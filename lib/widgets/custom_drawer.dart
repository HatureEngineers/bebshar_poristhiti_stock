import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../bar_chart/report_page.dart';
import '../bill/app_payment.dart';
import '../cash_box/cash_box.dart';
import '../expense/expense.dart';
import '../product_management/UploadExcelPage.dart';
import '../product_management/product.dart';
import '../requirement/change_pin.dart';
import '../requirement/pin_verification_screen.dart';
import '../sales_management/report/sale_report.dart';
import '../sales_management/sale_new_customer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CustomDrawer extends StatefulWidget {
  final String name;
  final String mobile;
  final Function onNameEdit;
  final Function onImagePick;
  final Function toggleTheme;
  final bool isDarkTheme;

  CustomDrawer({
    required this.name,
    required this.mobile,
    required this.onNameEdit,
    required this.onImagePick,
    required this.toggleTheme,
    required this.isDarkTheme,
  });

  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _profileImageUrl;
  String? _userMobileNumber; // To store user's mobile number
  String _userName = '';
  bool showAdditionalButtons = false;
  bool switch1 = true;
  bool switch2 = true;
  bool switch3 = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
    _loadUserMobileNumber();
    _loadPinRequiredStatus();
    _loadEditRequiredStatus();
    _loadDeleteRequiredStatus();
  }

  Future<void> _loadUserData() async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      setState(() {
        _userName =
            userDoc['name'] ?? widget.name; // Fetch username from Firestore
      });
    } catch (e) {
      print("Error fetching user name from Firebase: $e");
    }
  }

  Future<void> _saveUserName(String name) async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      setState(() {
        _profileImageUrl = userDoc['name'];
      });
    } catch (e) {
      print("Error fetching name: $e");
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      setState(() {
        _profileImageUrl = userDoc['profileImageUrl'];
      });
    } catch (e) {
      print("Error fetching profile image: $e");
    }
  }

  Future<void> _loadUserMobileNumber() async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      setState(() {
        _userMobileNumber = userDoc['phone']; // Fetch 'phone' field
      });
    } catch (e) {
      print("Error fetching mobile number: $e");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      await _uploadImageToFirebase();
    }
  }

  Future<void> _uploadImageToFirebase() async {
    try {
      String userId = _auth.currentUser!.uid;
      String fileName = 'profile_$userId.jpg';
      Reference storageRef =
      FirebaseStorage.instance.ref().child('profile_images/$fileName');

      // Read the image file
      final originalImage = img.decodeImage(await _profileImage!.readAsBytes());

      // Resize the image (for example, to 800x800 pixels)
      final resizedImage =
      img.copyResize(originalImage!, width: 600, height: 600);

      // Compress the image to JPEG format with a quality setting
      final compressedImage =
      img.encodeJpg(resizedImage, quality: 50); // Adjust quality as needed

      // Create a temporary file to hold the resized and compressed image
      final tempFile =
      File('${(await getTemporaryDirectory()).path}/$fileName');
      await tempFile.writeAsBytes(compressedImage);

      // Upload the resized and compressed image to Firebase
      UploadTask uploadTask = storageRef.putFile(tempFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'profileImageUrl': downloadUrl});

      setState(() {
        _profileImageUrl = downloadUrl;
      });
    } catch (e) {
      print("Error uploading profile image: $e");
    }
  }

  Future<void> _editName() async {
    TextEditingController controller = TextEditingController(text: _userName);
    FocusNode focusNode = FocusNode();

    String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('নাম পরিবর্তন করুন'),
          content: GestureDetector(
            onTap: () {
              focusNode.requestFocus();
            },
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(hintText: 'এখানে আপনার নাম লিখুন'),
              onTap: () {
                controller.clear();
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('বাতিল'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('সংরক্ষণ'),
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      await _updateNameInFirestore(newName);
      await _saveUserName(newName); // Save the name persistently
      setState(() {
        _userName = newName;
      });
    }
  }

  Future<void> _updateNameInFirestore(String name) async {
    try {
      String userId = _auth.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'name': name});
    } catch (e) {
      print("Error updating name: $e");
    }
  }

  Future<bool> _verifyPinWithFirebase() async {
    // পিন ইনপুট নেওয়ার জন্য ডায়লগ দেখান
    String? enteredPin = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController _pinController = TextEditingController();
        return AlertDialog(
          title: Text('পিন যাচাই করুন'),
          content: TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'পিন লিখুন'),
          ),
          actions: [
            TextButton(
              child: Text('বাতিল'),
              onPressed: () {
                Navigator.of(context).pop(null); // Cancel করলে null ফিরবে
              },
            ),
            TextButton(
              child: Text('যাচাই করুন'),
              onPressed: () {
                Navigator.of(context).pop(_pinController.text); // পিন রিটার্ন করবে
              },
            ),
          ],
        );
      },
    );

    if (enteredPin == null) {
      return false; // যদি ইউজার পিন না দেয় বা বাতিল করে
    }

    try {
      // Firebase Firestore থেকে ইউজারের সেভ করা পিনটি রিড করা
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      String savedPin = userDoc['pin']; // ইউজারের সেভ করা পিন

      // ইউজার ইনপুট করা পিন সেভ করা পিনের সাথে মিলিয়ে দেখা
      if (enteredPin == savedPin) {
        return true; // পিন সঠিক
      } else {
        return false; // পিন ভুল
      }
    } catch (e) {
      print("Error verifying pin with Firebase: $e");
      return false; // কোনো সমস্যা হলে false রিটার্ন
    }
  }

  Future<void> _savePinRequiredStatus(bool isPinRequired) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pinRequired', isPinRequired);

    // ২. Firestore-এ সেভ করুন
    try {
      String userId = _auth.currentUser!.uid; // Get current user ID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'isPinRequired': isPinRequired});
    } catch (e) {
      //প্রিন্ট করে দেখা যাবে
    }
  }
  Future<void> _loadPinRequiredStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // সেভ করা মান যদি থাকে, সেটি লোড করুন; না থাকলে false হিসাবে নিন
    setState(() {
      switch1 = prefs.getBool('pinRequired') ?? false;
    });
  }

  // isEdit আপডেট করার ফাংশন
  Future<void> _updateEditRequiredStatus(bool isEditRequired) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('editRequired', isEditRequired); // 'editRequired' কী নিশ্চিত করুন

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'isEdit': isEditRequired});
    } catch (e) {
    }
  }

  Future<void> _loadEditRequiredStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      switch2 = prefs.getBool('editRequired') ?? false; // 'editRequired' থেকে মান লোড করুন
    });
  }

