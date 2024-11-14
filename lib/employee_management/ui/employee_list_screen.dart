import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../services/employee_service.dart';
import 'employee_detail_screen.dart';
import 'add_employee_screen.dart';
import 'salary_transaction_screen.dart';
import 'attendance_screen.dart';

class EmployeeListScreen extends StatelessWidget {
  final EmployeeService employeeService = EmployeeService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Employees')),
      body: StreamBuilder<List<Employee>>(
        stream: employeeService.getEmployees(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final employees = snapshot.data!;
            return ListView.builder(
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final employee = employees[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: employee.imageUrl != null && employee.imageUrl!.isNotEmpty
                        ? NetworkImage(employee.imageUrl!)
                        : AssetImage('assets/placeholder.png') as ImageProvider,
                  ),
                  title: Text(employee.name),
                  subtitle: Text(employee.phoneNumber),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmployeeDetailScreen(employee: employee),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.money, color: Colors.green),  // Cash icon for salary transaction
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SalaryTransactionScreen(employee: employee), // Assuming SalaryTransactionScreen exists
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.calendar_month, color: Colors.green),  // Calendar icon for attendance
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: true, // Allow closing the dialog by tapping outside
                            builder: (BuildContext context) {
                              return Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: AttendanceScreen(employeeId: employee.id), // Passing employeeId to AttendanceScreen
                              );
                            },
                          );
                        },
                      ),

                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirmDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Delete Employee'),
                              content: Text('Are you sure you want to delete ${employee.name}?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (confirmDelete ?? false) {
                            await employeeService.deleteEmployee(employee.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show the AddEmployeeScreen as a dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return Dialog(
                child: AddEmployeeScreen(),
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
