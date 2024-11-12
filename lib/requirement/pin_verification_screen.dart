import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';
import '../home_screen.dart';

class PinVerificationScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkTheme;

  PinVerificationScreen({required this.toggleTheme, required this.isDarkTheme});

  @override
  _PinVerificationScreenState createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _pinController = TextEditingController();
  User? _currentUser;
  late AnimationController _animationController;
  bool _isPinVisible = true; // পিনের ভিজিবিলিটি ট্র্যাক করতে
  Timer? _timer;

  void _onPinChanged(String value) {
    if (value.isNotEmpty) {
      // 100 মিলিসেকেন্ড পর ইনপুটকে লুকানো
      _timer?.cancel(); // পুরানো টাইমার বাতিল করা
      _timer = Timer(Duration(milliseconds: 100), () {
        setState(() {
          _isPinVisible = false; // পিন লুকানো
        });
      });

      setState(() {
        _isPinVisible = true; // পিন দেখা যাচ্ছে
      });
    } else {
      // যদি ইনপুট খালি হয়
      setState(() {
        _isPinVisible = true; // পিন দেখা যাচ্ছে
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentUser();

    // Initialize animation controller for gradient effect
    _animationController = AnimationController(
      duration: Duration(seconds: 6),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel(); // টাইমার বাতিল করা
    _pinController.dispose();
    super.dispose();
  }

  // Get the current user
  void _getCurrentUser() {
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackBar('No user logged in. Please log in first.');
      });
    }
  }

  // Verify the PIN from Firestore
  void _verifyPin() async {
    if (_currentUser == null) {
      _showSnackBar('No user logged in');
      return;
    }

    String enteredPin = _pinController.text.trim();
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser?.uid)
        .get();

    if (userDoc.exists) {
      String storedPin = userDoc['pin'];
      if (enteredPin == storedPin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              toggleTheme: widget.toggleTheme,
              isDarkTheme: widget.isDarkTheme,
            ),
          ),
        );
      } else {
        _showSnackBar('আপনি ভুল পিন দিয়েছেন');
      }
    } else {
      _showSnackBar('No PIN found. Please set up a PIN first.');
    }
  }

  // Show SnackBar for messages
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            message,
            style: TextStyle(fontSize: 16), // আপনার প্রয়োজন অনুসারে টেক্সট সাইজ পরিবর্তন করুন
          ),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10), // গোলাকার প্রান্তের জন্য
        ),
        margin: EdgeInsets.all(16), // স্ন্যাকবারের চারপাশে মার্জিন
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green,
                      Colors.teal,
                      Colors.blue,
                      Colors.purpleAccent,
                    ],
                    stops: [
                      0.1 + 0.2 * sin(_animationController.value * 2 * pi),
                      0.4 + 0.2 * sin(_animationController.value * 2 * pi + pi / 2),
                      0.7 + 0.2 * sin(_animationController.value * 2 * pi + pi),
                      1.0,
                    ],
                  ),
                ),
              );
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'পিন লগইন করুন',
                    style: TextStyle(fontSize: 36, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _pinController,
                        decoration: InputDecoration(
                          hintText: '✱✱✱✱',
                          hintStyle: TextStyle(fontSize: 34, color: Colors.grey),
                          border: InputBorder.none,
                          counterText: "",
                        ),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: TextStyle(fontSize: 34, letterSpacing: 8),
                        obscureText: !_isPinVisible, // পিন দেখাবে না যদি _isPinVisible false হয়
                        obscuringCharacter: '✱',
                        onChanged: _onPinChanged,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _verifyPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      shadowColor: Colors.blueAccent.withOpacity(0.3),
                      elevation: 5,
                      textStyle: TextStyle(fontSize: 20),
                    ),
                    child: Text(
                      'পিন যাচাই',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
