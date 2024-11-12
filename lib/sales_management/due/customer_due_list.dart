import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../customer_transaction_history.dart';
import '../old_customer_sale.dart';
import '../sale_new_customer.dart';

class DuePage extends StatefulWidget {
  @override
  _DuePageState createState() => _DuePageState();
}

class _DuePageState extends State<DuePage> {
  String _searchText = ""; // সার্চ টেক্সট ধারণ করার জন্য
  DocumentSnapshot? _lastDocument; // শেষ ফেচ করা ডকুমেন্ট
  bool _hasMoreData = true; // আরও ডেটা আছে কিনা চেক করার জন্য
  List<DocumentSnapshot> _customers = []; // লোড করা কাস্টমারদের তালিকা
  bool _isLoading = false; // লোডিং ইনডিকেটর
  late ScrollController _scrollController;
  String convertToBanglaNumber(String number) {
    const englishToBanglaDigits = {
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
    };
    String banglaNumber = number.split('').map((digit) {
      return englishToBanglaDigits[digit] ?? digit;
    }).join('');

    return banglaNumber;
  }

  // Fetching the current user's ID from FirebaseAuth
  String? getCurrentUserId() {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid; // Return the user ID or null if the user is not logged in
  }

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
          title: Text('বাকির খাতা'),
        ),
        body: Center(
          child: Text('User is not logged in.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text("বাকির খাতা"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SaleNewCustomer(
                          appBarTitle: 'বাকির খাতায় যুক্ত করুন',
                        )),
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white70,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OldCustomerSale()),
              );
            },
            child: Text('বাকি আদায়'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SizedBox(height: 10),
            _buildSearchBar(),
            Expanded(
                child: _buildCustomerList(
                    userId)), // Pass the userId to the customer list
          ],
        ),
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

        if (_searchText.isNotEmpty) {
          customers = customers.where((customer) {
            var customerData = customer.data() as Map<String, dynamic>;
            var name = customerData['name'].toString().toLowerCase();
            return name.contains(_searchText.toLowerCase());
          }).toList();
        }

        return ListView.builder(
          controller: _scrollController,
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
    String customerId =
        customer.id; // Get the customer ID to pass to the next page

    String transaction = (customerData?['transaction'] is List)
        ? (customerData?['transaction'] as List<dynamic>).join(", ")
        : customerData?['transaction']?.toString() ?? '0';

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          _showImageDialog(context, imageUrl, customer);
        },
        child: CircleAvatar(
          backgroundImage: NetworkImage(imageUrl),
          onBackgroundImageError: (_, __) => AssetImage('assets/error.jpg'),
        ),
      ),
      title: GestureDetector(
        onTap: () {
          _showEditPopup(context, userId, customer);
        },
        child: Text(name),
      ),
      subtitle: GestureDetector(
        onTap: () {
          _showEditPopup(context, userId, customer);
        },
        child: Row(
          children: [
            Icon(
              Icons.call_sharp,
              color: Colors.grey, // Optional: set color
              size: 16, // Optional: set size
            ),
            SizedBox(width: 2), // Space between icon and text
            Text(phone), // Display phone number
          ],
        ),
      ),

      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '৳ ${convertToBanglaNumber((customerData?['transaction'] ?? '0').toString())}',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              // Navigate to CustomerHistoryPage with both userId and customerId
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerHistoryPage(
                    userId: userId, // Pass the userId
                    customerId: customerId, // Pass the customerId
                    customerName: name, // Pass the customerName
                    customerImageUrl: imageUrl,
                    customerPhoneNumber: phone, // Pass the customerImageUrl
                  ),
                ),
              );
            },
            child: Row(
              children: [
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
      onTap: () {
        _showEditPopup(context, userId, customer);
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
    int fetchLimit =
        isInitialLoad ? 15 : 10; //১৫টি প্রথমে আর পরে ১০টি করে লোড নিবে

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

        print('Loaded ${querySnapshot.docs.length} customers'); //দেখার জন্য
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

  Future<bool> _checkIsDelete() async {
    String? userId = getCurrentUserId();
    if (userId != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.get('isDelete') ?? false; // isEdit এর মান চেক করুন
    }
    return false;
  }

  Future<bool> _showPinVerificationDialog(BuildContext context) async {
    TextEditingController pinController = TextEditingController();
    bool pinVerified = false;
    String? userId = getCurrentUserId(); // ইউজারের আইডি নিয়ে আসুন

    if (userId != null) {
      // Firebase থেকে পিন রিট্রিভ করুন
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      String? savedPin = userDoc['pin']; // ফায়ারবেজে সেভ করা পিন

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('পিন যাচাই করুন'),
            content: TextField(
              controller: pinController,
              decoration: InputDecoration(
                labelText: 'পিন প্রবেশ করুন',
              ),
              obscureText: true, // পিন গোপন রাখতে
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  String enteredPin = pinController.text;
                  // ইনপুট পিন Firebase থেকে সেভ করা পিনের সাথে তুলনা করুন
                  if (enteredPin == savedPin) {
                    pinVerified = true; // পিন সঠিক হলে true
                  }
                  Navigator.of(context).pop();
                },
                child: Text('যাচাই করুন'),
              ),
            ],
          );
        },
      );
    }
    return pinVerified; // সঠিক পিন হলে true ফেরত দেবে
  }

  void _showImageDialog(
      BuildContext context, String imageUrl, DocumentSnapshot customer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                imageUrl,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset('assets/error.jpg');
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () async {
                      await _pickAndUploadImage(context, customer);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(
      BuildContext context, DocumentSnapshot customer) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      String fileName = 'customer_images/${customer.id}.jpg';
      try {
        Reference storageReference =
            FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageReference.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(getCurrentUserId() ?? '')
            .collection('customers')
            .doc(customer.id)
            .update({'image': downloadUrl});

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ছবি সফলভাবে আপলোড করা হয়েছে')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ছবি আপলোডে সমস্যা হয়েছে: $e')));
      }
    }
  }

  void _showEditPopup(
      BuildContext context, String userId, DocumentSnapshot customer) {
    TextEditingController nameController =
        TextEditingController(text: customer['name']);
    TextEditingController phoneController =
        TextEditingController(text: customer['phone']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // উভয় পাশে স্পেস দেওয়ার জন্য
            children: [
              Text('এডিট করুন'),
              IconButton(
                icon: Icon(Icons.delete_forever_outlined,
                    color: Colors.red), // ডিলিট আইকন
                onPressed: () {
                  _showDeleteConfirmation(context, customer);
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'নাম'),
              ),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: ' ফোন নম্বর'),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // আপডেট করুন বাটন
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('বাতিল'),
                ),
                // আপডেট করুন বাটন
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(getCurrentUserId() ?? '')
                        .collection('customers')
                        .doc(customer.id)
                        .update({
                      'name': nameController.text,
                      'phone': phoneController.text,
                    });
                    Navigator.pop(context); // ডায়ালগ বন্ধ করা
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('সফলভাবে পরিবর্তন হয়েছে')),
                    );
                  },
                  child: Text('পরিবর্তন করুন'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, DocumentSnapshot customer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ডিলিট নিশ্চিত করুন'),
          content: Text(
              'আপনি কি ${customer['name']} নামের কাস্টমারকে ডিলিট করতে চান? আপনি যদি ডিলিট করেন তাহলে ${customer['name']}-এর সকল বাকির হিসাব মুছে যাবে।'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // প্রথমে isDelete চেক করুন
                bool isDelete = await _checkIsDelete();

                if (isDelete) {
                  // যদি isDelete true হয়, তাহলে পিন ভেরিফিকেশন চালান
                  bool pinVerified = await _showPinVerificationDialog(context);

                  if (pinVerified) {
                    // পিন সঠিক হলে কাস্টমার ডিলিট করুন
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(getCurrentUserId() ?? '')
                        .collection('customers')
                        .doc(customer.id)
                        .delete();
                    Navigator.of(context).pop(); // ডিলিট ডায়ালগ বন্ধ করুন
                    Navigator.of(context).pop(); // এডিট ডায়ালগ বন্ধ করুন
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('সফলভাবে ডিলিট হয়েছে')),
                    );
                  } else {
                    // পিন সঠিক না হলে এরর মেসেজ দেখান
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ভুল পিন, আবার চেষ্টা করুন')),
                    );
                  }
                } else {
                  // যদি isDelete false হয়, সরাসরি ডিলিট করুন
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(getCurrentUserId() ?? '')
                      .collection('customers')
                      .doc(customer.id)
                      .delete();
                  Navigator.of(context).pop(); // ডিলিট ডায়ালগ বন্ধ করুন
                  Navigator.of(context).pop(); // এডিট ডায়ালগ বন্ধ করুন
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('সফলভাবে ডিলিট হয়েছে')),
                  );
                }
              },
              child: Text('হ্যাঁ চাই'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('না'),
            ),
          ],
        );
      },
    );
  }
}
