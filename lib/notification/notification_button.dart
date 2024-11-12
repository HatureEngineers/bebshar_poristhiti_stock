import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notification/notification.dart'; // NotificationsPage import

class NotificationButton extends StatelessWidget {
  final double iconSize;

  NotificationButton({required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;

    // Check if the user is logged in
    if (_auth.currentUser == null) {
      return Icon(Icons.notifications, color: Colors.black, size: iconSize);
    }

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false) // Unread notifications only
          .snapshots(), // Listen to changes in Firestore
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        // If still loading, show default icon
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Icon(Icons.notifications, color: Colors.black, size: iconSize); // Show default icon
        }

        // Check if there are unread notifications
        bool hasUnreadNotifications = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return IconButton(
          icon: Icon(
            hasUnreadNotifications ? Icons.notifications_active : Icons.notifications,
            color: hasUnreadNotifications ? Colors.yellowAccent : Colors.black,
            size: iconSize,
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                var screenHeight = MediaQuery.of(context).size.height;
                var screenWidth = MediaQuery.of(context).size.width;

                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: screenHeight * 0.01),
                      child: Container(
                        width: screenWidth * 0.9,
                        height: screenHeight * 0.87,
                        child: NotificationsPage(), // Show NotificationsPage in dialog
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
