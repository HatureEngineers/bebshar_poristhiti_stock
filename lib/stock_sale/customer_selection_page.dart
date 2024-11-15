import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerSelectionPage extends StatefulWidget {
  @override
  _CustomerSelectionPageState createState() => _CustomerSelectionPageState();
}

class _CustomerSelectionPageState extends State<CustomerSelectionPage> {
  String _searchText = ""; // সার্চ টেক্সট ধারণ করার জন্য
  DocumentSnapshot? _lastDocument; // শেষ ফেচ করা ডকুমেন্ট
  bool _hasMoreData = true; // আরও ডেটা আছে কিনা চেক করার জন্য
  List<DocumentSnapshot> _customers = []; // লোড করা কাস্টমারের তালিকা
  bool _isLoading = false; // লোডিং ইনডিকেটর
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    String? userId = getCurrentUserId();
    if (userId != null) {
      _loadCustomers(userId,
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
        _loadCustomers(userId); // Load 10 more documents on scroll
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
          title: Text('কাস্টমার নির্বাচন'),
        ),
        body: Center(
          child: Text('User is not logged in.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Center(child: Text("কাস্টমার নির্বাচন")),
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
                  child: _buildCustomerList(
                      userId), // Pass the userId to the Customer list
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () async {
                await _showAddCustomerDialog(context);
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
        labelText: 'কাস্টমার খুঁজুন',
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

  Widget _buildCustomerList(String userId) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('customers')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var customers = snapshot.data?.docs ?? [];

        // সার্চ টেক্সটের উপর ভিত্তি করে গ্রাহকদের তালিকা ফিল্টার করুন
        if (_searchText.isNotEmpty) {
          customers = customers.where((customer) {
            var customerData = customer.data();
            var name = customerData['name'].toString().toLowerCase();
            return name.contains(_searchText.toLowerCase());
          }).toList();
        }

        return ListView.builder(
          itemCount: customers.length,
          itemBuilder: (context, index) {
            var customer = customers[index];
            return _buildCustomerTile(context, customer, userId);
          },
        );
      },
    );
  }

  Widget _buildCustomerTile(
      BuildContext context, DocumentSnapshot customer, String userId) {
    Map<String, dynamic>? customerData =
        customer.data() as Map<String, dynamic>?;

    String imageUrl =
        (customerData != null && customerData.containsKey('image'))
            ? customerData['image']
            : 'assets/error.jpg';
    String name = customerData?['name'] ?? 'Unknown';
    String phone = customerData?['phone'] ?? 'Unknown';
    double transaction = customerData?['transaction']?.toDouble() ?? 0.0;

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

  Future<void> _showAddCustomerDialog(BuildContext context) async {
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
          title: Text('নতুন কাস্টমার যুক্ত করুন'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'কাস্টমারের নাম'),
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
                final existingCustomer = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('customers')
                    .where('phone', isEqualTo: phone)
                    .get();

                if (existingCustomer.docs.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('এই ফোন নম্বরটি ইতিমধ্যেই যুক্ত করা হয়েছে')),
                  );
                  return;
                }

                // Firebase Firestore-এ কাস্টমার তথ্য সেভ করা
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('customers')
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
                  SnackBar(content: Text('কাস্টমার সফলভাবে যুক্ত হয়েছে')),
                );
              },
              child: Text('যুক্ত করুন'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadCustomers(String userId,
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
        .collection('customers')
        .limit(fetchLimit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    QuerySnapshot querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        _customers.addAll(querySnapshot.docs);
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
