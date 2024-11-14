import 'package:flutter/material.dart';
import 'customer_selection_page.dart';
import 'product_selection_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SaleStockPage extends StatefulWidget {
  const SaleStockPage({super.key});

  @override
  _SaleStockPageState createState() => _SaleStockPageState();
}

class _SaleStockPageState extends State<SaleStockPage> {
  bool isProcessing = false;
  String selectedCustomerName = '';
  String selectedCustomerPhone = '';
  double selectedPreviousTransaction = 0.0;
  double saleAmount = 0.0;
  double cashPayment = 0.0;
  String? selectedCustomerId;
  List<TextEditingController> priceControllers = [];
  List<Map<String, dynamic>> selectedProducts = [];
  double get totalProductPrice =>
      selectedProducts.fold(0, (sum, product) => sum + (product['price'] * product['totalAmount']));

  double get grandTotal => selectedPreviousTransaction + totalProductPrice;
  final TextEditingController cashPaymentController = TextEditingController();

  String convertToBengaliNumbers(String input) {
    final List<String> englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    final List<String> bengaliNumbers = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

    String converted = input;
    for (int i = 0; i < englishNumbers.length; i++) {
      converted = converted.replaceAll(englishNumbers[i], bengaliNumbers[i]);
    }
    return converted;
  }

