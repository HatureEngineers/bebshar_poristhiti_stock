import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart'; // Add for image picking
import 'dart:io';
import '../models/employee_model.dart';
import '../services/employee_service.dart';
import 'employee_list_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class AddEmployeeScreen extends StatefulWidget {
  @override
  _AddEmployeeScreenState createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _positionController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _nidController = TextEditingController();
  final _salaryController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  File? _selectedImage; // To store the selected image file

  final EmployeeService employeeService = EmployeeService();

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Employee'),
        automaticallyImplyLeading: false, // Remove back arrow
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              // Close the dialog when the cross icon is pressed
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                ),
                TextFormField(
                  controller: _phoneNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Phone Number'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    } else if (value.length != 11) {
                      return 'Phone number must be exactly 11 digits';
                    }
                    return null; // Validation passed
                  },
                ),
                TextFormField(
                  controller: _emergencyContactController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'Emergency Contact'),
                ),
                TextFormField(
                  controller: _positionController,
                  decoration: InputDecoration(labelText: 'Position'),
                ),
                TextFormField(
                  controller: _nidController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'NID'),
                ),
                TextFormField(
                  controller: _salaryController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Salary'),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                ),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(labelText: 'Address'),
                ),
                SizedBox(height: 10),
                _selectedImage == null
                    ? Text("No image selected")
                    : Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(_selectedImage!, height: 100),
                    Padding(
                      padding: EdgeInsets.all(4), // Adjust padding to reduce box size
                      child: Container(
                        width: 24, // Set fixed width
                        height: 24, // Set fixed height
                        decoration: BoxDecoration(
                          color: Colors.white, // Background color for the icon
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(4), // Optional: Rounded corners
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero, // Remove default padding
                          iconSize: 16, // Adjust icon size
                          icon: Icon(Icons.clear, color: Colors.red),
                          onPressed: _clearImage, // Clear image when pressed
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text('Upload Image'),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      String? imageUrl;
                      if (_selectedImage != null) {
                        final fileName = path.basename(_selectedImage!.path);
                        final storageRef = FirebaseStorage.instance
                            .ref()
                            .child('employee_images/$fileName');
                        await storageRef.putFile(_selectedImage!);
                        imageUrl = await storageRef.getDownloadURL();
                      }

                      final employee = Employee(
                        id: FirebaseFirestore.instance
                            .collection('users')
                            .doc(employeeService.userId)
                            .collection('employees')
                            .doc()
                            .id, // Generate a new employee ID under the user
                        name: _nameController.text,
                        position: _positionController.text,
                        phoneNumber: _phoneNumberController.text,
                        nid: _nidController.text,
                        salary: double.tryParse(_salaryController.text),
                        address: _addressController.text,
                        emergencyContact: _emergencyContactController.text,
                        imageUrl: imageUrl, // Save the uploaded image URL
                      );

                      await employeeService.addEmployee(employee);

                      // Navigate to EmployeeListScreen after successful addition
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => EmployeeListScreen()),
                      );
                    }
                  },
                  child: Text('Add Employee'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _phoneNumberController.dispose();
    _nidController.dispose();
    _salaryController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }
}
