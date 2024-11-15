import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SupplierSelectionPage extends StatefulWidget {
  @override
  _SupplierSelectionPageState createState() => _SupplierSelectionPageState();
}

class _SupplierSelectionPageState extends State<SupplierSelectionPage> {
  String _searchText = ""; // সার্চ টেক্সট ধারণ করার জন্য
  DocumentSnapshot? _lastDocument; // শেষ ফেচ করা ডকুমেন্ট
  bool _hasMoreData = true; // আরও ডেটা আছে কিনা চেক করার জন্য
  List<DocumentSnapshot> _suppliers = []; // লোড করা সাপ্লায়ারের তালিকা
  bool _isLoading = false; // লোডিং ইনডিকেটর
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    String? userId = getCurrentUserId();
    if (userId != null) {
      _loadSuppliers(userId,
          isInitialLoad: true); // Initial load with 15 documents
    }
  }

  String? getCurrentUserId() {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid; // Return the user ID or null if the user is not logged in
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMoreData) {
      String? userId = getCurrentUserId();
      if (userId != null) {
        _loadSuppliers(userId); // Load 10 more documents on scroll
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the user ID
    String? userId = getCurrentUserId();

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('সাপ্লায়ার/পার্টি নির্বাচন'),
        ),
        body: Center(
          child: Text('User is not logged in.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Center(child: Text("সাপ্লায়ার/পার্টি নির্বাচন")),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                SizedBox(height: 10),
                _buildSearchBar(),
                Expanded(
                  child: _buildSupplierList(
                      userId), // Pass the userId to the Supplier list
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () async {
                await _showAddSupplierDialog(context);
                setState(() {}); // নতুন কাস্টমার যুক্ত হলে লিস্ট রিফ্রেশ
              },
              backgroundColor: Colors.green,
              child: Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'সাপ্লায়ার/পার্টি খুঁজুন',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchText = value; // সার্চ টেক্সট আপডেট করুন
        });
      },
    );
  }

  Widget _buildSupplierList(String userId) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('suppliers')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var suppliers = snapshot.data?.docs ?? [];

        // সার্চ টেক্সটের উপর ভিত্তি করে গ্রাহকদের তালিকা ফিল্টার করুন
        if (_searchText.isNotEmpty) {
          suppliers = suppliers.where((supplier) {
            var supplierData = supplier.data();
            var name = supplierData['name'].toString().toLowerCase();
            return name.contains(_searchText.toLowerCase());
          }).toList();
        }

        return ListView.builder(
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            var supplier = suppliers[index];
            return _buildSupplierTile(context, supplier, userId);
          },
        );
      },
    );
  }

  Widget _buildSupplierTile(
      BuildContext context, DocumentSnapshot supplier, String userId) {
    Map<String, dynamic>? supplierData =
        supplier.data() as Map<String, dynamic>?;

    String imageUrl =
        (supplierData != null && supplierData.containsKey('image'))
            ? supplierData['image']
            : 'assets/error.jpg';
    String name = supplierData?['name'] ?? 'Unknown';
    String phone = supplierData?['phone'] ?? 'Unknown';
    double transaction = supplierData?['transaction']?.toDouble() ?? 0.0;

    return ListTile(
      leading: GestureDetector(
        child: CircleAvatar(
          backgroundImage: NetworkImage(imageUrl),
          onBackgroundImageError: (_, __) => AssetImage('assets/error.jpg'),
        ),
      ),
      title: Text(name),
      subtitle: Text(phone),
      trailing: Text(
        '৳ $transaction',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      onTap: () {
        // নির্বাচন করার সময় তথ্য ফেরত পাঠান
        Navigator.pop(context, {
          'name': name,
          'phone': phone,
          'previousTransaction': transaction,
        });
      },
    );
  }

  Future<void> _showAddSupplierDialog(BuildContext context) async {
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _phoneController = TextEditingController();
    final TextEditingController _transactionController =
        TextEditingController();

    String? getCurrentUserId() {
      User? user = FirebaseAuth.instance.currentUser;
      return user?.uid;
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('নতুন সাপ্লায়ার যুক্ত করুন'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'সাপ্লায়ারের নাম'),
                ),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(labelText: 'ফোন নম্বর'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _transactionController,
                  decoration: InputDecoration(labelText: 'পূর্বের লেনদেনের'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('বাতিল করুন'),
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
                String? userId = getCurrentUserId();
                if (userId == null) return;

                String name = _nameController.text.trim();
                String phone = _phoneController.text.trim();
                double transaction =
                    double.tryParse(_transactionController.text.trim()) ?? 0.0;

                // ফিল্ড ভ্যালিডেশন: নাম এবং ফোন নম্বর খালি না হওয়া
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('অনুগ্রহ করে সব তথ্য পূরণ করুন')),
                  );
                  return;
                }

                // ফোন নম্বর ১১ সংখ্যার কিনা চেক করা
                if (phone.length != 11) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('ফোন নম্বর অবশ্যই ১১ সংখ্যার হতে হবে')),
                  );
                  return;
                }

                // পূর্বে নম্বরটি যুক্ত আছে কিনা চেক করা
                final existingSupplier = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('suppliers')
                    .where('phone', isEqualTo: phone)
                    .get();

                if (existingSupplier.docs.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('এই ফোন নম্বরটি ইতিমধ্যেই যুক্ত করা হয়েছে')),
                  );
                  return;
                }

                // Firebase Firestore-এ সাপ্লায়ার তথ্য সেভ করা
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('suppliers')
                    .add({
                  'name': name,
                  'phone': phone,
                  'transaction': transaction,
                  'image': 'assets/error.jpg',
                  'description': '',
                  'transactionDate': DateTime.now(),
                  'uid': userId,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('সাপ্লায়ার সফলভাবে যুক্ত হয়েছে')),
                );
              },
              child: Text('যুক্ত করুন'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSuppliers(String userId,
      {bool isInitialLoad = false}) async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    // Initial load will fetch 15 documents, subsequent fetches will fetch 10.
    int fetchLimit = isInitialLoad ? 15 : 10;

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('suppliers')
        .limit(fetchLimit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    QuerySnapshot querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        _suppliers.addAll(querySnapshot.docs);
        _lastDocument = querySnapshot.docs.last;
        _hasMoreData = querySnapshot.docs.length == fetchLimit;
      });
    } else {
      setState(() {
        _hasMoreData = false;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }
}
