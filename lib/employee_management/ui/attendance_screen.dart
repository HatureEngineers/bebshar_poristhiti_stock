import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  final String employeeId;

  AttendanceScreen({Key? key, required this.employeeId}) : super(key: key);

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  Map<String, String> _attendanceData = {};

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  void _loadAttendanceData() async {
    String? userId = await getCurrentUserId(); // await added here
    if (userId != null) {
      String employeeId = widget.employeeId;
      Map<String, String> data =
      await _attendanceService.fetchMonthlyAttendance(
        userId,
        employeeId,
        DateTime.now(),
      );
      setState(() {
        _attendanceData = data;
      });
    }
  }

  Future<String?> getCurrentUserId() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _editAttendance(DateTime date) async {
    String? userId = await getCurrentUserId(); // await added here
    if (userId != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);

      // Check if attendance data for this day exists
      bool hasAttendance = _attendanceData.containsKey(formattedDate);

      // Display dialog only to mark the attendance if it's not already marked
      bool? newStatus = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Edit Attendance"),
          content: Text("Mark this day as:"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Present
              child: Text("Present", style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Absent
              child: Text("Absent", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      // If the new status is different from the current status, update the attendance
      if (newStatus != null) {
        // Mark attendance only if the status is different from the current one
        if (!hasAttendance || _attendanceData[formattedDate] != (newStatus ? 'present' : 'absent')) {
          await _attendanceService.markAttendance(
            userId,
            widget.employeeId,
            date,
            newStatus,
          );
          _loadAttendanceData(); // Refresh attendance data
        }
      }
    }
  }

  Color _getDayColor(DateTime day) {
    String dayKey = DateFormat('yyyy-MM-dd').format(day);

    // Check if the day is today's date
    if (day.year == DateTime.now().year &&
        day.month == DateTime.now().month &&
        day.day == DateTime.now().day) {
      // Return the attendance color for today's date, if available
      if (_attendanceData.containsKey(dayKey)) {
        return _attendanceData[dayKey] == 'present' ? Colors.green : Colors.red;
      }
    }

    // For other days, check the attendance data
    if (_attendanceData.containsKey(dayKey)) {
      return _attendanceData[dayKey] == 'present' ? Colors.green : Colors.red;
    }

    return Colors.grey; // No attendance data, so use grey
  }

  void _markAttendance(bool isPresent) async {
    String? userId = await getCurrentUserId(); // await added here
    if (userId != null) {
      await _attendanceService.markAttendance(
        userId,
        widget.employeeId,
        DateTime.now(),
        isPresent,
      );
      _loadAttendanceData(); // Refresh attendance data
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance for Employee'),
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TableCalendar(
              firstDay:
              DateTime.utc(DateTime.now().year, DateTime.now().month, 1),
              lastDay: DateTime.utc(
                  DateTime.now().year, DateTime.now().month + 1, 0),
              focusedDay: DateTime.now(),
              calendarFormat: CalendarFormat.month,
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  bool isFutureDate = day.isAfter(
                      DateTime.now()); // Check if the day is in the future
                  return GestureDetector(
                    onTap: !isFutureDate
                        ? () => _editAttendance(day)
                        : null, // Disable editing for future dates
                    child: Container(
                      margin: EdgeInsets.all(4.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getDayColor(
                            day), // Color based on attendance status
                      ),
                      child: Text(day.day.toString()),
                    ),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  bool isFutureDate = day.isAfter(
                      DateTime.now()); // Check if today is in the future
                  return GestureDetector(
                    onTap: !isFutureDate
                        ? () => _editAttendance(day)
                        : null, // Disable editing for future
                    child: Container(
                      margin: EdgeInsets.all(4.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getDayColor(day), // Color for today's date
                      ),
                      child: Text(
                        day.day.toString(),
                        style: TextStyle(
                            color: Colors.white), // Text style for contrast
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () => _markAttendance(true),
                  child: Text('Present'),
                ),
                ElevatedButton(
                  onPressed: () => _markAttendance(false),
                  child: Text('Absent'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
