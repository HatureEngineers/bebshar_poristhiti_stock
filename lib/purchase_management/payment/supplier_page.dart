import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../Supplier_transaction_history.dart';
import '../old_supplier_purchase.dart';
import '../purchase_new_supplier.dart';

class SupplierPage extends StatefulWidget {
  @override
  _SupplierPageState createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  String _searchText = ""; // সার্চ টেক্সট ধারণ করার জন্য
  DocumentSnapshot? _lastDocument; // শেষ ফেচ করা ডকুমেন্ট
  bool _hasMoreData = true; // আরও ডেটা আছে কিনা চেক করার জন্য
  List<DocumentSnapshot> _suppliers = []; // লোড করা সাপ্লায়ারের তালিকা
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
      _loadSuppliers(userId,
          isInitialLoad: true); // Initial load with 15 documents
    }
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
          title: Text('সাপ্লায়ার/পার্টির হিসাব'),
        ),
        body: Center(
          child: Text('User is not logged in.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text("সাপ্লায়ার/পার্টির হিসাব"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PurchaseNewSupplier(
                          appBarTitle: 'সাপ্লায়ার যুক্ত করুন',
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
                MaterialPageRoute(builder: (context) => OldSupplierPurchase()),
              );
            },
            child: Text('পরিশোধ'),
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
                child: _buildSupplierList(
                    userId)), // Pass the userId to the Supplier list
          ],
        ),
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
            var supplierData = supplier.data() as Map<String, dynamic>;
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
    String supplierId =
        supplier.id; // Get the supplier ID to pass to the next page

    String transaction = (supplierData?['transaction'] is List)
        ? (supplierData?['transaction'] as List<dynamic>).join(", ")
        : supplierData?['transaction']?.toString() ?? '0';

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          _showImageDialog(context, imageUrl, supplier);
        },
        child: CircleAvatar(
          backgroundImage: NetworkImage(imageUrl),
          onBackgroundImageError: (_, __) => AssetImage('assets/error.jpg'),
        ),
      ),
      title: Text(name),
      subtitle: Text(phone),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '৳ ${convertToBanglaNumber((supplierData?['transaction'] ?? '0').toString())}',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              // Navigate to supplierHistoryPage with both userId and supplierId
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SupplierHistoryPage(
                    userId: userId, // Pass the userId
                    supplierId: supplierId, // Pass the supplierId
                    supplierName: name, // Pass the supplierName
                    supplierImageUrl: imageUrl,
                    supplierPhoneNumber: phone, // Pass the supplierImageUrl
                  ),
                ),
              );
            },
            child: Row(
              children: [
                Icon(
                  Icons.remove_red_eye,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
      onTap: () {
        _showEditPopup(context, userId, supplier);
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
    int fetchLimit =
        isInitialLoad ? 15 : 10; //১৫টি প্রথমে আর পরে ১০টি করে লোড নিবে

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
      BuildContext context, String imageUrl, DocumentSnapshot supplier) {
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
                      await _pickAndUploadImage(context, supplier);
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
      BuildContext context, DocumentSnapshot supplier) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      String fileName = 'supplier_images/${supplier.id}.jpg';
      try {
        Reference storageReference =
            FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageReference.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(getCurrentUserId() ?? '')
            .collection('suppliers')
            .doc(supplier.id)
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
      BuildContext context, String userId, DocumentSnapshot supplier) {
    TextEditingController nameController =
        TextEditingController(text: supplier['name']);
    TextEditingController phoneController =
        TextEditingController(text: supplier['phone']);

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
                  _showDeleteConfirmation(context, supplier);
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
                decoration: InputDecoration(labelText: 'ফোন নম্বর'),
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
                    backgroundColor: Colors.green,
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
                        .collection('suppliers')
                        .doc(supplier.id)
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
      BuildContext context, DocumentSnapshot supplier) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ডিলিট নিশ্চিত করুন'),
          content: Text(
              'আপনি কি ${supplier['name']} নামের সাপ্লায়ারকে ডিলিট করতে চান? আপনি যদি ডিলিট করেন তাহলে ${supplier['name']}-এর সকল লেনদেনের হিসাব মুছে যাবে।'),
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
                    // পিন সঠিক হলে সাপ্লায়ার ডিলিট করুন
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(getCurrentUserId() ?? '')
                        .collection('suppliers')
                        .doc(supplier.id)
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
                      .collection('suppliers')
                      .doc(supplier.id)
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
