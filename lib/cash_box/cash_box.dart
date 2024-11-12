import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart'; // for locale initialization

class CashBoxScreen extends StatefulWidget {
  @override
  _CashBoxScreenState createState() => _CashBoxScreenState();
}

class _CashBoxScreenState extends State<CashBoxScreen> {

  @override
  void initState() {
    super.initState();
    // Initialize locale and start the timer
    initializeDateFormatting('en_BD', null);
    // _startClock();
  }

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController =
  TextEditingController(); // Reason controller
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> _addCash() async {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    String reason = _reasonController.text.trim(); // Get reason from the field
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      _amountController.clear();
      _reasonController.clear(); // Clear the reason after adding

      // Add transaction to Firestore
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('cashbox')
          .add({
        "amount": amount,
        "reason": reason,
        "type": "add",
        "time": DateTime.now(),
      });
    }
  }

  Future<void> _withdrawCash() async {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    String reason = _reasonController.text.trim(); // Get reason from the field
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      _amountController.clear();
      _reasonController.clear(); // Clear the reason after withdrawing

      // Add transaction to Firestore
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('cashbox')
          .add({
        "amount": -amount,
        "reason": reason,
        "type": "withdraw",
        "time": DateTime.now(),
      });
    }
  }

  Future<bool> _verifyPin(String userInputPin) async {
    // Assuming the PIN is stored in Firestore under the user document.
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      String storedPin = userDoc['pin']; // Get the stored PIN from Firestore.

      return userInputPin == storedPin; // Compare the user input PIN with the stored PIN.
    }
    return false;
  }

  Future<void> _editTransaction(
      String id, double oldAmount, String oldReason) async {
    TextEditingController editAmountController = TextEditingController();
    TextEditingController editReasonController = TextEditingController();

    editAmountController.text = oldAmount.toString();
    editReasonController.text = oldReason;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('লেনদেন সংশোধন'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'সঠিক পরিমাণ'),
              ),
              TextField(
                controller: editReasonController,
                decoration: InputDecoration(labelText: 'লেনদেনের তথ্য'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('বাতিল'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('সেভ করুন'),
              onPressed: () async {
                double newAmount =
                    double.tryParse(editAmountController.text) ?? oldAmount;
                String newReason = editReasonController.text.trim();

                User? currentUser = _auth.currentUser;
                if (currentUser != null) {
                  final userDoc = _firestore
                      .collection('users')
                      .doc(currentUser.uid);

                  // Update cashbox document
                  await userDoc.collection('cashbox').doc(id).update({
                    "amount": newAmount,
                    "reason": newReason,
                    "time": DateTime.now(),
                  });
                  // Check if the document exists in expense before updating
                  final expenseDoc = userDoc.collection('expense').doc(id);
                  final expenseSnapshot = await expenseDoc.get();
                  if (expenseSnapshot.exists) {
                    await expenseDoc.update({
                      "amount": -newAmount,
                      "reason": newReason,
                      "time": DateTime.now(),
                    });
                  }
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(String id) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('লেনদেন ডিলিট করুন'),
          content: Text('আপনি যদি ডিলিট করে দেন তাহলে এই ডাটা একেবারে মুছে যাবে।'),
          actions: [
            TextButton(
              child: Text('হ্যাঁ চাই'),
              onPressed: () async {
                User? currentUser = _auth.currentUser;
                if (currentUser != null) {
                  // Delete the transaction from Firestore
                  await _firestore
                      .collection('users')
                      .doc(currentUser.uid)
                      .collection('cashbox')
                      .doc(id)
                      .delete();

                  await _firestore
                      .collection('users')
                      .doc(currentUser.uid)
                      .collection('expense')
                      .doc(id)
                      .delete();
                }
                Navigator.of(context).pop(); // Close the dialog after deletion
              },
            ),
            TextButton(
              child: Text('চাই না'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog, no action
              },
            ),
          ],
        );
      },
    );
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'en_US', symbol: '৳').format(value);
  }
  String _formatAmountCurrency(double value) {
    return NumberFormat.currency(locale: 'en_US', symbol: 'ক্যাশ ৳').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cash Box  ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors
            .green, // Make the background transparent to show the gradient
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlueAccent, Colors.tealAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Display in a Card

              SizedBox(height: 10),

              // Current Balance Card using StreamBuilder to calculate balance
              StreamBuilder(
                stream: _firestore
                    .collection('users')
                    .doc(_auth.currentUser!.uid)
                    .collection('cashbox')
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      // Center the card
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  } else {
                    // Calculate the current balance from Firestore data
                    final transactions = snapshot.data!.docs;
                    double totalBalance = transactions.fold(0.0, (sum, doc) {
                      // Convert 'amount' to double safely
                      final amount = doc['amount'] is int
                          ? (doc['amount'] as int).toDouble()
                          : (doc['amount'] as double);
                      return sum + amount;
                    });

                    return Center(
                      // Center the card
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: Colors.blueAccent,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('ক্যাশ বক্স',
                                  style: TextStyle(
                                      fontSize: 28, color: Colors.white)),
                              SizedBox(height: 10),
                              Text(
                                _formatCurrency(totalBalance),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
              SizedBox(height: 20),

              // Cash Entry Field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'টাকার পরিমাণ (৳)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Reason Entry Field
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'বিবরণ লিখুন',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Action Buttons
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Validate Amount before withdrawing cash
                      if (_amountController.text.isEmpty) {
                        // Show a SnackBar if the amount is empty
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter an amount to withdraw.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        _withdrawCash(); // Proceed to withdraw cash if amount is valid
                      }
                    },
                    icon: Icon(Icons.remove, color: Colors.white),
                    label: Text('টাকা উত্তোলন', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Validate Amount before adding cash
                      if (_amountController.text.isEmpty) {
                        // Show a SnackBar if the amount is empty
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter an amount to add.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        _addCash(); // Proceed to add cash if amount is valid
                      }
                    },
                    icon: Icon(Icons.add, color: Colors.white),
                    label: Text('টাকা জমা', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Recent Transactions Section
              Text('Recent Transactions',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
              Expanded(
                child: StreamBuilder(
                  stream: _firestore
                      .collection('users')
                      .doc(_auth.currentUser!.uid)
                      .collection('cashbox')
                      .orderBy('time', descending: true)
                      .snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final transactions = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];

                        // Safely convert amount to double
                        final amount = transaction['amount'] is int
                            ? (transaction['amount'] as int).toDouble()
                            : transaction['amount'] as double;

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          color: amount < 0 ? Colors.redAccent : Colors.greenAccent,
                          child: ListTile(
                            title: Text(
                              _formatAmountCurrency(amount),
                              style: TextStyle(
                                color: amount < 0 ? Colors.white : Colors.black,  // Text color based on amount
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'বিবরণ: ${transaction['reason']}',
                                  style: TextStyle(
                                    color: amount < 0 ? Colors.white : Colors.black,  // Subtitle text color
                                  ),
                                ),
                                Text(
                                  DateFormat('EEE, dd-MM-yyyy – hh:mm a', 'en_BD').format(
                                    transaction['time'].toDate().toLocal(),
                                  ),
                                  style: TextStyle(
                                    color: amount < 0 ? Colors.white : Colors.black,  // Date text color
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: amount < 0 ? Colors.white : Colors.black,
                                  ),
                                  onPressed: () async {
                                    User? currentUser = _auth.currentUser;
                                    if (currentUser != null) {
                                      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
                                      bool isEdit = userDoc['isEdit'] ?? false;

                                      if (isEdit) {
                                        // Show PIN input dialog
                                        String userInputPin = '';
                                        bool pinVerified = false;

                                        await showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: Text('পিন নিশ্চিত করুন'),
                                              content: TextField(
                                                onChanged: (value) {
                                                  userInputPin = value;
                                                },
                                                decoration: InputDecoration(
                                                  labelText: 'এখানে পিন লিখুন',
                                                  border: OutlineInputBorder(),
                                                ),
                                                keyboardType: TextInputType.number,
                                                obscureText: true,
                                              ),
                                              actions: [
                                                TextButton(
                                                  child: Text('বাতিল'),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                                TextButton(
                                                  child: Text('যাচাই'),
                                                  onPressed: () async {
                                                    pinVerified = await _verifyPin(userInputPin);
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (pinVerified) {
                                          _editTransaction(transaction.id, amount, transaction['reason']);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Incorrect PIN. Try again.')),
                                          );
                                        }
                                      } else {
                                        _editTransaction(transaction.id, amount, transaction['reason']);
                                      }
                                    }
                                  },
                                ),

                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: amount < 0 ? Colors.white : Colors.black,
                                  ),
                                  onPressed: () async {
                                    User? currentUser = _auth.currentUser;
                                    if (currentUser != null) {
                                      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
                                      bool isDelete = userDoc['isDelete'] ?? false;

                                      if (isDelete) {
                                        // Show PIN input dialog
                                        String userInputPin = '';
                                        bool pinVerified = false;

                                        await showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: Text('Enter PIN'),
                                              content: TextField(
                                                onChanged: (value) {
                                                  userInputPin = value;
                                                },
                                                decoration: InputDecoration(
                                                  labelText: 'PIN',
                                                  border: OutlineInputBorder(),
                                                ),
                                                keyboardType: TextInputType.number,
                                                obscureText: true,
                                              ),
                                              actions: [
                                                TextButton(
                                                  child: Text('Cancel'),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                                TextButton(
                                                  child: Text('Verify'),
                                                  onPressed: () async {
                                                    pinVerified = await _verifyPin(userInputPin);
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                        if (pinVerified) {
                                          _deleteTransaction(transaction.id);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Incorrect PIN. Try again.')),
                                          );
                                        }
                                      } else {
                                        _deleteTransaction(transaction.id);
                                      }
                                    }
                                  },
                                ),

                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}