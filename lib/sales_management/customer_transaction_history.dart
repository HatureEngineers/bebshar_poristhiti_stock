import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class Transaction {
  final String id;
  final String description;
  final double totalSale;
  final double cashPayment;
  final double remainingAmount;
  final DateTime date;
  final String? imageUrl;

  Transaction({
    required this.id,
    required this.description,
    required this.totalSale,
    required this.cashPayment,
    required this.remainingAmount,
    required this.date,
    this.imageUrl,
  });

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      description: data['details'] ?? '',
      totalSale: data['totalSale']?.toDouble() ?? 0.0,
      cashPayment: data['cashPayment']?.toDouble() ?? 0.0,
      remainingAmount: data['remainingAmount']?.toDouble() ?? 0.0,
      date: (data['timestamp'] as Timestamp).toDate(),
      imageUrl: data['image'],
    );
  }
}

class CustomerHistoryPage extends StatefulWidget {
  final String userId;
  final String customerId;
  final String customerName;
  final String customerImageUrl;
  final String customerPhoneNumber;

  const CustomerHistoryPage({
    Key? key,
    required this.userId,
    required this.customerId,
    required this.customerName,
    required this.customerImageUrl,
    required this.customerPhoneNumber,
  }) : super(key: key);

  @override
  _CustomerHistoryPageState createState() => _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends State<CustomerHistoryPage> {
  Stream<List<Transaction>> _transactionHistoryStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('customers')
        .doc(widget.customerId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList());
  }

  double _totalRemaining = 0.0;
  // double _totalRemaining = transactions.first.remainingAmount;
  // int _visibleItemCount = 15; // প্রথমে ১৫টি আইটেম দেখানো হবে

  // void _loadMoreItems() {
  //   setState(() {
  //     _visibleItemCount += 10; // প্রতি বার আরো ১০টি করে আইটেম লোড হবে
  //   });
  // }




  late Future<List<Transaction>> _transactionHistory;

  @override
  void initState() {
    super.initState();
    _transactionHistory = fetchCustomerHistory();


    // এখানে _transactionHistoryStream() এর সাথে listen করে _totalRemaining আপডেট করুন
    _transactionHistoryStream().listen((transactions) {

      _totalRemaining =  transactions.first.remainingAmount;
      // setState(() {
      //   _totalRemaining = transactions.first.remainingAmount;
      // });

    });
  }



  Future<List<Transaction>> fetchCustomerHistory() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('customers')
        .doc(widget.customerId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .get();

    List<Transaction> transactions = querySnapshot.docs
        .map((doc) => Transaction.fromFirestore(doc))
        .toList();

    if (transactions.isNotEmpty) {

      _totalRemaining = transactions.first.remainingAmount;
    }
    return transactions;
  }

  Future<void> updateTransactionAndRecalculate(Transaction transaction, double newTotalSale, double newCashPayment) async {
    final transactionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('customers')
        .doc(widget.customerId)
        .collection('history')
        .doc(transaction.id);

    double previousRemainingAmount = transaction.remainingAmount;
    double newRemainingAmount =
        previousRemainingAmount + (newTotalSale - newCashPayment);

    await transactionRef.update({
      'totalSale': newTotalSale,
      'cashPayment': newCashPayment,
      'remainingAmount': newRemainingAmount,
    });

    recalculateRemainingAmounts();
  }

