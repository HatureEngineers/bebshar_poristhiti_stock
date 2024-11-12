import 'package:bebshar_poristhiti_stock/purchase_management/purchase_new_supplier.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../cash_box/cash_box.dart';
import '../widgets/calculator_page.dart';
import 'old_supplier_purchase.dart';

class PurchasePage extends StatefulWidget {
  @override
  _PurchasePageState createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  TextEditingController searchController = TextEditingController();
  TextEditingController creditPurchaseAmountController = TextEditingController();
  TextEditingController quickPurchaseAmountController = TextEditingController();
  TextEditingController quickPurchaseDescriptionController = TextEditingController();

  String? selectedSupplierId;
  String? selectedSupplierName;
  double previousTransaction = 0.0;

  Future<void> fetchSupplierData(String supplierName) async {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('suppliers')
        .where('uid', isEqualTo: uid)
        .where('name', isGreaterThanOrEqualTo: supplierName)
        .where('name', isLessThanOrEqualTo: supplierName + '\uf8ff')
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        selectedSupplierId = querySnapshot.docs.first.id;
        selectedSupplierName = querySnapshot.docs.first['name'];
        previousTransaction = querySnapshot.docs.first['transaction'] ?? 0.0;
      });
    } else {
      setState(() {
        selectedSupplierId = null;
        selectedSupplierName = null;
        previousTransaction = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text('সাপ্লায়ার থেকে ক্রয়'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'বাকিতে ক্রয়',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 120,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PurchaseNewSupplier(appBarTitle: 'ajshakjsh')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'নতুন সাপ্লায়ার থেকে কিনুন',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 120,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OldSupplierPurchase()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'পুরাতন সাপ্লায়ার থেকে কিনুন',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 50),
            Center(
              child: Text(
                'দ্রুত ক্রয়',
                style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ),
            SizedBox(height: 10),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quickPurchaseDescriptionController, // New text field
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
                          // IconButton(
                          //   icon: Icon(Icons.description, color: Colors.teal),
                          //   onPressed: () {  },
                          // ),
                        ]
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quickPurchaseAmountController,
                            decoration: InputDecoration(
                              labelText: 'ক্রয়ের পরিমাণ লিখুন(টাকা)',
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
                        SizedBox(width: 10), // Space between the text field and icon
                        IconButton(
                          icon: Icon(
                            Icons.calculate_outlined,
                            color: Colors.teal,
                            size: MediaQuery.of(context).size.width * 0.14,
                          ),
                          onPressed: () {
                            // Show the calculator dialog
                            showDialog(
                              context: context,
                              builder: (context) {
                                return CalculatorPage(
                                  onValueSelected: (value) {
                                    quickPurchaseAmountController.text = value.toString();
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (quickPurchaseAmountController.text.isNotEmpty) {
                          try {
                            double quickPurchaseAmount = double.parse(quickPurchaseAmountController.text);
                            String quickPurchaseDescription = quickPurchaseDescriptionController.text;
                            String? uid = FirebaseAuth.instance.currentUser?.uid;

                            if (uid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('User not logged in')),
                              );
                              return;
                            }

                            // Prepare the purchase data map
                            Map<String, dynamic> purchaseData = {
                              'amount': quickPurchaseAmount,
                              'time': Timestamp.now(),
                              'details':quickPurchaseDescription,
                            };

                            // Add the purchase data to Firestore
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('purchases')
                                .add(purchaseData);

                            // Add the purchase to the cashbox as well
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('cashbox')
                                .add({
                              'amount': -quickPurchaseAmount,
                              'reason': 'দ্রুত ক্রয়: $quickPurchaseDescription',
                              'time': Timestamp.now(),
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("ক্রয় সফল হয়েছে!"),
                                action: SnackBarAction(
                                  label: 'View', // Label for the button
                                  textColor: Colors.white, // Optional: Customize button color
                                  onPressed: () {
                                    // Navigate to CashBoxScreen when the button is pressed
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => CashBoxScreen()), // Replace with your CashBoxScreen page
                                    );
                                  },
                                ),
                              ),
                            );

                            // Clear the quick purchase amount after successful purchase
                            quickPurchaseAmountController.clear();
                            quickPurchaseDescriptionController.clear();
                          } catch (e) {
                            print('Error during purchase: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('ক্রয় করার সময় সমস্যা হয়েছে।')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please enter an amount')),
                          );
                        }
                      },
                      child: Text(
                        'ক্রয় করুন',
                        style: TextStyle(color: Colors.white), // Change text color here
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, // Change button color here
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
