import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore import
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth import
import 'cash_box/cash_box.dart';
import 'notification/notification_button.dart';
import 'widgets/large_action_buttons.dart';
import 'widgets/summary_card_section.dart';
import 'widgets/action_grid.dart';
import 'widgets/support_section.dart';
import 'widgets/custom_drawer.dart';
import 'widgets/edit_name_dialog.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final Function toggleTheme; // Theme toggle function
  final bool isDarkTheme; // State for dark theme

  HomeScreen({required this.toggleTheme, required this.isDarkTheme}); // Accept toggleTheme and isDarkTheme in the constructor

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _name = "Name"; // Default user name
  String _mobile = "phone number"; // Default user phone number
  File? _profileImage; // Holds selected profile image
  final ImagePicker _picker = ImagePicker(); // For image picking
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance
  final String formattedDate = DateFormat('EEEE, d MMMM, y', 'bn_BD').format(DateTime.now());
  String convertToBengali(String input) {
    const englishToBengali = {
      '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
      '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯', '.': '.',
    };
    return input.split('').map((e) => englishToBengali[e] ?? e).join();
  }


  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.isDarkTheme ? Colors.black : Colors.grey[300], // Conditional background color
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 1, 158, 255),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'দোকানের নাম',
              style: TextStyle(color: Colors.black, fontSize: screenWidth * 0.05),
            ),
            Text(
              formattedDate,
              style: TextStyle(color: Colors.black54, fontSize: screenWidth * 0.035),
            ),
          ],
        ),
        actions: [
          NotificationButton(iconSize: screenWidth * 0.07), // Replaces static IconButton with NotificationButton
          SizedBox(width: screenWidth * 0.03),
        ],
      ),
      drawer: CustomDrawer(
        name: _name,
        mobile: _mobile,
        onNameEdit: _showEditNameDialog,
        onImagePick: _pickImage,
        toggleTheme: widget.toggleTheme, // Pass toggleTheme function
        isDarkTheme: widget.isDarkTheme, // Pass isDarkTheme
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add the CashBox balance display section
            _buildCurrentBalance(screenWidth, screenHeight),
            SizedBox(height: screenHeight * 0.02),

            // Responsive Summary Section
            SummaryCardSection(screenWidth),
            SizedBox(height: screenHeight * 0.02),

            // Large Action Buttons
            LargeActionButtons(context, screenWidth, screenHeight),

            // Responsive Action Grid
            ActionGrid(screenWidth, screenHeight),
            // Support Section
            SupportSection(screenWidth),
          ],
        ),
      ),
    );
  }

  // Function to fetch and calculate the current balance from Firestore for the logged-in user
  Widget _buildCurrentBalance(double screenWidth, double screenHeight) {
    final User? user = _auth.currentUser; // Get the currently logged-in user
    if (user == null) {
      return Center(child: Text("User not logged in"));
    }

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid) // Use the logged-in user's UID
          .collection('cashbox')
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        // Calculate the total balance from the transactions
        final transactions = snapshot.data!.docs;
        double totalBalance = transactions.fold(0.0, (sum, doc) {
          return sum + (doc['amount'] is int
              ? (doc['amount'] as int).toDouble()
              : doc['amount']);
        });

// Display balance amount with dynamic text color
String formattedBalance = totalBalance % 1 == 0
  ? convertToBengali(totalBalance.toInt().toString()) // If it's an integer, convert to Bengali
  : convertToBengali(totalBalance.toStringAsFixed(2)); // Otherwise, show with two decimal places

        return InkWell(
          onTap: () {
            // Navigate to the CashBoxScreen on tap
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CashBoxScreen()), // Open CashBoxScreen
            );
          },
          child: Container(
            width: screenWidth * 1.0, // Adjust width based on screen size
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.02, // Adjust padding for responsiveness
              horizontal: screenWidth * 0.05,
            ),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Colors.white54, Colors.blue.shade400],
                center: Alignment.bottomCenter, // Center of the circle
                radius: 1.2, // Radius of the gradient
                // If you want to adjust how the colors spread in the gradient, you can use focal and focal radius
                focal: Alignment.center, // Focal point of the gradient
                focalRadius: 0.09, // Radius of the focal point
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'ক্যাশবক্স',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: screenWidth * 0.07, // Adjust font size based on screen width
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkTheme ? Colors.white : Colors.black, // Set text color based on theme
                  ),
                ),
                SizedBox(height: screenHeight * 0.02), // Adjust height for responsiveness
                // Display balance amount with dynamic text color
                Text(
  '৳$formattedBalance', // Use the formatted balance
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: screenWidth * 0.08, // Adjust font size for the balance
    fontWeight: FontWeight.bold, // Make text bold
    color: widget.isDarkTheme ? Colors.white : Colors.black, // Set text color based on theme
  ),
),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(text: _name);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditNameDialog(
          controller: nameController,
          onSave: () {
            setState(() {
              _name = nameController.text;
            });
          },
        );
      },
    );
  }
}

