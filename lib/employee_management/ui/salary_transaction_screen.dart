import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../services/employee_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalaryTransactionScreen extends StatefulWidget {
  final Employee employee;

  SalaryTransactionScreen({required this.employee});

  @override
  _SalaryTransactionScreenState createState() =>
      _SalaryTransactionScreenState();
}

class _SalaryTransactionScreenState extends State<SalaryTransactionScreen> {
  final TextEditingController _amountController = TextEditingController();
  final EmployeeService _employeeService = EmployeeService();
  final ScrollController _scrollController = ScrollController();

  double _amountToPay = 0.0;
  bool _sendToCashbox = false;
  bool _isLoading = false;
  bool _hasMore = true; // Tracks if more transactions are available
  DocumentSnapshot? _lastDocument; // The last document fetched in pagination
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _checkAndUpdateAmountToPay();
    _loadTransactions();

    // Add scroll listener to load more transactions when reaching the end
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent &&
          !_isLoading &&
          _hasMore) {
        _loadTransactions();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addTransaction(double amount) async {
    try {
      await _employeeService.addSalaryTransaction(widget.employee.id, amount);
      setState(() {
        _amountToPay -= amount;
      });

      if (_sendToCashbox) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_employeeService.userId)
            .collection('cashbox')
            .add({
          'timestamp': Timestamp.now(),
          'amount': -amount,
          'reason': 'employee salary',
        });
      }

      // Reload transactions to update the list immediately
      _transactions.clear();
      _lastDocument = null; // Reset pagination
      _hasMore = true;
      await _loadTransactions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add transaction: $e')),
      );
    }
  }

  Future<void> _checkAndUpdateAmountToPay() async {
    final currentDate = DateTime.now();
    final employeeDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_employeeService.userId)
        .collection('employees')
        .doc(widget.employee.id)
        .get();

    if (employeeDoc.exists) {
      final data = employeeDoc.data() as Map<String, dynamic>;
      final lastTransactionDate =
      (data['lastTransactionDate'] as Timestamp?)?.toDate();
      final storedAmountToPay = (data['amountToPay'] ?? 0.0) as double;

      if (lastTransactionDate == null ||
          lastTransactionDate.year != currentDate.year ||
          lastTransactionDate.month != currentDate.month) {
        setState(() {
          _amountToPay = storedAmountToPay + (widget.employee.salary ?? 0.0);
        });

        await employeeDoc.reference.update({
          'amountToPay': _amountToPay,
          'lastTransactionDate': Timestamp.fromDate(currentDate),
        });
      } else {
        setState(() {
          _amountToPay = storedAmountToPay;
        });
      }
    } else {
      setState(() {
        _amountToPay = widget.employee.salary ?? 0.0;
      });

      await employeeDoc.reference.set({
        'amountToPay': _amountToPay,
        'lastTransactionDate': Timestamp.fromDate(currentDate),
      });
    }
  }

  Future<void> _loadTransactions() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch transactions starting after the last document, or from the beginning if none
      final newTransactions = await _employeeService.getPaginatedSalaryTransactions(
        widget.employee.id,
        5,
        startAfter: _lastDocument,
      );

      setState(() {
        if (newTransactions.isNotEmpty) {
          // Filter out duplicates by checking unique transaction ID
          newTransactions.forEach((transaction) {
            if (!_transactions.any((t) => t['id'] == transaction['id'])) {
              _transactions.add(transaction);
            }
          });

          // Update last document for pagination
          _lastDocument = newTransactions.last['documentSnapshot'];
        } else {
          _hasMore = false; // No more data available
        }
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      print("Error loading transactions: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Salary Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Salary: ${widget.employee.salary?.toStringAsFixed(0) ?? '0'}৳',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              _amountToPay >= 0
                  ? 'Amount to Pay: ${_amountToPay.toStringAsFixed(0)}৳'
                  : 'Advance Paid: ${(-_amountToPay).toStringAsFixed(0)}৳',
              style: TextStyle(
                fontSize: 18,
                color: _amountToPay >= 0 ? Colors.red : Colors.green, // Optional: change color based on positive/negative
              ),
            ),

            SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount to Pay',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _sendToCashbox,
                  onChanged: (bool? value) {
                    setState(() {
                      _sendToCashbox = value ?? false;
                    });
                  },
                ),
                Text('Send to Cashbox'),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text);
                if (amount != null && amount != 0) {
                  _addTransaction(amount);
                  _amountController.clear();
                  FocusScope.of(context).unfocus();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid amount')),
                  );
                }
              },
              child: Text('Add Transaction'),
            ),
            SizedBox(height: 20),
            Text('Transaction History:', style: TextStyle(fontSize: 18)),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _transactions.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _transactions.length) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final transaction = _transactions[index];
                  final amount = transaction['amount'].toDouble();
                  final date = transaction['date'];

                  String formattedDate = 'No date available';
                  if (date != null && date is Timestamp) {
                    formattedDate = DateFormat('MMM dd, yyyy, h:mm a')
                        .format(date.toDate());
                  }

                  return ListTile(
                    title: Text('${amount.toStringAsFixed(0)}৳'),
                    subtitle: Text('Date: $formattedDate'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