  @override
  void dispose() {
    cashPaymentController.dispose();
    for (var controller in priceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saleProducts() async {
    // যদি ইতিমধ্যেই প্রক্রিয়া চলছে, তাহলে ফাংশন বন্ধ করা হবে
    if (isProcessing) return;

    // প্রক্রিয়া শুরু করা হচ্ছে
    setState(() {
      isProcessing = true;
    });

    DateTime now = DateTime.now();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // Step 0: ইউজার লগ ইন না থাকলে ফাংশন বন্ধ করা
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ইউজার লগ ইন নেই।')),
      );
      return;
    }

    // Step 1: পণ্য যোগ করা হয়েছে কিনা তা চেক করা
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('দয়া করে পণ্য যুক্ত করুন।')),
      );
      return;
    }

    try {
      // Step 2: স্টক আপডেট করা হচ্ছে
      for (var product in selectedProducts) {
        final productName = product['name'];
        final productQuery = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('stock')
            .where('name', isEqualTo: productName)
            .limit(1);

        final productSnapshot = await productQuery.get();

        if (productSnapshot.docs.isNotEmpty) {
          final productDoc = productSnapshot.docs.first;
          await productDoc.reference.update({
            'totalAmount': FieldValue.increment(product['totalAmount']),
          });
        }
      }

      // Step 3: সাপ্লায়ারের transaction আপডেট করা হচ্ছে
      double updatedTransaction = selectedPreviousTransaction + totalProductPrice - cashPayment;
      if (selectedCustomerPhone.isNotEmpty) {
        final customerRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('customers')
            .where('phone', isEqualTo: selectedCustomerPhone)
            .limit(1);
        final customerSnapshot = await customerRef.get();
        if (customerSnapshot.docs.isNotEmpty) {
          final customerDoc = customerSnapshot.docs.first;
          await customerDoc.reference.update({
            'transaction': updatedTransaction,
          });
        }
      }

      // Step 4: বিক্রয়ের তথ্য sales কালেকশনে সংরক্ষণ করা হচ্ছে
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('sales')
          .add({
        'amount': totalProductPrice,
        'time': now,
        'payment': cashPayment,
        'products': selectedProducts,
      });

      // Step 5: নগদের মুভমেন্ট cashbox কালেকশনে লগ করা হচ্ছে
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cashbox')
          .add({
        'amount': cashPayment,
        'reason': 'বিক্রয়ঃ $selectedCustomerName এর কাছে $totalProductPrice টাকার পণ্য বিক্রয় করে বর্তমান বাকি $updatedTransaction টাকা।',
        'time': now,
      });

      // Step 6: প্রতিদিনের জন্য ডকুমেন্ট তৈরি করা হচ্ছে (daily_totals)
      final dailyDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('daily_totals')
          .doc('${now.year}-${now.month}-${now.day}');

      await dailyDocRef.set({
        'sale_amount': FieldValue.increment(totalProductPrice),
        'sale_remaining': FieldValue.increment(totalProductPrice - cashPayment),
        'sale_paid': FieldValue.increment(cashPayment),
        'cashbox_total': FieldValue.increment(cashPayment),
        'date': now,
      }, SetOptions(merge: true));

      // Step 7: মাসিক ডকুমেন্ট তৈরি করা হচ্ছে (monthly_totals)
      final monthlyDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('monthly_totals')
          .doc('${now.year}-${now.month}');

      await monthlyDocRef.set({
        'sale_amount': FieldValue.increment(totalProductPrice),
        'sale_remaining': FieldValue.increment(totalProductPrice - cashPayment),
        'sale_paid': FieldValue.increment(cashPayment),
        'cashbox_total': FieldValue.increment(cashPayment),
        'month': now.month,
        'year': now.year,
      }, SetOptions(merge: true));

      // Step 8: বার্ষিক ডকুমেন্ট তৈরি করা হচ্ছে (yearly_totals)
      final yearlyDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('yearly_totals')
          .doc('${now.year}');

      await yearlyDocRef.set({
        'sale_amount': FieldValue.increment(totalProductPrice),
        'sale_remaining': FieldValue.increment(totalProductPrice - cashPayment),
        'sale_paid': FieldValue.increment(cashPayment),
        'cashbox_total': FieldValue.increment(cashPayment),
        'year': now.year,
      }, SetOptions(merge: true));

      // সফল বার্তা প্রদর্শন এবং UI রিসেট করা
      setState(() {
        selectedProducts.clear();
        saleAmount = 0.0;
        cashPayment = 0.0;
        cashPaymentController.clear();
        selectedCustomerName = '';
        selectedCustomerPhone = '';
        selectedPreviousTransaction = 0.0;
        selectedCustomerId = null;
        FocusScope.of(context).unfocus();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('বিক্রয় সফল হয়েছে!')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('কেনাকাটা সম্পন্ন করতে সমস্যা হয়েছে: $e')),
      );
    }
  }

  void _openCustomerSelection(BuildContext context) async {
    final selectedCustomer = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // রাউন্ড এজ
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: CustomerSelectionPage(),
        ),
      ),
    );

    if (selectedCustomer != null) {
      setState(() {
        selectedCustomerName = selectedCustomer['name'];
        selectedCustomerPhone = selectedCustomer['phone'];
        selectedPreviousTransaction = selectedCustomer['previousTransaction'];
        selectedCustomerId = selectedCustomer['id'];
      });
    }
  }

  void _openProductSelection(BuildContext context) async {
    final selectedProduct = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // রাউন্ড এজ
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: ProductSelectionPage(),
        ),
      ),
    );

    if (selectedProduct != null) {
      bool isProductAlreadySelected = selectedProducts.any((product) => product['name'] == selectedProduct['name']);

      if (!isProductAlreadySelected) {
        setState(() {
          int previoustotalAmount = selectedProduct['totalAmount']?.toInt() ?? 0 ?? 0;
          selectedProducts.insert(0, {
            'name': selectedProduct['name'],
            'price': selectedProduct['price'],
            'totalAmount': 1,
            'previoustotalAmount': previoustotalAmount,
          });
          priceControllers.insert(0, TextEditingController(text: selectedProduct['price'].toString()));
        });
      }
    }
  }

  void updateProducttotalAmount(int index, String value) {
    setState(() {
      int newtotalAmount = int.tryParse(value) ?? 1;
      selectedProducts[index]['totalAmount'] = newtotalAmount;
      saleAmount = totalProductPrice;
    });
  }

  void updateProductPrice(int index, String value) {
    setState(() {
      double newPrice = double.tryParse(value) ?? selectedProducts[index]['price'];
      selectedProducts[index]['price'] = newPrice;
      saleAmount = totalProductPrice;
    });
  }

  void removeProduct(int index) {
    setState(() {
      selectedProducts.removeAt(index);
      priceControllers[index].dispose(); // রিমুভ করার সময় `controller` dispose করা হচ্ছে
      priceControllers.removeAt(index); // লিস্ট থেকে `controller` রিমুভ করা হচ্ছে
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Remove focus from the TextField
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text('বিক্রয় ও বাকীতে বিক্রয়'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          children: [
            // Customer and Product Selection Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openCustomerSelection(context),
                    icon: Icon(Icons.people, color: Colors.white),
                    label: Text('কাস্টমার নির্বাচন', style: TextStyle(fontSize: screenWidth * 0.04)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openProductSelection(context),
                    icon: Icon(Icons.add_shopping_cart, color: Colors.white),
                    label: Text('পণ্য নির্বাচন', style: TextStyle(fontSize: screenWidth * 0.04)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            // Scrollable selected products list
            Expanded(
              child: Column(
                children: [
                  Center(
                    child: Text(
                      'নির্বাচিত পণ্যসমূহ:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.045,
                        color: Colors.teal,
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: selectedProducts.length,
                      itemBuilder: (context, index) {
                        final product = selectedProducts[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 5),
                          child: Padding(
                            padding: EdgeInsets.all(screenWidth * 0.03),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${product['name']} (পণ্যের পরিমাণ: ${product['previoustotalAmount']})',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: screenWidth * 0.04,
                                            color: Colors.black,
                                          ),
                                        ),

                                      ],
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close, color: Colors.red),
                                      onPressed: () {
                                        removeProduct(index); // পণ্য রিমুভ ফাংশন কল
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: priceControllers[index],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(labelText: 'মূল্য'),
                                        onChanged: (value) => updateProductPrice(index, value),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(labelText: 'পরিমাণ'),
                                        initialValue: product['totalAmount'].toString(),
                                        onChanged: (value) => updateProducttotalAmount(index, value),
                                      ),
                                    ),
                                    Text(' = ৳${product['price'] * product['totalAmount']}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Fixed Customer information and sale button section
            Container(
              padding: EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(),
                  Center(
                    child: Text(
                      'কাস্টমার ইনফর্মেশন:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.045,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('নামঃ'),
                            Text('$selectedCustomerName'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ফোনঃ'),
                            Text('$selectedCustomerPhone'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('পূর্ববর্তী দেনা:'),
                            Text('৳${convertToBengaliNumbers(selectedPreviousTransaction.toString())}', style: TextStyle(fontSize: screenWidth * 0.04)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('মোট বিক্রয় মূল্যঃ', style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold)),
                            Text('৳${convertToBengaliNumbers(totalProductPrice.toString())}', style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('বাকী সহ মোটঃ', style: TextStyle(fontSize: screenWidth * 0.04)),
                            Text('৳${convertToBengaliNumbers(grandTotal.toString())}', style: TextStyle(fontSize: screenWidth * 0.048)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: cashPaymentController,
                    decoration: InputDecoration(
                      labelText: 'নগদ পরিশোধ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12), // প্যাডিং যুক্ত করা হচ্ছে
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() {
                      cashPayment = double.tryParse(value) ?? 0.0;
                    }),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: selectedProducts.isNotEmpty
                          ? () {
                        _saleProducts(); // সরাসরি কল করা হচ্ছে, await প্রয়োজন নেই
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white, // টেক্সটের রঙ সাদা
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), // গোল ভাব কমানো হয়েছে
                        ),
                      ),
                      child: const Text(
                        'বিক্রয় করুন',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
