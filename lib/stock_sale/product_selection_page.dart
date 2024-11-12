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
  final TextEditingController _priceController = TextEditingController();
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
          .limit(isLoadMore && lastFetchedDocument != null ? loadMoreCount : initialFetchCount);

      if (isLoadMore && lastFetchedDocument != null) {
        query = query.startAfterDocument(lastFetchedDocument!);
      }

      // snapshots ব্যবহার করলে রিয়েল-টাইম আপডেট পেতে পারেন
      query.snapshots().listen((snapshot) {
        setState(() {
          if (snapshot.docs.isNotEmpty) {
            products = snapshot.docs.map((doc) => {
              'name': doc['name'] ?? 'Unknown',
              'price': doc['price'] ?? 0,
              'totalAmount': doc['totalAmount'] ?? 0,
            }).toList();
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
    Navigator.pop(context, product);
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
          title: Text('নতুন পণ্য যুক্ত করুন'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'পণ্যের নাম'),
              ),
              TextField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'মূল্য (৳)'),
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
                backgroundColor: Colors.green, // বাটনের ব্যাকগ্রাউন্ড রঙ পরিবর্তন
                foregroundColor: Colors.white, // টেক্সটের রঙ পরিবর্তন
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), // প্যাডিং
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // বাটনের কোণ গোলাকার করা
                ),
              ),
              onPressed: () async {
                if (_nameController.text.isNotEmpty &&
                    _priceController.text.isNotEmpty &&
                    _totalAmountController.text.isNotEmpty) {
                  await _addProduct();
                  Navigator.pop(context);
                  _resetData();
                }
              },
              child: Text('যোগ করুন'),
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
      double price = double.tryParse(_priceController.text) ?? 0.0;
      double totalAmount = double.tryParse(_totalAmountController.text) ?? 0.0;

      if (price <= 0 || totalAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('মূল্য এবং পরিমাণ সঠিকভাবে পূরণ করুন')),
        );
        return;
      }

      double totalPrice = price * totalAmount;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stock')
          .add({
        'name': productName,
        'price': price,
        'quantity': totalAmount,
        'totalAmount': totalAmount,
        'totalPrice': totalPrice,
        'isPacket': true,
        'size': 0.0, // Setting size as double
        'stockUnit': 'pcs',
        'unitUnit': 'gm',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('পণ্য সফলভাবে যুক্ত হয়েছে')),
      );

      _nameController.clear();
      _priceController.clear();
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
        title: Text('পণ্য নির্বাচন'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddProductDialog,
          ),
        ],
      ),
      body: Column(
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
                    margin:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    elevation: 4,
                    child: ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${product['name']} (${product['totalAmount']})',
                              style:
                              TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '৳ ${product['price']}',
                            style: TextStyle(color: Colors.green[700]),
                          ),
                        ],
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
    );
  }
}
