import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../purchase_management/report/purchase_report.dart';

class SaleReportPage extends StatefulWidget {
  @override
  _SaleReportPageState createState() => _SaleReportPageState();
}

class _SaleReportPageState extends State<SaleReportPage> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final DateFormat _dateFormatter = DateFormat('dd-MM-yyyy');
  final DateFormat _timeFormatter = DateFormat('hh:mm a');
  String _selectedList = 'বিক্রয় লিস্ট';

  final int _initialLimit = 20; // Initial limit for first load
  final int _paginationLimit = 10; // Limit for pagination
  List<DocumentSnapshot> _salesDocuments = []; // Holds the sales documents
  bool _isLoading = false; // Loading indicator
  bool _hasMore = true; // To track if more data is available
  ScrollController _scrollController = ScrollController(); // Scroll controller
  double _totalSales = 0.0; // Holds the total sales amount

  @override
  void initState() {
    super.initState();
    _loadInitialSales(); // Load initial sales data
    _calculateTotalSales(); // Calculate total sales for all data
    _scrollController
        .addListener(_loadMoreSalesOnScroll); // Add scroll listener
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('বিক্রয় রিপোর্ট'),
          backgroundColor: Colors.green,
        ),
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

    // Responsive screen size variables
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('বিক্রয় রিপোর্ট'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: _selectedList,
                  items: [
                    DropdownMenuItem(
                      value: 'বিক্রয় লিস্ট',
                      child: Text('বিক্রয় লিস্ট'),
                    ),
                    DropdownMenuItem(
                      value: 'ক্রয় লিস্ট',
                      child: Text('ক্রয় লিস্ট'),
                    ),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedList = newValue!;

                      // যদি "ক্রয় লিস্ট" নির্বাচন করা হয়
                      if (_selectedList == 'ক্রয় লিস্ট') {
                        // ড্রপডাউন নির্বাচন রিসেট করুন
                        _selectedList =
                            'বিক্রয় লিস্ট'; // ডিফল্ট মানে ফিরিয়ে নিন

                        // PurchaseReport পেজে নেভিগেট করুন
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PurchaseReport(),
                          ),
                        );
                      }
                    });
                  },
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
            SizedBox(height: screenHeight * 0.02),

            // Table Header
            Container(
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
              decoration: BoxDecoration(
                color: Colors.blue[100],
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
                  Text('বিক্রি',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Scrollable Sales Data Table
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _salesDocuments.length,
                itemBuilder: (context, index) {
                  if (index >= _salesDocuments.length)
                    return Center(child: CircularProgressIndicator());

                  var sale = _salesDocuments[index];
                  var saleDate = sale['time'].toDate();
                  var saleAmount = sale['amount'];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_dateFormatter.format(saleDate)),
                        Text(_timeFormatter.format(saleDate)),
                        Text('৳ ${saleAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Total Sales Display
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total: ৳ ${_totalSales.toStringAsFixed(2)}',
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
  Future<void> _loadInitialSales() async {
    setState(() => _isLoading = true);
    print("Loading initial 20 sales..."); // Debug message

    Query salesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('sales')
        .orderBy('time', descending: true)
        .limit(_initialLimit);

    // Filter by date if set
    if (_fromDate != null) {
      salesQuery = salesQuery.where('time', isGreaterThanOrEqualTo: _fromDate);
    }
    if (_toDate != null) {
      salesQuery = salesQuery.where('time', isLessThanOrEqualTo: _toDate);
    }

    QuerySnapshot snapshot = await salesQuery.get();

    setState(() {
      _salesDocuments = snapshot.docs;
      _hasMore = snapshot.docs.length == _initialLimit;
      _isLoading = false;
    });
  }

  // Load more sales data with 10 items
  Future<void> _loadMoreSalesOnScroll() async {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMore) {
      setState(() => _isLoading = true);
      print("Loading next 10 sales..."); // Debug message

      Query salesQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('sales')
          .orderBy('time', descending: true)
          .startAfterDocument(_salesDocuments.last)
          .limit(_paginationLimit);

      // Apply date filters if set
      if (_fromDate != null) {
        salesQuery =
            salesQuery.where('time', isGreaterThanOrEqualTo: _fromDate);
      }
      if (_toDate != null) {
        salesQuery = salesQuery.where('time', isLessThanOrEqualTo: _toDate);
      }

      QuerySnapshot snapshot = await salesQuery.get();

      setState(() {
        _salesDocuments.addAll(snapshot.docs);
        _hasMore = snapshot.docs.length == _paginationLimit;
        _isLoading = false;
      });
    }
  }

  // Calculate total sales based on selected date range
  void _calculateTotalSales() async {
    double total = 0.0;

    Query salesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('sales');

    // Apply date range filters if set
    if (_fromDate != null) {
      salesQuery = salesQuery.where('time', isGreaterThanOrEqualTo: _fromDate);
    }
    if (_toDate != null) {
      salesQuery = salesQuery.where('time', isLessThanOrEqualTo: _toDate);
    }

    QuerySnapshot snapshot = await salesQuery.get();
    for (var doc in snapshot.docs) {
      total += doc['amount'];
    }

    setState(() {
      _totalSales = total;
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
      // Reload sales data and recalculate total after date selection
      _loadInitialSales();
      _calculateTotalSales();
    }
  }
}
