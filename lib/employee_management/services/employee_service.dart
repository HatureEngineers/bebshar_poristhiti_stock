import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/employee_model.dart';

class EmployeeService {
  // Get the current logged-in user's ID
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  // Reference to the employees collection under the logged-in user's document
  CollectionReference get employeeCollection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('employees');
  }

  // Method to get a reference to the salary transactions sub-collection under a specific employee
  CollectionReference getSalaryTransactionCollection(String employeeId) {
    return employeeCollection
        .doc(employeeId)
        .collection('salary_transactions');
  }

  // Method to add an employee
  Future<void> addEmployee(Employee employee) async {
    await employeeCollection.doc(employee.id).set(employee.toMap());
  }

  // Method to update an existing employee
  Future<void> updateEmployee(Employee employee) async {
    await employeeCollection.doc(employee.id).update(employee.toMap());
  }

  // Method to delete an employee by ID
  Future<void> deleteEmployee(String id) async {
    await employeeCollection.doc(id).delete();
  }

  // Method to update the imageUrl of an employee
  Future<void> updateEmployeeImageUrl(String employeeId, String imageUrl) async {
    await employeeCollection.doc(employeeId).update({
      'imageUrl': imageUrl,
    });
  }

  // Method to initialize or update `amountToPay` at the start of a new month
  Future<void> initializeMonthlyAmountToPay(String employeeId, double salary) async {
    final employeeDoc = await employeeCollection.doc(employeeId).get();

    if (employeeDoc.exists) {
      final data = employeeDoc.data() as Map<String, dynamic>;
      final lastTransactionDate = (data['lastTransactionDate'] as Timestamp?)?.toDate();
      final amountToPay = (data['amountToPay'] ?? 0.0) as double;
      final now = DateTime.now();

      // Check if it's a new month
      if (lastTransactionDate == null ||
          lastTransactionDate.year != now.year ||
          lastTransactionDate.month != now.month) {
        final updatedAmountToPay = amountToPay + salary;

        await employeeCollection.doc(employeeId).update({
          'amountToPay': updatedAmountToPay,
          'lastTransactionDate': Timestamp.fromDate(now),
        });
      }
    }
  }

  // Method to add a salary transaction and update `amountToPay` accordingly
  Future<void> addSalaryTransaction(String employeeId, double amount) async {
    final transactionRef = getSalaryTransactionCollection(employeeId).doc();

    // Save the transaction details (amount and date)
    await transactionRef.set({
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
    });

    // Retrieve current amountToPay for the employee
    final employeeDoc = await employeeCollection.doc(employeeId).get();
    final currentAmountToPay = (employeeDoc['amountToPay'] ?? 0.0) as double;

    // Update amountToPay in the employee document
    final updatedAmountToPay = currentAmountToPay - amount;
    await employeeCollection.doc(employeeId).update({
      'amountToPay': updatedAmountToPay,
    });
  }

  // Paginated fetch of salary transactions
// EmployeeService
  Future<List<Map<String, dynamic>>> getPaginatedSalaryTransactions(
      String employeeId,
      int limit,
      {DocumentSnapshot? startAfter}) async {

    Query query = getSalaryTransactionCollection(employeeId)
        .orderBy('date', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Ensure each transaction has a unique ID
      data['documentSnapshot'] = doc; // Keep the snapshot for pagination
      return data;
    }).toList();
  }

  // Stream to retrieve employees for the logged-in user
  Stream<List<Employee>> getEmployees() {
    return employeeCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Employee.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }
}