//
// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore import
// import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth import
// import 'cash_box/cash_box.dart';
// import 'notification/notification_button.dart';
// import 'widgets/large_action_buttons.dart';
// import 'widgets/summary_card_section.dart';
// import 'widgets/action_grid.dart';
// import 'widgets/support_section.dart';
// import 'widgets/custom_drawer.dart';
// import 'widgets/edit_name_dialog.dart';
// import 'package:intl/intl.dart';
//
// class HomeScreen extends StatefulWidget {
//   final Function toggleTheme; // Theme toggle function
//   final bool isDarkTheme; // State for dark theme
//
//   HomeScreen({required this.toggleTheme, required this.isDarkTheme}); // Accept toggleTheme and isDarkTheme in the constructor
//
//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   String _name = "Name"; // Default user name
//   String _mobile = "phone number"; // Default user phone number
//   File? _profileImage; // Holds selected profile image
//   final ImagePicker _picker = ImagePicker(); // For image picking
//   final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance
//   final String formattedDate = DateFormat('EEEE, d MMMM, y', 'bn_BD').format(DateTime.now());
//   String convertToBengali(String input) {
//     const englishToBengali = {
//       '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
//       '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯', '.': '.',
//     };
//     return input.split('').map((e) => englishToBengali[e] ?? e).join();
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     var screenWidth = MediaQuery.of(context).size.width;
//     var screenHeight = MediaQuery.of(context).size.height;
//
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: widget.isDarkTheme ? Colors.black : Colors.grey[300], // Conditional background color
//       appBar: AppBar(
//         backgroundColor: Color.fromARGB(255, 1, 158, 255),
//         elevation: 0,
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'দোকানের নাম',
//               style: TextStyle(color: Colors.black, fontSize: screenWidth * 0.05),
//             ),
//             Text(
//               formattedDate,
//               style: TextStyle(color: Colors.black54, fontSize: screenWidth * 0.035),
//             ),
//           ],
//         ),
//         actions: [
//           NotificationButton(iconSize: screenWidth * 0.07), // Replaces static IconButton with NotificationButton
//           SizedBox(width: screenWidth * 0.03),
//         ],
//       ),
//       drawer: CustomDrawer(
//         name: _name,
//         mobile: _mobile,
//         onNameEdit: _showEditNameDialog,
//         onImagePick: _pickImage,
//         toggleTheme: widget.toggleTheme, // Pass toggleTheme function
//         isDarkTheme: widget.isDarkTheme, // Pass isDarkTheme
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Add the CashBox balance display section
//             _buildCurrentBalance(screenWidth, screenHeight),
//             SizedBox(height: screenHeight * 0.01),
//
//             // Responsive Summary Section
//             SummaryCardSection(screenWidth),
//             SizedBox(height: screenHeight * 0.01),
//
//             // Large Action Buttons
//             LargeActionButtons(context, screenWidth, screenHeight),
//
//             // Responsive Action Grid
//             ActionGrid(screenWidth, screenHeight),
//             // Support Section
//             SupportSection(screenWidth),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Function to fetch and calculate the current balance from Firestore for the logged-in user
//   Widget _buildCurrentBalance(double screenWidth, double screenHeight) {
//     final User? user = _auth.currentUser; // Get the currently logged-in user
//     if (user == null) {
//       return Center(child: Text("User not logged in"));
//     }
//
//     return StreamBuilder(
//       stream: FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid) // Use the logged-in user's UID
//           .collection('cashbox')
//           .snapshots(),
//       builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
//         if (!snapshot.hasData) {
//           return Center(child: CircularProgressIndicator());
//         }
//
//         // Calculate the total balance from the transactions
//         final transactions = snapshot.data!.docs;
//         double totalBalance = transactions.fold(0.0, (sum, doc) {
//           return sum + (doc['amount'] is int
//               ? (doc['amount'] as int).toDouble()
//               : doc['amount']);
//         });
//         // Format the balance amount
//         String formattedBalance = totalBalance % 1 == 0
//             ? convertToBengali(totalBalance.toInt().toString()) // If it's an integer, convert to Bengali
//             : convertToBengali(totalBalance.toStringAsFixed(2)); // Otherwise, show with two decimal places
//
//         return InkWell(
//           onTap: () {
//             // Navigate to the CashBoxScreen on tap
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => CashBoxScreen()), // Open CashBoxScreen
//             );
//           },
//           child: Container(
//             width: screenWidth * 1.0, // Adjust width based on screen size
//             padding: EdgeInsets.symmetric(
//               vertical: screenHeight * 0.02, // Adjust padding for responsiveness
//               horizontal: screenWidth * 0.05,
//             ),
//             decoration: BoxDecoration(
//               image: DecorationImage(
//                 image: AssetImage('assets/lightning-frame.jpg'), // Replace with your image path
//                 fit: BoxFit.cover, // Fit the image to cover the entire container
//               ),
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.3),
//                   spreadRadius: 2,
//                   blurRadius: 6,
//                   offset: Offset(0, 3),
//                 ),
//               ],
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Text(
//                   'ক্যাশবক্স',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: screenWidth * 0.07, // Adjust font size based on screen width
//                     fontWeight: FontWeight.bold,
//                     color: widget.isDarkTheme ? Colors.white : Colors.lightBlueAccent, // Set text color based on theme
//                   ),
//                 ),
//                 SizedBox(height: screenHeight * 0.02), // Adjust height for responsiveness
//                 // Display balance amount with dynamic text color
//                 Text(
//                   '৳$formattedBalance', // Use the formatted balance
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: screenWidth * 0.08, // Adjust font size for the balance
//                     fontWeight: FontWeight.bold, // Make text bold
//                     color: widget.isDarkTheme ? Colors.white : Colors.lightBlueAccent, // Set text color based on theme
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//
//       },
//     );
//   }
//
//   Future<void> _pickImage() async {
//     final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile != null) {
//       setState(() {
//         _profileImage = File(pickedFile.path);
//       });
//     }
//   }
//
//   void _showEditNameDialog() {
//     final TextEditingController nameController = TextEditingController(text: _name);
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return EditNameDialog(
//           controller: nameController,
//           onSave: () {
//             setState(() {
//               _name = nameController.text;
//             });
//           },
//         );
//       },
//     );
//   }
// }
