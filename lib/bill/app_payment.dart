import 'package:flutter/material.dart';

class AppPaymentPage extends StatefulWidget {
  _ExpensePageState createState() => _ExpensePageState();
}

class _ExpensePageState extends State<AppPaymentPage> {
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'বিল পরিশোধ',
          style: TextStyle(
            color: Colors.green, // Custom color
            fontWeight: FontWeight.bold, // Make the text bold (optional)
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Make the content scrollable
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally
            children: [
              Text(
                "বিকাশ বা নগদের মাধ্যমে বিল পরিশোধ করতে পারবেন। বিল পরিশোধের পর আপনার নোটিফিকেশান থেকে জানতে পারবেন। ধন্যবাদ...",
                style: TextStyle(
                  fontSize: 24.0, // Custom font size
                  color: Colors.blue, // Custom color
                  fontWeight: FontWeight.bold, // Make the text bold (optional)
                ),
                textAlign: TextAlign.center, // Center the text
              ),
              SizedBox(height: 50),
              Text(
                "বিকাশ থেকে ০১৫২১৪৪৪৪৭২ এই নম্বরে সেন্ড মানি করবেন।",
                style: TextStyle(
                  fontSize: 24.0, // Custom font size
                  color: Colors.blue, // Custom color
                ),
              ),
              SizedBox(height: 10), // Add spacing between text and images

              Center( // Center each image
                child: Image.asset(
                  'assets/image1.jpg', // Path to your image
                  width: 200, // Set width of the image
                  height: 150, // Set height of the image
                ),
              ),
              SizedBox(height: 10), // Add some space between images

              Center( // Center the second image
                child: Image.asset(
                  'assets/image2.jpg',
                  width: 200,
                  height: 300,
                ),
              ),
              SizedBox(height: 50),
              Text(
                "নগদ থেকে ০১৬৭৭৩৭৩৭৮৮ এই নম্বরে সেন্ড মানি করবেন।",
                style: TextStyle(
                  fontSize: 24.0, // Custom font size
                  color: Colors.blue, // Custom color
                ),
              ),

              Center( // Center the third image
                child: Image.asset(
                  'assets/image3.jpg',
                  width: 200,
                  height: 200,
                ),
              ),
              SizedBox(height: 10),

              Center( // Center the fourth image
                child: Image.asset(
                  'assets/image4.jpg',
                  width: 200,
                  height: 200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