  Future<void> recalculateRemainingAmounts() async {
    QuerySnapshot historySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('customers')
        .doc(widget.customerId)
        .collection('history')
        .orderBy('timestamp')
        .get();

    double cumulativeRemainingAmount = 0.0;

    for (var doc in historySnapshot.docs) {
      double totalSale = doc['totalSale'];
      double cashPayment = doc['cashPayment'];
      // cumulativeRemainingAmount += (totalSale - cashPayment)
      cumulativeRemainingAmount = cumulativeRemainingAmount + (totalSale - cashPayment);


      await doc.reference.update({
        'remainingAmount': cumulativeRemainingAmount,
      });
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('customers')
        .doc(widget.customerId)
        .update({
      'transaction':cumulativeRemainingAmount,
    });
  }


///////////////////////////////////////////////////////////////////


  Future<void> _editTransaction(Transaction transaction) async {
    TextEditingController totalSaleController = TextEditingController(text: transaction.totalSale.toString());
    TextEditingController cashPaymentController = TextEditingController(text: transaction.cashPayment.toString());
    TextEditingController descriptionController = TextEditingController(text: transaction.description);
    TextEditingController imageController = TextEditingController(text: transaction.imageUrl);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("লেনদেন সম্পাদনা করুন"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: totalSaleController,
                  decoration: const InputDecoration(labelText: "মোট বিক্রি"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: cashPaymentController,
                  decoration: const InputDecoration(labelText: "ক্যাশ পেমেন্ট"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: "বিস্তারিত"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("বাতিল"),
            ),
            TextButton(
              onPressed: () async {
                double newTotalSale = double.parse(totalSaleController.text);
                double newCashPayment = double.parse(cashPaymentController.text);
                String newDescription = descriptionController.text;
                String newImage = imageController.text;

                double cashDifference = newCashPayment - transaction.cashPayment;
                double oldTotalSale = transaction.totalSale;
                double oldCashPayment = transaction.cashPayment;
                // List<String> words = newDescription.split(' ');
                // যদি শব্দ সংখ্যা ১০ এর বেশি হয় তবে শেষের ১০টি শব্দ নেয়া হবে, না হলে পুরোটা।
                // String trimmedDetails = words.length > 10
                //     ? words.sublist(words.length - 10).join(' ')
                //     : newDescription;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userId)
                    .collection('customers')
                    .doc(widget.customerId)
                    .collection('history')
                    .doc(transaction.id)
                    .update({
                  'totalSale': newTotalSale,
                  'cashPayment': newCashPayment,
                  'details': 'edited.. $newDescription\n(পুরানো বিক্রয়: $oldTotalSale টাকা, পুরানো পেমেন্ট: $oldCashPayment টাকা)..',
                  // 'details': 'edited.. $newDescription',
                  'image':newImage,
                  // 'remainingAmount':
                });



                await updateTransactionAndRecalculate(
                    transaction, newTotalSale, newCashPayment);



                setState(() {
                  _transactionHistory = fetchCustomerHistory();
                });


                Navigator.pop(context);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userId)
                    .collection('cashbox')
                    .add({
                  'amount': cashDifference,
                  'time': Timestamp.now(),
                  'reason': ' ${widget.customerName} এর আপডেট হওয়া বিক্রয় লেনদেন\n(পুরানো বিক্রয়: $oldTotalSale টাকা, পুরানো পেমেন্ট: $oldCashPayment টাকা)\nনতুন বিক্রয়: $newTotalSale টাকা, নতুন নগদ পেমেন্ট: $newCashPayment টাকা',

                  // 'reason': ' আপডেট হওয়া ${widget.customerName} er bikroy ট্রানজ্যাকশন (old total $oldTotalSale & old payment $oldCashPayment): new total $newTotalSale & new cash payment $newCashPayment ',
                });
              },
              child: const Text("সংরক্ষণ করুন"),
            ),
            TextButton(
              onPressed: () async {
                bool confirmDelete = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('আপনি কি ডিলিট করতে চান?'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, false);
                          },
                          child: const Text("না"),
                        ),
                        TextButton(
                          onPressed: () async {
                            double newTotalSale = double.parse(totalSaleController.text);
                            double newCashPayment = double.parse(cashPaymentController.text);

                            await updateTransactionAndRecalculate(
                                transaction, newTotalSale, newCashPayment);
                            Navigator.pop(context, true);
                          },
                          child: const Text("হ্যাঁ"),
                        ),
                      ],
                    );
                  },
                );
                // ডিলিট করার সময় ক্যাশবক্স ও মূল হিসাব আপডেট নিশ্চিত করা হচ্ছে
                if (confirmDelete == true) {
                  double deleteAmount = transaction.cashPayment;
                  double totalAmmount = transaction.totalSale;
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .collection('customers')
                      .doc(widget.customerId)
                      .collection('history')
                      .doc(transaction.id)
                      .delete();

                  setState(() {
                    _transactionHistory = fetchCustomerHistory();
                  });




                  Navigator.pop(context);// Close the edit dialog



                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .collection('cashbox')
                      .add({
                    'amount': -deleteAmount,
                    'time': Timestamp.now(),
                    'reason': ' ${widget.customerName} এর ডিলিট হওয়া লেনদেন\n(মোট বিক্রয়: $totalAmmount টাকা, নগদ পরিশোধ: $deleteAmount টাকা)',

                    // 'reason': 'মোট বাকি: $_totalRemaining--${widget.customerName} er ডিলিট হওয়া ট্রানজ্যাকশন: total $totalAmmount & cashpayment $deleteAmount',
                  });





                }
              },
              child: const Text("ডিলিট"),
            ),
          ],
        );
      },
    );
  }



  String formatDateWithBengaliMonth(DateTime date) {
    const List<String> bengaliMonths = [
      'জানুয়ারী',
      'ফেব্রুয়ারী',
      'মার্চ',
      'এপ্রিল',
      'মে',
      'জুন',
      'জুলাই',
      'অগস্ট',
      'সেপ্টেম্বর',
      'অক্টোবর',
      'নভেম্বর',
      'ডিসেম্বর'
    ];

    String day = date.day.toString();
    String month = bengaliMonths[date.month - 1];
    String year = date.year.toString();

    return '$day $month $year';
  }

  String convertToBengaliDigits(double value) {
    String bengaliDigits = '';
    String valueStr = value.toStringAsFixed(2);
    List<String> digits = valueStr.split('.');

    for (int i = 0; i < digits[0].length; i++) {
      bengaliDigits += _getBengaliDigit(digits[0][i]);
    }

    bengaliDigits += '.';

    for (int i = 0; i < digits[1].length; i++) {
      bengaliDigits += _getBengaliDigit(digits[1][i]);
    }

    return bengaliDigits;
  }

  String _getBengaliDigit(String digit) {
    switch (digit) {
      case '0':
        return '০';
      case '1':
        return '১';
      case '2':
        return '২';
      case '3':
        return '৩';
      case '4':
        return '৪';
      case '5':
        return '৫';
      case '6':
        return '৬';
      case '7':
        return '৭';
      case '8':
        return '৮';
      case '9':
        return '৯';
      default:
        return digit;
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url,
          mode: LaunchMode
              .externalApplication); // Opens the dialer app externally
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': 'Hello, this is a test message'},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri,
          mode: LaunchMode.externalApplication); // Launch externally
    } else {
      throw 'Could not launch SMS app';
    }
  }

  void _showImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.network(imageUrl),
          ),
        );
      },
    );
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////

  // Stream<List<Transaction>> _transactionHistoryStream() async* {
  //   yield snapshot.data!.take(_currentTransactionLimit).toList();
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customerName} এর লেনদেন'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Customer Name and Photo
          Container(
            padding: const EdgeInsets.all(10.0),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30.0,
                  backgroundImage: NetworkImage(widget.customerImageUrl),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customerName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.customerPhoneNumber,
                        style:
                        const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () => _makeCall(widget.customerPhoneNumber),
                ),
                IconButton(
                  icon: const Icon(Icons.message),
                  onPressed: () => _sendSMS(widget.customerPhoneNumber),
                ),
              ],
            ),
          ),
          // Total Remaining
          StreamBuilder<List<Transaction>>(
            stream: _transactionHistoryStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return const Center(
                    child: Text('Error loading transaction history'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No transactions found'));
              } else {

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'বর্তমান বাকী: ৳${convertToBengaliDigits(_totalRemaining)}',
                    style: const TextStyle(
                        fontSize: 18,
                        color: Colors.red,
                        fontWeight: FontWeight.bold),
                  ),
                );
              }
            },
          ),
          // Transaction Table
          Expanded(
            child: StreamBuilder <List<Transaction>>(
              stream: _transactionHistoryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(
                      child: Text('লেনদেনের ইতিহাস লোড করতে সমস্যা হয়েছে'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('কোনো লেনদেন পাওয়া যায়নি'));
                } else {
                  // final totalTransactions = snapshot.data!;
                  // final visibleTransactions = totalTransactions.take(_visibleItemCount).toList();

                  return Column(
                    children: [
                      // Fixed Table Header
                      Table(
                        border: TableBorder.all(color: Colors.black, width: 1),
                        columnWidths: const {
                          0: FlexColumnWidth(2), // For date and image
                          1: FlexColumnWidth(1), // For total sale
                          2: FlexColumnWidth(1), // For cash payment
                        },
                        children: [
                          TableRow(
                            decoration:
                            BoxDecoration(color: Colors.lightBlue[100]),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'লেনদেনের বিবরণ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'মোট মূল্য',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'পরিশোধ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Transaction List

                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children:
                            // itemCount: visibleTransactions.length,
                            List.generate(snapshot.data!.length, (index) {
                              final transaction = snapshot.data![index];
                              return GestureDetector(
                                  onTap: () {
                                    _editTransaction(transaction); // ট্যাপ করলে এডিট অপশন ওপেন হবে
                                  },
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  // Display remainingAmount, date, icon for image, and description


                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // Display remainingAmount
                                                      Text(
                                                        'মোট বাকি: ${convertToBengaliDigits(transaction.remainingAmount)}৳',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold),
                                                      ),
                                                      Row(
                                                        mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                        children: [
                                                          // Display date
                                                          Text(
                                                            formatDateWithBengaliMonth(
                                                                transaction
                                                                    .date),
                                                            style:
                                                            const TextStyle(
                                                                fontSize:
                                                                12),
                                                          ),
                                                          // Display the image icon
                                                          if (transaction
                                                              .imageUrl !=
                                                              null)
                                                            IconButton(
                                                              icon: const Icon(
                                                                  Icons.image,
                                                                  size: 20.0),
                                                              onPressed: () {
                                                                _showImage(
                                                                    context,
                                                                    transaction
                                                                        .imageUrl!);
                                                              },
                                                            ),
                                                        ],
                                                      ),
                                                      Row(
                                                        mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                        children: [
                                                          // Display date
                                                          Text(
                                                            '${transaction.totalSale - transaction.cashPayment < 0 ? 'জমা/ পরিশোধ' : 'বাকি পরিমাণ'}: ${convertToBengaliDigits((transaction.totalSale - transaction.cashPayment).abs())}৳',
                                                            style:
                                                            const TextStyle(
                                                                fontSize:
                                                                12),
                                                          ),
                                                          // Display the image ico
                                                        ],
                                                      ),

                                                      // Display date
                                                      // Add some spacing

                                                      Container(
                                                        // Wrap with Container to control size
                                                        constraints:
                                                        BoxConstraints(
                                                          maxWidth: MediaQuery.of(
                                                              context)
                                                              .size.width * 0.5, // Set a max width for the text
                                                        ),
                                                        child: Text(
                                                          'বিস্তারিত: ${transaction.description}',
                                                          style:
                                                          const TextStyle(
                                                              fontSize: 10),
                                                          maxLines:7,
                                                          // Limit to 2 lines; adjust as needed
                                                          overflow: TextOverflow
                                                              .ellipsis, // Use ellipsis for overflow
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                child: Text(
                                                  '৳${convertToBengaliDigits(transaction.totalSale)}',
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                      FontWeight.bold),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                child: Text(
                                                  '৳${convertToBengaliDigits(transaction.cashPayment)}',
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                      FontWeight.bold),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: Colors.black), // Row divider
                                    ],
                                  ));
                            }),
                          ),
                        ),
                      ),

                      // if (_visibleItemCount < totalTransactions.length)
                      //   ElevatedButton(
                      //     onPressed: _loadMoreItems,
                      //     child: Text('আরো দেখুন'),
                      //   ),

                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
