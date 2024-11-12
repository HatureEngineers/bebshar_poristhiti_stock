import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home_screen.dart';

class PinSetupScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkTheme;

  PinSetupScreen({required this.toggleTheme, required this.isDarkTheme});

  @override
  _PinSetupScreenState createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _pinController = TextEditingController();

  // Save the PIN to Firestore
  void _savePin() async {
    String pin = _pinController.text.trim();
    if (pin.length == 4) {
      try {
        // Save PIN to Firestore for the logged-in user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .set({'pin': pin}, SetOptions(merge: true));

        // Navigate to HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              toggleTheme: widget.toggleTheme,
              isDarkTheme: widget.isDarkTheme,
            ),
          ),
        );
      } catch (e) {
        _showSnackBar('Error saving PIN: $e');
      }
    } else {
      _showSnackBar('দয়া করে ৪ সংখার সঠিক পিন দিন');
    }
  }

  // Show SnackBar for messages
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('এখান থেকে নতুন পিন যুক্ত করুন'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
          children: [
            Text(
              'দয়া করে আপনার ৪ সংখ্যার পিন দিন:',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent, width: 2),
              ),
              child: TextField(
                controller: _pinController,
                decoration: InputDecoration(
                  labelText: '৪ সংখ্যার পিন দিন',
                  labelStyle: TextStyle(color: Colors.blueAccent),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 2.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1.0),
                  ),
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true, // Hide the pin input for security
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // Background color
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text(
                'Save PIN',
                style: TextStyle(color: Colors.white), // Change text color
              ),
            ),
          ],
        ),
      ),
    );
  }
}
