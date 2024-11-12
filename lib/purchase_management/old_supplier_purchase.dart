import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class OldSupplierPurchase extends StatefulWidget {
  @override
  _OldSupplierPurchaseState createState() => _OldSupplierPurchaseState();
}

class _OldSupplierPurchaseState extends State<OldSupplierPurchase> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> originalList = [];
  List<Map<String, dynamic>> filteredList = [];
  File? _imageFile; // To store the captured image
  DateTime? _dueDate;
  bool _isSmsIconActive = true; // SMS আইকনের স্ট্যাটাস ট্র্যাক করার জন্য ভ্যারিয়েবল
  String selectedSupplierName = '';
  String selectedPhoneNumber = '';
  DateTime transactionDate = DateTime.now();
  double transactionAmount = 0.0;
  double dueAmount = 0.0;
  List<Map<String, dynamic>> loadedList = [];
  int _documentLimit = 15; // শুরুতে ১৫টা ডকুমেন্ট দেখাবে
  bool _isLoadingMore = false; // অতিরিক্ত ডেটা লোড হচ্ছে কিনা চেক করার জন্য
  DocumentSnapshot? _lastDocument; // সর্বশেষ ডকুমেন্ট সংরক্ষণ


  @override
  void initState() {
    super.initState();
    _fetchDueData();
  }

  String? getCurrentUserId() {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  void _fetchDueData() async {
    String? userId = getCurrentUserId();
    if (userId != null) {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('suppliers')
          .limit(_documentLimit); // প্রথমে ১৫টা ডেটা লোড করবো

      query.snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          setState(() {
            originalList = snapshot.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return {
                'name': data['name'] ?? 'Unknown',
                'amount': data['transaction'] ?? 0,
                'image': data['image'] ?? 'assets/error.jpg',
                'phone': data['phone'] ?? 'নাম্বার যুক্ত নেই',
              };
            }).toList();
            filteredList = originalList;
            _lastDocument = snapshot.docs.last; // সর্বশেষ ডকুমেন্ট সেভ করা
          });
          print('Initial 15 documents loaded: ${originalList.length}');
        }
      });
    } else {
      setState(() {
        originalList = [];
        filteredList = [];
      });
    }
  }
  void loadMoreData() async {
    if (!_isLoadingMore && _lastDocument != null) {
      setState(() {
        _isLoadingMore = true;
      });

      String? userId = getCurrentUserId();
      if (userId != null) {
        Query query = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('suppliers')
            .startAfterDocument(_lastDocument!)
            .limit(10); // পরবর্তীতে ১০টা করে ডেটা লোড করবো

        QuerySnapshot snapshot = await query.get();
        if (snapshot.docs.isNotEmpty) {
          setState(() {
            originalList.addAll(snapshot.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return {
                'name': data['name'] ?? 'Unknown',
                'amount': data['transaction'] ?? 0,
                'image': data['image'] ?? 'assets/error.jpg',
                'phone': data['phone'] ?? 'নাম্বার যুক্ত নেই',
              };
            }).toList());
            filteredList = originalList;
            _lastDocument = snapshot.docs.last;
          });
          print('Loaded 10 more documents: Total documents now = ${originalList.length}');
        }
      }
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != _dueDate) {
      setState(() { // UI আপডেট করার জন্য setState যুক্ত করা হয়েছে
        _dueDate = picked;
      });
    }
  }

  void scheduleNotification(String? supplierName, String? phoneNumber, DateTime? dueDate, double? transactionAmount, double? dueAmount) {
    String safeSupplierName = supplierName ?? 'অজানা';
    // String safePhoneNumber = phoneNumber ?? 'নম্বর নেই';
    String safeDueDate = dueDate != null ? DateFormat('dd MMM yyyy').format(dueDate) : 'তারিখ নেই'; // দেনা টাকা পরিশোধের তারিখ
    double safeDueAmount = dueAmount ?? 0.0;

    String notificationTitle = 'দেনা পরিশোধ করুন';
    // ফোনঃ $safePhoneNumber দিতে চাইলে।
    String notificationDescription = '$safeSupplierName, '
        '$safeDueAmount টাকা পাবে, আজকে $safeDueDate তারিখের মধ্যে পরিশোধ করতে হবে।';

    FirebaseFirestore.instance
        .collection('users')
        .doc(getCurrentUserId())
        .collection('user_notifications')
        .add({
      'title': notificationTitle,
      'description': notificationDescription,
      'time': dueDate != null ? Timestamp.fromDate(dueDate) : FieldValue.serverTimestamp(), // নির্বাচিত তারিখ
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }


  void _filterDueList(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredList = originalList;
      } else {
        filteredList = originalList.where((supplier) {
          return supplier['name'].toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<String?> _uploadImage(File imageFile) async {
    String? userId = getCurrentUserId();
    if (userId != null) {
      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('purchases_images/$userId/${DateTime.now().toString()}.jpg');
      UploadTask uploadTask = storageReference.putFile(imageFile);
      TaskSnapshot storageSnapshot = await uploadTask.whenComplete(() => null);
      return await storageSnapshot.ref.getDownloadURL();
    }
    return null;
  }

  void _showDetails(int index) {
    final supplier = filteredList[index];
    TextEditingController totalPurchaseController = TextEditingController();
    TextEditingController cashPaymentController = TextEditingController();
    TextEditingController detailsController = TextEditingController(); // New text field for details

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: Container(
            width: screenWidth * 0.8,
            // height: screenHeight * 0.55, // Adjusted height for new text field
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          supplier['name'],
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () =>{ Navigator.pop(context), setState(() {
                            _dueDate = null; // Clear the selected date
                          })}
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'মোট দেনা: ${supplier['amount']}৳',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: TextField(
                      controller: totalPurchaseController,
                      decoration: InputDecoration(
                        labelText: 'মোট ক্রয় মূল্য লিখুন',
                        border: InputBorder.none,
                        icon: Icon(Icons.attach_money, color: Colors.green),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: TextField(
                      controller: cashPaymentController,
                      decoration: InputDecoration(
                        labelText: 'নগদ পরিশোধ',
                        border: InputBorder.none,
                        icon: Icon(Icons.money_off, color: Colors.orange),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: TextField(
                      controller: detailsController, // New text field
                      decoration: InputDecoration(
                        labelText: 'লেনদেনের বিবরণ লিখুন',
                        border: InputBorder.none,
                        icon: Icon(Icons.description, color: Colors.blue),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // ক্যালেন্ডার আইকন
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null && picked != _dueDate) {
                            setState(() {
                              _dueDate = picked;
                            });
                          }
                        },
                      ),
                      Text(
                        _dueDate == null
                            ? 'দেনা পরিশোধের তারিখ'
                            : 'নির্বাচিত তারিখ: ${DateFormat('dd MMM yyyy').format(_dueDate!)}',
                        textAlign: TextAlign.center,
                      ),
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _dueDate = null; // Clear the selected date
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.camera_alt, color: Colors.grey),
                            onPressed: _pickImage,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.sms,
                              color: _isSmsIconActive ? Colors.blue : Colors.grey, // SMS আইকনের রং পরিবর্তন
                            ),
                            onPressed: () {
                              setState(() {
                                _isSmsIconActive = !_isSmsIconActive; // SMS আইকনের সক্রিয় অবস্থা পরিবর্তন
                              });
                              // SMS বাটনের জন্য যেকোনো অ্যাকশন এখানে লিখুন
                            },
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 14.0, horizontal: 25.0),
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: () async {
                          if (totalPurchaseController.text.isNotEmpty) {
                            double totalPurchase =
                            double.parse(totalPurchaseController.text);
                            double cashPayment =
                            cashPaymentController.text.isNotEmpty
                                ? double.parse(cashPaymentController.text)
                                : 0.0;
                            double remaining = totalPurchase - cashPayment;

                            double previousAmount = supplier['amount'];
                            double newAmount =
                                previousAmount + remaining.round();

                            String? imageUrl;
                            if (_imageFile != null) {
                              imageUrl = await _uploadImage(_imageFile!);
                            }

                            await _updateSupplierData(
                                supplier['name'], newAmount);
                            await _addPurchaseToCollections(
                                supplier['name'],
                                totalPurchase,
                                cashPayment,
                                newAmount,
                                detailsController.text, // Add details to collection
                                imageUrl);

                            // Schedule notification only if due date is selected
                            if (_dueDate != null) {
                              scheduleNotification(
                                supplier['name'],
                                selectedPhoneNumber,
                                _dueDate,
                                totalPurchase,
                                remaining,
                              );
                            }
                            setState(() {
                              _dueDate = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("ক্রয় সফল হয়েছে"),
                            ));
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("দয়াকরে মোট ক্রয় মূল্য লিখুন"),
                              backgroundColor: Colors.red,
                            ));
                          }
                        },
                        child: Text(
                          'ক্রয় করুন',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateSupplierData(String supplierName, double newAmount) async {
    String? userId = getCurrentUserId();
    if (userId != null) {
      QuerySnapshot supplierSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('suppliers')
          .where('name', isEqualTo: supplierName)
          .get();

      if (supplierSnapshot.docs.isNotEmpty) {
        DocumentReference supplierDoc = supplierSnapshot.docs.first.reference;
        await supplierDoc.update({'transaction': newAmount});
      }
    }
  }

  Future<void> _addPurchaseToCollections(
      String supplierName,
      double totalPurchase,
      double cashPayment,
      double remainingAmount,
      String details,
      String? imageUrl) async {
    String? userId = getCurrentUserId();
    if (userId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .add({
        'amount': totalPurchase,
        'time': Timestamp.now(),
        'details': details, // Add details to Purchases
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cashbox')
          .add({
        'amount': cashPayment,
        'time': Timestamp.now(),
        'reason': 'মোট ক্রয়: $totalPurchase & বর্তমান দেনা: $remainingAmount',
      });

      QuerySnapshot supplierSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('suppliers')
          .where('name', isEqualTo: supplierName)
          .get();

      if (supplierSnapshot.docs.isNotEmpty) {
        DocumentReference supplierDocRef =
            supplierSnapshot.docs.first.reference;

        await supplierDocRef.collection('history').add({
          'totalPurchase': totalPurchase,
          'cashPayment': cashPayment,
          'remainingAmount': remainingAmount,
          'details': details, // Add details to history
          'image': imageUrl, // Add image URL if available
          'timestamp': Timestamp.now(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('সাপ্লায়ার থেকে ক্রয়'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _filterDueList,
              decoration: InputDecoration(
                labelText: 'সার্চ করুন',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                        loadMoreData(); // স্ক্রোল শেষে লোড করবে
                      }
                      return false;
                    },
                    child: ListView.builder(
                      itemCount: filteredList.length + (_isLoadingMore ? 1 : 0), // লোডিং ইন্ডিকেটর
                      itemBuilder: (context, index) {
                        if (index == filteredList.length) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final supplier = filteredList[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          elevation: 5,
                          margin: EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10.0),
                              child: Image.network(
                                supplier['image'],
                                width: screenWidth * 0.15,
                                height: screenWidth * 0.15,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset('assets/error.jpg'),
                              ),
                            ),
                            title: Text(
                              supplier['name'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${supplier['phone']}'),
                            trailing: Text(
                              '${supplier['amount']}৳',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            onTap: () => _showDetails(index),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
