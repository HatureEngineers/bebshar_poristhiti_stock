import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'calculator_page.dart';

class SummaryCardSection extends StatefulWidget {
  final double screenWidth;

  SummaryCardSection(this.screenWidth);

  @override
  _SummaryCardSectionState createState() => _SummaryCardSectionState();
}

class _SummaryCardSectionState extends State<SummaryCardSection> {
  double totalDueAmount = 0.0;
  double dailySales = 0.0;
  double dailyPurchases = 0.0;
  double dailyDue = 0.0;

  String convertToBengali(String input) {
    const englishToBengali = {
      '0': '০',
      '1': '১',
      '2': '২',
      '3': '৩',
      '4': '৪',
      '5': '৫',
      '6': '৬',
      '7': '৭',
      '8': '৮',
      '9': '৯',
      '.': '.',
    };
    return input.split('').map((e) => englishToBengali[e] ?? e).join();
  }

  @override
  void initState() {
    super.initState();
    _listenToTotalDueAmount();
    _listenToDailySales();
    _listenToDailyPurchases();
    _listenToDailyDue();
  }

  // Real-time listener for total due amount
  void _listenToTotalDueAmount() {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('customers')
        .snapshots()
        .listen((customerSnapshot) {
      double totalAmount = 0.0;
      for (var doc in customerSnapshot.docs) {
        totalAmount += (doc['transaction'] ?? 0.0);
      }

      setState(() {
        totalDueAmount = totalAmount;
      });
    });
  }

  // Real-time listener for daily sales
  void _listenToDailySales() {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1));

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sales')
        .where('time', isGreaterThanOrEqualTo: startOfDay)
        .where('time', isLessThan: endOfDay)
        .snapshots()
        .listen((salesSnapshot) {
      double totalSales = 0.0;
      for (var doc in salesSnapshot.docs) {
        totalSales += (doc['amount'] ?? 0.0);
      }

      setState(() {
        dailySales = totalSales;
      });
    });
  }

  // Real-time listener for daily purchases
  void _listenToDailyPurchases() {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1));

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .where('time', isGreaterThanOrEqualTo: startOfDay)
        .where('time', isLessThan: endOfDay)
        .snapshots()
        .listen((purchasesSnapshot) {
      double totalPurchases = 0.0;
      for (var doc in purchasesSnapshot.docs) {
        totalPurchases += (doc['amount'] ?? 0.0);
      }
      setState(() {
        dailyPurchases = totalPurchases;
      });
    });
  }

  // Real-time listener for daily due
  void _listenToDailyDue() {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1));

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('customers')
        .where('transactionDate', isGreaterThanOrEqualTo: startOfDay)
        .where('transactionDate', isLessThan: endOfDay)
        .snapshots()
        .listen((dueSnapshot) {
      double totalDue = 0.0;
      for (var doc in dueSnapshot.docs) {
        totalDue += (doc['transaction'] ?? 0.0);
      }

      setState(() {
        dailyDue = totalDue;
      });
    });
  }

//পপআপ
  void _showPaymentDialog() {
    TextEditingController quickSaleDescriptionController = TextEditingController();
    TextEditingController quickSaleAmountController = TextEditingController();
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quickSaleDescriptionController,
                          decoration: InputDecoration(
                            labelText: 'লেনদেনের বিবরণ লিখুন',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(vertical: 30, horizontal: 15),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quickSaleAmountController,
                          decoration: InputDecoration(
                            labelText: 'বিক্রয়ের পরিমাণ(টাকা)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        icon: Icon(
                          Icons.calculate_outlined,
                          color: Colors.teal,
                          size: MediaQuery.of(context).size.width * 0.14,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return CalculatorPage(
                                onValueSelected: (value) {
                                  quickSaleAmountController.text = value.toString();
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 30),
                          minimumSize: Size(80, 50),
                        ),
                        child: Text(
                          'বাতিল',
                          style: TextStyle(color: Colors.white, fontSize: 25),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          DocumentSnapshot userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .get();
                          bool isPermissionGranted = userDoc.get('permission') ?? false;

                          if (isPermissionGranted) {
                            if (quickSaleAmountController.text.isNotEmpty) {
                              try {
                                double quickSaleAmount = double.parse(quickSaleAmountController.text);
                                String quickSaleDescription = quickSaleDescriptionController.text;

                                Map<String, dynamic> saleData = {
                                  'amount': quickSaleAmount,
                                  'time': Timestamp.now(),
                                  'details': quickSaleDescription,
                                };

                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('sales')
                                    .add(saleData);

                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('cashbox')
                                    .add({
                                  'amount': quickSaleAmount,
                                  'reason': 'দ্রুত বিক্রি: $quickSaleDescription',
                                  'time': Timestamp.now(),
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("বিক্রি সফল হয়েছে", textAlign: TextAlign.center),
                                    behavior: SnackBarBehavior.floating,
                                    margin: EdgeInsets.symmetric(horizontal: 120, vertical: 20),
                                  ),
                                );

                                quickSaleAmountController.clear();
                                // Navigator.of(context).pop();
                              } catch (e) {
                                print('Error during sale: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('বিক্রয় করার সময় সমস্যা হয়েছে।', textAlign: TextAlign.center)),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('বিক্রয় মূল্য লিখে বিক্রি করুন', textAlign: TextAlign.center)),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('দয়া করে পেমেন্ট করুন অথবা হেল্প লাইনে যোগাযোগ করুন', textAlign: TextAlign.center)),
                            );
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 30),
                          minimumSize: Size(100, 60),
                        ),
                        child: Text(
                          'বিক্রি করুন',
                          style: TextStyle(color: Colors.white, fontSize: 25),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.tealAccent, Colors.grey],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('দৈনিক বাকি', '৳ ${convertToBengali(dailyDue.toStringAsFixed(0))}', false),
                  _buildSummaryItem('দৈনিক ক্রয়', '৳ ${convertToBengali(dailyPurchases.toStringAsFixed(0))}', false),
                  _buildSummaryItem('দৈনিক বিক্রি', '৳ ${convertToBengali(dailySales.toStringAsFixed(0))}', false),
                ],
              ),
              Divider(height: 30, color: Colors.black),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('মোট বাকির পরিমাণ', '৳ ${convertToBengali(totalDueAmount.toStringAsFixed(0))}', false),
                  ElevatedButton(
                    onPressed: () {
                      _showPaymentDialog(); // পপআপ দেখানোর জন্য কল করুন
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue, // বাটনের ব্যাকগ্রাউন্ড রঙ
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // 20 পিক্সেল গোলাকার শেপ
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10), // বাটনের প্যাডিং
                    ),
                    child: Text(
                      'দ্রুত বিক্রি',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, bool isPrimary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : Colors.black),
        ),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isPrimary ? Colors.blue : Colors.black87,
          ),
        ),
      ],
    );
  }
}
