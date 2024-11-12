import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:flutter/material.dart';

class ExcelUploader extends StatefulWidget {
  @override
  _ExcelUploaderState createState() => _ExcelUploaderState();
}

class _ExcelUploaderState extends State<ExcelUploader> {
  bool _isLoading = false;
  String? userId; // Declare userId

  @override
  void initState() {
    super.initState();
    // Initialize userId from FirebaseAuth
    userId = FirebaseAuth.instance.currentUser?.uid; // Get current user's ID
  }

  Future<void> _uploadExcel(String subCollection) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Open file picker to select an Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.isNotEmpty) {
        String filePath = result.files.single.path!; // Get the selected file path

        // Read the Excel file
        var bytes = File(filePath).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        // Iterate through each sheet in the Excel file
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];

          // Iterate through rows, skipping the header row
          for (var row in sheet!.rows.skip(1)) {
            Map<String, String> data = {}; // Change the type to String

            // Iterate through each cell in the row
            for (var i = 0; i < sheet.rows[0].length; i++) {
              if (sheet.rows[0][i] != null) {
                // Get the cell value
                var cellValue = row[i]?.value; // Use '?.' to prevent null exception

                // Convert all values to strings
                data[sheet.rows[0][i]!.value.toString()] = cellValue?.toString() ?? '';
              }
            }

            // Check if data has meaningful content (non-empty)
            if (data.isNotEmpty && !data.values.every((value) => value.isEmpty)) {
              // Upload the constructed map to Firestore under the specified subcollection
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection(subCollection) // Use the specified subcollection
                  .add(data);
              print('Uploaded to $subCollection: $data');
            } else {
              print('Skipped empty or incomplete data: $data');
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload successful to $subCollection!')),
        );
      } else {
        // Handle the case when no file is selected
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No file selected')),
        );
      }
    } catch (e) {
      print('Error uploading: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Excel Uploader'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ElevatedButton(
            //   onPressed: () => _uploadExcel('customers'), // Upload to 'customers' subcollection
            //   child: Text('Upload to Customers'),
            // ),
            ElevatedButton(
              onPressed: () => _uploadExcel('stock'), // Upload to 'stock' subcollection
              child: Text('Upload to Stock'),
            ),
            // ElevatedButton(
            //   onPressed: () => _uploadExcel('supplier'), // Upload to 'supplier' subcollection
            //   child: Text('Upload to Supplier'),
            // ),
            if (_isLoading) CircularProgressIndicator(), // Show loading indicator
          ],
        ),
      ),
    );
  }
}