// isDelete আপডেট করার ফাংশন
  Future<void> _updateDeleteRequiredStatus(bool isDeleteRequired) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('deleteRequired', isDeleteRequired); // 'deleteRequired' কী নিশ্চিত করুন

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'isDelete': isDeleteRequired});
    } catch (e) {
    }
  }

  Future<void> _loadDeleteRequiredStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      switch3 = prefs.getBool('deleteRequired') ?? false; // 'deleteRequired' থেকে মান লোড করুন
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: GestureDetector(
              onTap: _editName, // Update name when tapped
              child: Text(_userName, style: TextStyle(fontSize: 20)),
            ),
            accountEmail: _userMobileNumber != null
                ? Text(
              _userMobileNumber!,
              style: TextStyle(fontSize: 16),
            )
                : Text(
              'Phone number not available',
              style: TextStyle(fontSize: 16),
            ),
            currentAccountPicture: GestureDetector(
              onTap: _pickImage, // Select image when tapped
              child: CircleAvatar(
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : const AssetImage('assets/icon/ic_launcher.png') as ImageProvider,
                backgroundColor: Colors.grey[200],
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.green[400],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.account_balance_wallet,
                  text: 'ক্যাশবক্স',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CashBoxScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.note_alt_outlined,
                  text: 'প্রোডাক্ট যুক্ত করুন',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProductPage()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.list_alt_rounded,
                  text: 'বিক্রির রিপোর্ট',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ReportPage()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.add_chart,
                  text: 'excel',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ExcelUploader()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.add_shopping_cart,
                  text: 'কাস্টমার',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SaleNewCustomer(appBarTitle: 'টেম্পোরারি')),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.shopping_cart,
                  text: 'খরচের হিসাব',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ExpensePage()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.payment_rounded,
                  text: 'বিল পরিশোধ',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AppPaymentPage()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.lock_reset_sharp,
                  text: 'পিন পরিবর্তন করুন',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ChangePinScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.bar_chart,
                  text: 'Bebsar Poristhiti',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SaleReportPage()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  text: 'সেটিংস',
                  onTap: () {
                    setState(() {
                      showAdditionalButtons = !showAdditionalButtons;
                    });
                  },
                ),
                if (showAdditionalButtons) ...[
                  SwitchListTile(
                    title: Text('লগইন এর জন্য পিন'),
                    value: switch1,
                    onChanged: (bool value) async {
                      // পিন যাচাইয়ের জন্য পপআপ ডায়লগ দেখানো হবে
                      bool pinVerified = await _verifyPinWithFirebase();

                      // পিন সঠিক হলে স্যুইচ পরিবর্তন হবে
                      if (pinVerified) {
                        setState(() {
                          switch1 = value;
                        });
                        _savePinRequiredStatus(switch1); // ফায়ারবেসে সংরক্ষণ
                      } else {
                        // পিন ভুল হলে SnackBar-এ মেসেজ দেখানো হবে
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('           পিন সঠিক নয়')),
                        );
                      }
                    },
                  ),
                  // সুইচ ২: এডিট এর জন্য পিন
                  SwitchListTile(
                    title: Text('এডিট এর জন্য পিন'),
                    value: switch2,
                    onChanged: (bool value) async {
                      // পিন যাচাইয়ের জন্য পপআপ ডায়লগ দেখানো হবে
                      bool pinVerified = await _verifyPinWithFirebase();

                      // পিন সঠিক হলে স্যুইচ পরিবর্তন হবে এবং isEdit ফিল্ড আপডেট হবে
                      if (pinVerified) {
                        setState(() {
                          switch2 = value;
                        });
                        _updateEditRequiredStatus(switch2); // isEdit ফিল্ড আপডেট
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('           পিন সঠিক নয়')),
                        );
                      }
                    },
                  ),

                  // সুইচ ৩: ডিলিট এর জন্য পিন
                  SwitchListTile(
                    title: Text('ডিলিট এর জন্য পিন'),
                    value: switch3,
                    onChanged: (bool value) async {
                      // পিন যাচাইয়ের জন্য পপআপ ডায়লগ দেখানো হবে
                      bool pinVerified = await _verifyPinWithFirebase();

                      // পিন সঠিক হলে স্যুইচ পরিবর্তন হবে এবং isDelete ফিল্ড আপডেট হবে
                      if (pinVerified) {
                        setState(() {
                          switch3 = value;
                        });
                        _updateDeleteRequiredStatus(switch3); // isDelete ফিল্ড আপডেট
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('        পিন সঠিক নয়')),
                        );
                      }
                    },
                  ),
                ],
                _buildDrawerItem(
                  icon: Icons.palette,
                  text: 'থিম পরিবর্তন', // Dark Theme toggle
                  onTap: () {
                    widget.toggleTheme();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.logout,
                  text: 'লগ আউট',
                  onTap: () async {
                    // Step 1: Set isPinRequired to true and update SharedPreferences and Firestore
                    await _savePinRequiredStatus(
                        true); // isPinRequired মান true এ সেট হবে

                    // Step 2: Ensure the switch1 is turned ON if it was OFF
                    setState(() {
                      switch1 = true; // switch1 কে true সেট করে দেওয়া হবে
                    });

                    // Step 3: Navigate to PinVerificationScreen
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => PinVerificationScreen(
                          toggleTheme: widget.toggleTheme,
                          isDarkTheme: widget.isDarkTheme,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(
      {required IconData icon, required String text, required Function onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text, style: TextStyle(fontSize: 18)),
      onTap: () => onTap(),
    );
  }
}
