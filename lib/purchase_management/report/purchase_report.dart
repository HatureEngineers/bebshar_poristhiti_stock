import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PurchaseReport extends StatefulWidget {
  @override
  _PurchaseReportState createState() => _PurchaseReportState();
}

class _PurchaseReportState extends State<PurchaseReport> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final DateFormat _dateFormatter = DateFormat('dd-MM-yyyy');
  final DateFormat _timeFormatter = DateFormat('hh:mm a');

  final int _initialLimit = 20; // Initial limit for first load
  final int _paginationLimit = 10; // Limit for pagination
  List<DocumentSnapshot> _purchasesDocuments = []; // Holds the purchases documents
  bool _isLoading = false; // Loading indicator
  bool _hasMore = true; // To track if more data is available
  ScrollController _scrollController = ScrollController(); // Scroll controller
  double _totalPurchases = 0.0; // Holds the total purchases amount

  @override
  void initState() {
    super.initState();
    _loadInitialPurchases(); // Load initial purchases data
    _calculateTotalPurchases(); // Calculate total purchases for all data
    _scrollController
        .addListener(_loadMorePurchasesOnScroll); // Add scroll listener
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the current user ID from Firebase Auth
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('ক্রয় রিপোর্ট'),
          backgroundColor: Colors.blue,
        ),
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

    // Responsive screen size variables
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('ক্রয় রিপোর্ট'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Picker Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ' ক্রয় লিস্ট',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: screenWidth * 0.05, // Responsive font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text('From: '),
                    InkWell(
                      onTap: () => _selectDate(context, isFrom: true),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_fromDate != null
                            ? _dateFormatter.format(_fromDate!)
                            : 'Select'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('To: '),
                    InkWell(
                      onTap: () => _selectDate(context, isFrom: false),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_toDate != null
                            ? _dateFormatter.format(_toDate!)
                            : 'Select'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.02), // Responsive space

            // Table Header
            Container(
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
              decoration: BoxDecoration(
                color: Colors.green[100],
                border: Border(bottom: BorderSide(color: Colors.grey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('তারিখ',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('সময়',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('ক্রয়',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Scrollable Purchases Data Table
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _purchasesDocuments.length,
                itemBuilder: (context, index) {
                  if (index >= _purchasesDocuments.length)
                    return Center(child: CircularProgressIndicator());

                  var purchase = _purchasesDocuments[index];
                  var purchaseDate = purchase['time'].toDate();
                  var purchaseAmount = purchase['amount'];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_dateFormatter.format(purchaseDate)),
                        Text(_timeFormatter.format(purchaseDate)),
                        Text('৳ ${purchaseAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Total purchases Display
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total: ৳ ${_totalPurchases.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Initial load with 20 items
  Future<void> _loadInitialPurchases() async {
    setState(() => _isLoading = true);
    print("Loading initial 20 purchases..."); // Debug message

    Query purchasesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('purchases')
        .orderBy('time', descending: true)
        .limit(_initialLimit);

    // Filter by date if set
    if (_fromDate != null) {
      purchasesQuery = purchasesQuery.where('time', isGreaterThanOrEqualTo: _fromDate);
    }
    if (_toDate != null) {
      purchasesQuery = purchasesQuery.where('time', isLessThanOrEqualTo: _toDate);
    }

    QuerySnapshot snapshot = await purchasesQuery.get();

    setState(() {
      _purchasesDocuments = snapshot.docs;
      _hasMore = snapshot.docs.length == _initialLimit;
      _isLoading = false;
    });
  }
  // Load more purchases data with 10 items
  Future<void> _loadMorePurchasesOnScroll() async {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMore) {
      setState(() => _isLoading = true);
      print("Loading next 10 purchases..."); // Debug message

      Query purchasesQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('purchases')
          .orderBy('time', descending: true)
          .startAfterDocument(_purchasesDocuments.last)
          .limit(_paginationLimit);

      // Apply date filters if set
      if (_fromDate != null) {
        purchasesQuery =
            purchasesQuery.where('time', isGreaterThanOrEqualTo: _fromDate);
      }
      if (_toDate != null) {
        purchasesQuery = purchasesQuery.where('time', isLessThanOrEqualTo: _toDate);
      }

      QuerySnapshot snapshot = await purchasesQuery.get();

      setState(() {
        _purchasesDocuments.addAll(snapshot.docs);
        _hasMore = snapshot.docs.length == _paginationLimit;
        _isLoading = false;
      });
    }
  }

  // Calculate total purchases based on selected date range
  void _calculateTotalPurchases() async {
    double total = 0.0;

    Query purchasesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('purchases');

    // Apply date range filters if set
    if (_fromDate != null) {
      purchasesQuery = purchasesQuery.where('time', isGreaterThanOrEqualTo: _fromDate);
    }
    if (_toDate != null) {
      purchasesQuery = purchasesQuery.where('time', isLessThanOrEqualTo: _toDate);
    }

    QuerySnapshot snapshot = await purchasesQuery.get();
    for (var doc in snapshot.docs) {
      total += doc['amount'];
    }

    setState(() {
      _totalPurchases = total;
    });
  }

  // Function to select date for From/To
  Future<void> _selectDate(BuildContext context, {required bool isFrom}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != (isFrom ? _fromDate : _toDate)) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      // Reload purchases data and recalculate total after date selection
      _loadInitialPurchases();
      _calculateTotalPurchases();
    }
  }
}
