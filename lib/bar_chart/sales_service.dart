import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<List<Map<String, dynamic>>> fetchSalesData(String timeRange,{int? barCount}) async {
  User? user = FirebaseAuth.instance.currentUser; // Ensure user is logged in
  if (user == null) {
    throw Exception("User is not logged in");
  }

  // Create a reference to the sales collection
  CollectionReference salesCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('sales');

  // Adjust the query based on the time range
  Query query;
  DateTime now = DateTime.now();

  if (timeRange == 'Daily') {
    DateTime lastDays = now.subtract(Duration(days: barCount ?? 7)); // Get the last 7 days of data
    query = salesCollection
        .where('time', isGreaterThanOrEqualTo: lastDays)
        .orderBy('time'); // Order by 'time' field (default is ascending)
  } else if (timeRange == 'Monthly') {
    DateTime startOfMonth = DateTime(now.year, now.month- 12, 1); // First day of the month
    query = salesCollection
        .where('time', isGreaterThanOrEqualTo: startOfMonth)
        .orderBy('time');
  } else if (timeRange == 'Yearly') {
    DateTime startOfYear = DateTime(now.year- (barCount ?? 5), 1, 1); // First day of the year
    query = salesCollection
        .where('time', isGreaterThanOrEqualTo: startOfYear)
        .orderBy('time');
  } else {
    throw Exception("Invalid time range");
  }

  // Fetch sales data from Firestore
  QuerySnapshot snapshot = await query.get();

  // Map sales documents into a list of sales data
  return snapshot.docs.map((doc) {
    return {
      'amount': doc['amount'], // Sale amount
      'time': doc['time'].toDate(), // Convert timestamp to DateTime
    };
  }).toList();
}
