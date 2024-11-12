import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Stream<List<DocumentSnapshot>> getTodayNotifications(String userId) async* {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    Stream<QuerySnapshot> globalNotificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('time', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('time', descending: true)
        .snapshots();

    Stream<QuerySnapshot> userNotificationsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('user_notifications')
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('time', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('time', descending: true)
        .snapshots();

    await for (var globalNotifications in globalNotificationsStream) {
      await for (var userNotifications in userNotificationsStream) {
        List<DocumentSnapshot> todayNotifications = [
          ...globalNotifications.docs,
          ...userNotifications.docs,
        ];

        todayNotifications.sort((a, b) {
          Timestamp timeA = a['time'];
          Timestamp timeB = b['time'];
          return timeB.compareTo(timeA);
        });

        yield todayNotifications;
      }
    }
  }

  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Notifications'),
          backgroundColor: Colors.teal,
          automaticallyImplyLeading: false,
          centerTitle: true,
        ),
        body: Center(
          child: Text("User not logged in"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        backgroundColor: Colors.teal,
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: StreamBuilder<List<DocumentSnapshot>>(
        stream: getTodayNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No notifications found for today.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView(
            children: snapshot.data!.map((doc) {
              String title = doc.data().toString().contains('title') ? doc['title'] : 'No Title';
              String description = doc.data().toString().contains('description') ? doc['description'] : 'No Description';
              String? imageUrl = doc.data().toString().contains('image') ? doc['image'] : null;
              Timestamp timestamp = doc['time'];
              String formattedTime = formatTimestamp(timestamp);
              bool isExpanded = false;

              Widget leadingIcon;
              bool isGlobalNotification = doc.reference.parent.id == 'notifications';
              leadingIcon = isGlobalNotification
                  ? Icon(Icons.notifications, color: Colors.teal, size: 40)
                  : Icon(Icons.dangerous, color: Colors.red, size: 40);

              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Card(
                    color: imageUrl != null ? Colors.lightBlue.shade50 : Colors.lightGreen.shade50,
                    margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    child: Column(
                      children: [
                        ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              if (imageUrl != null && imageUrl.isNotEmpty) {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.network(imageUrl),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Close'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                              imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                                : leadingIcon,
                          ),
                          title: Text(
                            title,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Only show time if it's a global notification
                              if (isGlobalNotification)
                                Text(formattedTime, style: TextStyle(color: Colors.grey)),
                              SizedBox(height: 5),
                              isExpanded
                                  ? Text(description)
                                  : Text(
                                '${description.split(' ').take(15).join(' ')}...',
                              ),
                            ],
                          ),
                          trailing: GestureDetector(
                            onTap: () {
                              setState(() {
                                isExpanded = !isExpanded;
                              });
                            },
                            child: Icon(
                              isExpanded ? Icons.arrow_drop_up : Icons.arrow_forward_ios,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
