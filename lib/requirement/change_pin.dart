import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChangePinScreen extends StatefulWidget {
  @override
  _ChangePinScreenState createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _oldPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmNewPinController = TextEditingController();

  bool _isOldPinVisible = false; // বর্তমান পিন দেখানোর কন্ট্রোলার
  bool _isNewPinVisible = false; // নতুন পিন দেখানোর কন্ট্রোলার
  bool _isConfirmNewPinVisible = false; // নিশ্চিত পিন দেখানোর কন্ট্রোলার

  void _changePin() async {
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      String uid = currentUser.uid;
      String oldPin = _oldPinController.text.trim();
      String newPin = _newPinController.text.trim();
      String confirmNewPin = _confirmNewPinController.text.trim();

      // Check if the new PIN and confirm PIN are both 4 digits
      if (newPin.length != 4 || confirmNewPin.length != 4) {
        _showMessage('পিন ৪ সংখ্যার হতে হবে');
        return;
      }

      // Check if new PIN matches the confirm PIN
      if (newPin != confirmNewPin) {
        _showMessage('নতুন পিন এবং নিশ্চিত পিন মিলছে না');
        return;
      }

      try {
        // Fetch the stored PIN from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        String storedPin = userDoc['pin']; // Assuming the PIN is stored under 'pin'

        // Check if the old PIN matches the stored PIN
        if (oldPin != storedPin) {
          _showMessage('বর্তমান পিন সঠিক নয়');
          return;
        }

        // Update the PIN in Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'pin': newPin,
        });

        _showMessage('পিন সফলভাবে পরিবর্তন হয়েছে', isSuccess: true);

        // Close the screen or pop the dialog after success
        Navigator.of(context).pop();
      } catch (e) {
        _showMessage('পিন পরিবর্তন করতে ব্যর্থ হয়েছে: $e');
      }
    }
  }

  // Helper function to show messages
  void _showMessage(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('পিন পরিবর্তন করুন'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.redAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    'এখানে ৪ সংখ্যার পিন দিতে হবে',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 30),
                _buildPinInputField('বর্তমান পিন দিন', _oldPinController, _isOldPinVisible, () {
                  setState(() {
                    _isOldPinVisible = !_isOldPinVisible;
                  });
                }),
                SizedBox(height: 10),
                _buildPinInputField('নতুন পিন (৪ সংখ্যার)', _newPinController, _isNewPinVisible, () {
                  setState(() {
                    _isNewPinVisible = !_isNewPinVisible;
                  });
                }),
                SizedBox(height: 10),
                _buildPinInputField('নতুন পিন নিশ্চিত করুন', _confirmNewPinController, _isConfirmNewPinVisible, () {
                  setState(() {
                    _isConfirmNewPinVisible = !_isConfirmNewPinVisible;
                  });
                }),
                SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _changePin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black,
                    textStyle: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 18,
                    ),
                  ),
                  child: Text(
                    'পরিবর্তন করুন',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget for PIN input fields with toggle visibility feature
  Widget _buildPinInputField(String label, TextEditingController controller, bool isPinVisible, VoidCallback toggleVisibility) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 70.0), // দুই পাশ থেকে 40 পিক্সেল কমানো
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white),
          filled: true,
          fillColor: Colors.white24,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              isPinVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
            ),
            onPressed: toggleVisibility,
          ),
        ),
        style: TextStyle(color: Colors.white),
        keyboardType: TextInputType.number,
        obscureText: !isPinVisible,
        maxLength: 4,
        textAlign: TextAlign.center, // টেক্সট সেন্টারে টাইপ হবে
      ),
    );
  }
}
