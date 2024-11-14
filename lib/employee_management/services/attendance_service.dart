import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Dynamically mark attendance for a specific employee of the logged-in user
  Future<void> markAttendance(String userId, String employeeId, DateTime date, bool isPresent) async {
    String formattedDate = DateFormat('yyyy-MM-dd').format(date);

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('employees')
        .doc(employeeId)
        .collection('attendance')
        .doc(formattedDate)
        .set({
      'date': date,  // You may leave this as a Timestamp for easier querying if needed.
      'status': isPresent ? 'present' : 'absent',
    });
  }

  // Fetch monthly attendance dynamically for the employee of the logged-in user
  Future<Map<String, String>> fetchMonthlyAttendance(String userId, String employeeId, DateTime month) async {
    DateTime startOfMonth = DateTime(month.year, month.month, 1);
    DateTime endOfMonth = DateTime(month.year, month.month + 1, 0);

    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('employees')
        .doc(employeeId)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThanOrEqualTo: endOfMonth)
        .get();

    // Format snapshot data into a Map<String, String> with consistent date keys
    return {
      for (var doc in snapshot.docs)
        DateFormat('yyyy-MM-dd').format((doc['date'] as Timestamp).toDate()): doc['status']
    };
  }
}
