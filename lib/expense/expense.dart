import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting

class ExpensePage extends StatefulWidget {
  @override
  _ExpensePageState createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final TextEditingController _expenseController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  double _totalExpense = 0.0;
  bool _includeInCashbox = false;
  User? _currentUser;
  bool _isAddingExpense = false;

  String _selectedRange = 'সাপ্তাহিক'; // Default to 'মাসিক'

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _calculateTotalExpense();
  }

  // Get the reference to the user's expense and cashbox collections
  CollectionReference getExpenseCollection() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('expense');
  }

  CollectionReference getCashboxCollection() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('cashbox');
  }

  Future<void> _addExpense() async {
    if (_expenseController.text.isEmpty) return;

    final expenseData = {
      'amount': double.parse(_expenseController.text),
      'reason': _detailsController.text,
      'time': Timestamp.now(),
    };

    final expenseDoc = await getExpenseCollection().add(expenseData);

    if (_includeInCashbox) {
      final cashboxData = {
        'amount': -double.parse(_expenseController.text),
        'reason': _detailsController.text,
        'time': Timestamp.now(),
      };
      await getCashboxCollection().doc(expenseDoc.id).set(cashboxData);
    }

    await _calculateTotalExpense();

    _expenseController.clear();
    _detailsController.clear();
    setState(() {
      _includeInCashbox = false;
    });
  }

  Future<bool> checkIfExpenseInCashbox(String expenseId) async {
    // Retrieve the document from the cashbox collection using the expenseId
    var cashboxDoc = await getCashboxCollection().doc(expenseId).get();

    // Return true if the document exists, indicating the expense is included in cashbox
    return cashboxDoc.exists;
  }

  Future<void> _editExpense(String expenseId, double amount, String details,
      bool includeInCashbox) async {
    final updatedData = {
      'amount': amount,
      'reason': details,
      'time': Timestamp.now(),
    };

    await getExpenseCollection().doc(expenseId).update(updatedData);

    // Check if the expense is to be included in cashbox
    if (includeInCashbox) {
      final updatedCashboxData = {
        'amount': -amount,
        'reason': details,
        'time': Timestamp.now(),
      };
      await getCashboxCollection().doc(expenseId).set(updatedCashboxData);
    } else {
      // If the checkbox is unchecked, remove from cashbox
      await getCashboxCollection().doc(expenseId).delete();
    }

    // Recalculate total expenses after editing
    await _calculateTotalExpense();
  }

  Future<void> _deleteExpense(String expenseId) async {
    await getExpenseCollection().doc(expenseId).delete();
    await getCashboxCollection().doc(expenseId).delete();

    // Recalculate total expenses after deletion
    await _calculateTotalExpense();
  }

  Future<void> _confirmDeleteExpense(String expenseId) async {
    bool isDelete = await _getIsDeleteValue();

    if (isDelete) {
      bool pinVerified = await _verifyPin();
      if (!pinVerified) {
        return; // Exit if the PIN is incorrect
      }
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this expense?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                _deleteExpense(expenseId); // Proceed with deletion
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(String expenseId, double amount, String details,
      bool isIncludedInCashbox) async {
    // Create local variables for the edit dialog
    String tempAmount = amount.toString();
    String tempDetails = details;
    bool isEdit = await _getIsEditValue();

    if (isEdit) {
      bool pinVerified = await _verifyPin();
      if (!pinVerified) {
        return; // Exit if the PIN is incorrect
      }
    }

    // Use the passed parameter to set the initial state of the checkbox
    bool cashboxChecked =
        isIncludedInCashbox; // Set the initial state of the checkbox

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Expense'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: TextEditingController(text: tempAmount),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Amount'),
                    onChanged: (value) {
                      tempAmount = value; // Update the local variable on change
                    },
                  ),
                  TextField(
                    controller: TextEditingController(text: tempDetails),
                    decoration: InputDecoration(labelText: 'Details'),
                    onChanged: (value) {
                      tempDetails =
                          value; // Update the local variable on change
                    },
                  ),
                  Row(
                    children: <Widget>[
                      Checkbox(
                        value: cashboxChecked,
                        onChanged: (bool? value) {
                          // Update the checkbox state on click
                          setState(() {
                            cashboxChecked = value ?? false; // Toggle the value
                          });
                        },
                      ),
                      Text('Include in Cashbox'),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Simply close the dialog
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () async {
                FocusScope.of(context).unfocus();
                await _editExpense(
                  expenseId,
                  double.parse(tempAmount), // Use the local variable
                  tempDetails, // Use the local variable
                  cashboxChecked, // Include checkbox state
                );
                Navigator.of(context).pop(); // Close the dialog after saving
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _calculateTotalExpense() async {
    final now = DateTime.now();

    Query expenseQuery;

    // Modify the query based on selected range
    switch (_selectedRange) {
      case 'সাপ্তাহিক':
        final oneWeekAgo = now.subtract(Duration(days: 7));
        expenseQuery =
            getExpenseCollection().where('time', isGreaterThan: oneWeekAgo);
        break;
      case 'মাসিক':
        final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);
        expenseQuery =
            getExpenseCollection().where('time', isGreaterThan: oneMonthAgo);
        break;
      case 'বাৎসরিক':
        final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
        expenseQuery =
            getExpenseCollection().where('time', isGreaterThan: oneYearAgo);
        break;
      default:
        expenseQuery = getExpenseCollection(); // For 'সর্বকালীন'
    }

    // Get the snapshot and calculate total expense
    final expenseSnapshot = await expenseQuery.get();
    final expenses = expenseSnapshot.docs;

    double total = 0.0;
    for (var doc in expenses) {
      total += doc['amount'];
    }

    setState(() {
      _totalExpense = total; // Update the total expense state
    });
  }
  //ডিলিট এডিটের জন্য
  Future<bool> _getIsEditValue() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    return doc.data()?['isEdit'] ?? false;
  }

  Future<bool> _getIsDeleteValue() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    return doc.data()?['isDelete'] ?? false;
  }

  // পিন ভেরিফাইয়ের জন্য
  Future<bool> _verifyPin() async {
    String enteredPin = '';
    bool isPinCorrect = false;

    // ফায়ারবেস থেকে স্টোর করা পিন রিট্রাইভ করুন
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    String storedPin = userDoc.data()?['pin'] ?? ''; // স্টোর করা পিনটি রিট্রাইভ

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('পিন দিন'),
          content: TextField(
            obscureText: true,
            onChanged: (value) {
              enteredPin = value;
            },
            decoration: InputDecoration(
              labelText: 'পিন',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('বাতিল করুন'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('যাচাই করুন'),
              onPressed: () {
                // পিন চেক করা হচ্ছে
                if (enteredPin == storedPin) {
                  isPinCorrect = true;
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    return isPinCorrect;
  }
//পিন ফর ডিলিট এন্ড এডিট

  Widget _buildExpenseList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          getExpenseCollection().orderBy('time', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());

        final expenses = snapshot.data!.docs.where((doc) {
          final reason = doc['reason'].toString().toLowerCase();
          return reason.contains(_searchQuery); // Filter by the search query
        }).toList();

        if (expenses.isEmpty) {
          return Center(child: Text('No expenses found.'));
        }

        return ListView.builder(
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            final expenseId = expense.id;
            final amount = expense['amount'];
            final details = expense['reason'];
            final time = (expense['time'] as Timestamp).toDate();
            final formattedTime = DateFormat.yMMMd().format(time);

            return FutureBuilder<bool>(
              future:
                  checkIfExpenseInCashbox(expenseId), // Check inclusion status
              builder: (context, cashboxSnapshot) {
                Color cardColor = Colors.blue[100]!; // Default color
                bool isIncludedInCashbox = false;

                if (cashboxSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Card(
                    color: cardColor,
                    child: ListTile(
                      title: Text('Loading...'),
                    ),
                  );
                } else if (cashboxSnapshot.hasData &&
                    cashboxSnapshot.data != null) {
                  isIncludedInCashbox = cashboxSnapshot.data!;
                  cardColor = isIncludedInCashbox
                      ? Colors.green[100]!
                      : Colors.blue[100]!;
                }

                return Card(
                  color: cardColor, // Set the background color of the card
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 16), // Further reduced vertical padding
                    leading: Icon(
                      isIncludedInCashbox
                          ? Icons.account_balance_wallet
                          : Icons
                              .money, // Different icons based on cashbox inclusion
                      size: 20,
                      color: isIncludedInCashbox
                          ? Colors.green
                          : Colors.blue, // Color changes based on inclusion
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'খরচ: ৳$amount', // Amount label
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(
                            height:
                                4), // Small space between title and subtitle
                        Text(
                          'বিবরণ: $details', // Details label
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 2), // Small space for date
                        Text(
                          'তারিখ: $formattedTime', // Date label
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.green[700]),
                          onPressed: () {
                            // Call the edit dialog with the cashbox inclusion status
                            _showEditDialog(expenseId, amount, details,
                                isIncludedInCashbox);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _confirmDeleteExpense(expenseId);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, String rangeLabel) {
    return Center(
      child: Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)), // Rounded corners
        color: Colors.teal[100], // Set the background color of the card
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 10, horizontal: 20), // Add padding for content
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Align text to the start
            children: [
              Text(
                '$label $rangeLabel', // Title with range label
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold), // Title style
              ),
              SizedBox(height: 10), // Space between title and value
              Text(
                '৳$_totalExpense', // Dynamic total expense value
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple), // Value style
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        Container(
          width: MediaQuery.of(context).size.width * 0.95,
          child: TextField(
            controller: _detailsController,
            decoration: InputDecoration(
              labelText: 'খরচের বর্ণনা লিখুন',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
          ),
        ),
        SizedBox(height: 16),
        Container(
          width: MediaQuery.of(context).size.width * 0.95,
          child: TextField(
            controller: _expenseController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'খরচের পরিমান (টাকা)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
          ),
        ),
        SizedBox(height: 2),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            'ক্যাশবক্সে অন্তর্ভুক্ত করুন',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          value: _includeInCashbox,
          onChanged: (bool? value) {
            setState(() {
              _includeInCashbox = value ?? false;
            });
          },
        ),
        SizedBox(height: 2),
        ElevatedButton(
          onPressed: _isAddingExpense
              ? null
              : () async {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _isAddingExpense = true;
                  });
                  await _addExpense();
                  setState(() {
                    _isAddingExpense = false;
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            fixedSize: Size(180, 45),
          ),
          child: Text('খরচ যুক্ত করুন',
              style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 1.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search by reason',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
        onChanged: (query) {
          setState(() {
            _searchQuery = query.toLowerCase(); // Update the search query
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'খরচের হিসাব',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.teal[600],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          Transform.translate(
            offset: Offset(-10, 0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 1.0),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: DropdownButton<String>(
                value: _selectedRange,
                dropdownColor: Colors.teal[600],
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                underline: SizedBox(),
                items: <String>['সাপ্তাহিক', 'মাসিক', 'বাৎসরিক', 'সর্বকালীন']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedRange = newValue!;
                    _calculateTotalExpense();
                  });
                },
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: _buildSummaryCard(_selectedRange, 'খরচ'),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: _buildSummaryCard('দৈনিক', 'খরচ'),
                ),
              ],
            ),

            SizedBox(height: 2),
            _buildInputFields(), // Extracted method for input fields
            SizedBox(height: 2),
            _buildSearchField(),
            // Container for the expense list
            Expanded(
              child: _buildExpenseList(),
            ),
          ],
        ),
      ),
    );
  }
}
