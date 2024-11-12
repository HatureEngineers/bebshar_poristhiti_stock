import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'requirement/login_screen.dart';
import 'requirement/pin_verification_screen.dart';

class AuthWrapper extends StatelessWidget {
  final Function toggleTheme;
  final bool isDarkTheme;

  AuthWrapper({required this.toggleTheme, required this.isDarkTheme});

  // Function to check if pin is required
  Future<bool> _isPinRequired() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pinRequired') ?? false; // Default to false if not set
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isPinRequired(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        // Error state
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong"));
        }

        // Get pin required status
        bool isPinRequired = snapshot.data ?? false;

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, userSnapshot) {
            // Loading state
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            // Error state
            if (userSnapshot.hasError) {
              return Center(child: Text("Something went wrong"));
            }

            // User is logged in
            if (userSnapshot.hasData) {
              if (isPinRequired) {
                return PinVerificationScreen(
                  toggleTheme: toggleTheme,
                  isDarkTheme: isDarkTheme,
                );
              } else {
                return HomeScreen(
                  toggleTheme: toggleTheme,
                  isDarkTheme: isDarkTheme,
                );
              }
            }

            // User is not logged in
            return LoginScreen(
              toggleTheme: toggleTheme,
              isDarkTheme: isDarkTheme,
            );
          },
        );
      },
    );
  }
}
