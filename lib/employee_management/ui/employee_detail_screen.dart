import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import '../models/employee_model.dart';
import '../services/dialogs.dart';
import '../services/employee_service.dart';
import 'package:flutter/services.dart'; // Import for TextInputFormatter

// Function to dynamically get current user ID (replace with actual user ID fetching logic)
Future<String?> getCurrentUserId() async {
  return FirebaseAuth.instance.currentUser?.uid;
}

class EmployeeDetailScreen extends StatefulWidget {
  final Employee employee;

  EmployeeDetailScreen({Key? key, required this.employee}) : super(key: key);

  @override
  _EmployeeDetailScreenState createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final EmployeeService _employeeService = EmployeeService(); // Instance of EmployeeService

  bool _isLoading = false; // To prevent multiple submissions

  // Function to initiate a phone call to the specified number
  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final Uri url = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'Could not launch $url';
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Phone number not available")),
      );
    }
  }

  // Function to update the employee's profile image (using image picker)
  Future<void> _updateImage(BuildContext context) async {
    final ImageSource? source = await DialogUtil.showImageSourceDialog(context);

    if (source != null) {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 10,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);

        try {
          // Check if there's an existing image URL and delete the old image
          if (widget.employee.imageUrl != null &&
              widget.employee.imageUrl!.isNotEmpty) {
            String oldImageUrl = widget.employee.imageUrl!;
            Reference oldImageRef = _storage.refFromURL(oldImageUrl);
            await oldImageRef.delete();
          }

          // Upload the new image to Firebase Storage
          String fileName = path.basename(imageFile.path);
          Reference storageReference =
          _storage.ref().child('employee_images/$fileName');
          UploadTask uploadTask = storageReference.putFile(imageFile);
          TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() {});

          // Get the URL of the uploaded image
          String newImageUrl = await taskSnapshot.ref.getDownloadURL();
          await _employeeService.updateEmployeeImageUrl(
            widget.employee.id,
            newImageUrl,
          );

          // Update the employee's image in the local state
          setState(() {
            widget.employee.imageUrl = newImageUrl;
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to upload image: $e")),
          );
        }
      }
    }
  }

  // Function to handle updating employee information (name, phone, etc.)
  Future<void> _editEmployeeDetails() async {
    if (_isLoading) return; // Prevent multiple submissions

    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      // Update the employee details in Firestore
      await _employeeService.updateEmployee(widget.employee);

      // Display a success message after update
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Employee details updated successfully!")),
      );
    } catch (e) {
      // Handle any errors during the update
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update employee details: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  // Function to show the Edit Details dialog
  Future<void> _showEditDialog() async {
    TextEditingController nameController =
    TextEditingController(text: widget.employee.name);
    TextEditingController phoneController =
    TextEditingController(text: widget.employee.phoneNumber);
    TextEditingController addressController =
    TextEditingController(text: widget.employee.address);
    TextEditingController nidController =
    TextEditingController(text: widget.employee.nid);
    TextEditingController positionController =
    TextEditingController(text: widget.employee.position);
    TextEditingController emergencyContactController =
    TextEditingController(text: widget.employee.emergencyContact);
    TextEditingController salaryController =
    TextEditingController(text: widget.employee.salary?.toString() ?? '');


    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit Employee Details"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: "Name"),
                ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.number, // Number pad keyboard
                  decoration: InputDecoration(labelText: "Phone"),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // Only digits allowed
                    LengthLimitingTextInputFormatter(11), // Limit input to 11 digits
                  ],
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: "Address"),
                ),
                TextField(
                  controller: nidController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: "NID"),
                ),
                TextField(
                  controller: positionController,
                  decoration: InputDecoration(labelText: "Position"),
                ),
                TextField(
                  controller: emergencyContactController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: "Emergency Contact"),
                ),
                TextField(
                  controller: salaryController,
                  keyboardType: TextInputType.number, // Number pad keyboard
                  decoration: InputDecoration(labelText: "Salary"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (phoneController.text.length != 11) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Phone number must be 11 digits.")),
                  );
                  return;
                }
                double? updatedSalary = double.tryParse(salaryController.text);

                // If the parsed value is null, show an error
                if (updatedSalary == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please enter a valid salary.")),
                  );
                  return;
                }

                // Update the employee object with the new salary
                setState(() {
                  widget.employee.name = nameController.text;
                  widget.employee.phoneNumber = phoneController.text;
                  widget.employee.address = addressController.text;
                  widget.employee.nid = nidController.text;
                  widget.employee.position = positionController.text;
                  widget.employee.emergencyContact = emergencyContactController.text;
                  widget.employee.salary = updatedSalary; // Set the salary as a double
                });

                _editEmployeeDetails();
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Details'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => DialogUtil.showImageDialog(
                        context, widget.employee.imageUrl),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: widget.employee.imageUrl != null &&
                          widget.employee.imageUrl!.isNotEmpty
                          ? NetworkImage(widget.employee.imageUrl!)
                          : AssetImage('assets/placeholder.png')
                      as ImageProvider,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => _updateImage(context),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.edit, size: 15, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text('Name: ${widget.employee.name}', style: TextStyle(fontSize: 18)),
            Row(
              children: [
                Text('Phone: ${widget.employee.phoneNumber}', style: TextStyle(fontSize: 18)),
                IconButton(
                  icon: Icon(Icons.phone, color: Colors.blue),
                  onPressed: () => _makePhoneCall(widget.employee.phoneNumber),
                ),
              ],
            ),
            Row(
              children: [
                Text('Emergency Contact: ${widget.employee.emergencyContact}', style: TextStyle(fontSize: 18)),
                IconButton(
                  icon: Icon(Icons.phone, color: Colors.red),
                  onPressed: () => _makePhoneCall(widget.employee.emergencyContact),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text('NID: ${widget.employee.nid}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            Text(
              'Address: ${widget.employee.address}',
              style: TextStyle(fontSize: 18),
              maxLines: 3, // Limit the number of lines to 3
              overflow: TextOverflow.ellipsis, // Add ellipsis if the text overflows
            ),
            SizedBox(height: 20),
            Text('Position: ${widget.employee.position}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            Text('Salary: ${widget.employee.salary}', style: TextStyle(fontSize: 18)),

            // Edit button to update employee details
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showEditDialog, // Trigger the edit dialog
              child: Text('Edit Details'),
            ),
          ],
        ),
      ),
    );
  }
}
