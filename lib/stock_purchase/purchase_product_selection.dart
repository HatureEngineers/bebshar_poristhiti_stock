import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductSelectionPage extends StatefulWidget {
  @override
  _ProductSelectionPageState createState() => _ProductSelectionPageState();
}

class _ProductSelectionPageState extends State<ProductSelectionPage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  String searchQuery = '';
  bool isLoading = false;
  DocumentSnapshot? lastFetchedDocument;
  final int initialFetchCount = 15;
  final int loadMoreCount = 10;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  void _fetchProducts({bool isLoadMore = false}) {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // ফায়ারস্টোরের কুয়েরি রিয়েল-টাইম স্ট্রিমের জন্য
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stock')
          .orderBy('name')
          .limit(isLoadMore && lastFetchedDocument != null
              ? loadMoreCount
              : initialFetchCount);

      if (isLoadMore && lastFetchedDocument != null) {
        query = query.startAfterDocument(lastFetchedDocument!);
      }

      // snapshots ব্যবহার করলে রিয়েল-টাইম আপডেট পেতে পারেন
      query.snapshots().listen((snapshot) {
        setState(() {
          if (snapshot.docs.isNotEmpty) {
            products = snapshot.docs
                .map((doc) => {
                      'name': doc['name'] ?? 'Unknown',
                      'purchase_price': doc['purchase_price'] ?? 0,
                      'totalAmount': doc['totalAmount'] ?? 0,
                    })
                .toList();
            filteredProducts = products;
            lastFetchedDocument = snapshot.docs.last;
          }
        });
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _selectProduct(Map<String, dynamic> product) {
    Navigator.pop(context, {
      'name': product['name'],
      'totalAmount': product['totalAmount'],
      'purchase_price':
          product['purchase_price'], // এখন বিক্রয় মূল্য পাঠানো হচ্ছে
    });
  }

  void _filterProducts(String query) {
    setState(() {
      searchQuery = query;
      filteredProducts = products.where((product) {
        final productName = product['name'].toLowerCase();
        final searchLower = query.toLowerCase();
        return productName.contains(searchLower);
      }).toList();
    });
  }

  Future<void> _showAddProductDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20), // কোনাগুলো গোলাকার করার জন্য
          ),
          title: Text('নতুন পণ্য যুক্ত করুন'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'পণ্যের নাম'),
              ),
              TextField(
                controller: _purchasePriceController,
                decoration: InputDecoration(labelText: 'ক্রয় মূল্য (৳)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _salePriceController,
                decoration: InputDecoration(labelText: 'বিক্রয় মূল্য (৳)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _totalAmountController,
                decoration: InputDecoration(labelText: 'পরিমাণ'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('বাতিল'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.green, // বাটনের ব্যাকগ্রাউন্ড রঙ পরিবর্তন
                foregroundColor: Colors.white, // টেক্সটের রঙ পরিবর্তন
                padding: EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10), // প্যাডিং
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10), // বাটনের কোণ গোলাকার করা
                ),
              ),
              onPressed: () async {
                if (_nameController.text.isNotEmpty &&
                    _purchasePriceController.text.isNotEmpty &&
                    _totalAmountController.text.isNotEmpty) {
                  await _addProduct();
                  Navigator.pop(context);
                  _resetData();
                }
              },
              child: Text('যুক্ত করুন'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addProduct() async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      String productName = _nameController.text;

      // Check if product with the same name already exists
      QuerySnapshot existingProduct = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stock')
          .where('name', isEqualTo: productName)
          .limit(1)
          .get();

      if (existingProduct.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('এই নামের পণ্য ইতিমধ্যেই আছে')),
        );
        return;
      }

      // Validate and parse user inputs for price and totalAmount as double
      double purchase_price =
          double.tryParse(_purchasePriceController.text) ?? 0.0;
      double sale_price = double.tryParse(_salePriceController.text) ?? 0.0;
      double totalAmount = double.tryParse(_totalAmountController.text) ?? 0.0;

      if (purchase_price <= 0 || totalAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('মূল্য এবং পরিমাণ সঠিকভাবে পূরণ করুন')),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stock')
          .add({
        'name': productName,
        'purchase_price': purchase_price,
        'sale_price': sale_price,
        'quantity': totalAmount,
        'totalAmount': totalAmount,
        'isPacket': true,
        'size': 0.0, // Setting size as double
        'stockUnit': 'pcs',
        'unitUnit': 'kg',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('পণ্য সফলভাবে যুক্ত হয়েছে')),
      );

      _nameController.clear();
      _purchasePriceController.clear();
      _salePriceController.clear();
      _totalAmountController.clear();
      _resetData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('পণ্য যুক্ত করতে সমস্যা হয়েছে')),
      );
    }
  }

  void _resetData() {
    products.clear();
    filteredProducts.clear();
    lastFetchedDocument = null;
    _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Center(child: Text('পণ্য নির্বাচন')),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: _filterProducts,
                  decoration: InputDecoration(
                    labelText: 'পণ্য অনুসন্ধান করুন',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scrollNotification) {
                    if (scrollNotification.metrics.pixels ==
                            scrollNotification.metrics.maxScrollExtent &&
                        !isLoading) {
                      _fetchProducts(isLoadMore: true);
                    }
                    return true;
                  },
                  child: filteredProducts.isEmpty
                      ? Center(
                          child: isLoading
                              ? CircularProgressIndicator()
                              : Text('কোনো পণ্য নেই'))
                      : ListView.builder(
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return Card(
                              margin: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              elevation: 4,
                              child: ListTile(
                                title: Text(
                                  product['name'],
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  'মজুদ পরিমাণ: ${product['totalAmount']}',
                                  style: TextStyle(color: Colors.blueGrey),
                                ),
                                trailing: Text(
                                  'ক্রয় মূল্যঃ ৳${product['purchase_price']}',
                                  style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold),
                                ),
                                onTap: () => _selectProduct(product),
                              ),
                            );
                          },
                        ),
                ),
              ),
              if (isLoading)
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showAddProductDialog,
              backgroundColor: Colors.blue,
              child: Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
