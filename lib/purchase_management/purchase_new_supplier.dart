import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../cash_box/cash_box.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';

class PurchaseNewSupplier extends StatefulWidget {
  final String appBarTitle;
  PurchaseNewSupplier ({required this.appBarTitle});
  @override
  _PurchaseNewSupplierState createState() => _PurchaseNewSupplierState();
}

class _PurchaseNewSupplierState extends State<PurchaseNewSupplier> {
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _transactionController = TextEditingController();
  final TextEditingController _cashPaymentController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSaving = false;

  DateTime _selectedDate = DateTime.now(); // Default to today's date
  File? _selectedImage;
  String? _image;
  bool _redirectToCashBoxScreenSwitch = false;

  // Date picker function
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate, // Show previously selected or today's date
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Image picker function
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();

    // Show dialog to choose between gallery and camera
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ছবি নির্বাচন করুন'),
          content: Text('কোথা থেকে ছবি নিতে চান?'),
          actions: [
            TextButton(
              child: Text('গ্যালারি'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                final pickedFile =
                await _picker.pickImage(source: ImageSource.gallery);
                _setImage(pickedFile);
              },
            ),
            TextButton(
              child: Text('ক্যামেরা'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                final pickedFile =
                await _picker.pickImage(source: ImageSource.camera);
                _setImage(pickedFile);
              },
            ),
            TextButton(
              child: Text('বাতিল করুন'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
            ),
          ],
        );
      },
    );
  }

  void _setImage(XFile? pickedFile) {
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _saveSupplier() async {
    final User? user = _auth.currentUser; // Get the current logged-in user
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to add supplier')),
      );
      return;
    }

    // Prevent further execution if the saving process is already happening
    if (_isSaving) return;

    setState(() {
      _isSaving = true; // Block further submissions
    });

    try {
      final existingPhoneNumberInCustomers = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('suppliers')
      // .where('name', isEqualTo: _nameController.text)
          .where('phone', isEqualTo: _phoneController.text)
          .get();

      // যদি কোনো কাস্টমার মেলে তাহলে সাবমিশন বন্ধ করা
      if (existingPhoneNumberInCustomers.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('এই ফোন নম্বর ইতিমধ্যেই বিদ্যমান'),backgroundColor: Colors.redAccent,),//নাম এবং
        );
        setState(() {
          _isSaving = false; // Allow future submissions
        });
        return;
      }

      if (_formKey.currentState!.validate()) {
        FocusScope.of(context).unfocus();
        // Image upload to Firebase Storage
        if (_selectedImage != null) {
          final storageRef = FirebaseStorage.instance.ref().child(
              'supplier_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
          await storageRef.putFile(_selectedImage!);
          _image = await storageRef.getDownloadURL();
        } else {
          _image = 'assets/error.jpg'; // Default image path if no image is picked
        }

        // Use selected date or current date if no date is chosen
        final DateTime transactionDate = _selectedDate;

        // Calculate transaction amount
        double transactionAmount =
            double.tryParse(_transactionController.text) ?? 0;
        double cashPayment = double.tryParse(_cashPaymentController.text) ?? 0;
        double supplierTransaction = transactionAmount - cashPayment;

        // Save purchases data to "purchases" collection with Timestamp
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('purchases') // Save to "purchases" sub-collection
            .add({
          'amount': transactionAmount, // "মোট বিক্রির পরিমাণ(টাকা)" value
          'time': FieldValue.serverTimestamp(), // Save current timestamp
        });

        // Save supplier data to Firestore under the user's UID with Timestamp
        final supplierData = {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'image': _image,
          'transaction': supplierTransaction,
          'transactionDate': FieldValue.serverTimestamp(),
          'uid': user.uid,
          'description': _descriptionController.text,
        };

        DocumentReference supplierRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('suppliers')
            .add(supplierData);

        // After adding the supplier, create a new "history" document under this supplier's document
        await supplierRef.collection('history').add({
          'totalPurchase': transactionAmount,
          'cashPayment': cashPayment,
          'remainingAmount': supplierTransaction,
          'timestamp': FieldValue.serverTimestamp(),
          'details': 'Initial Purchase',
          'image': _image,
        });

        // Save cash payment data to "cashbox" collection with Timestamp
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cashbox')
            .add({
          'amount': -cashPayment,
          'reason':
          "মোট বিক্রি: $transactionAmount & বর্তমান বাকি: $supplierTransaction",
          'time': FieldValue.serverTimestamp(), // Current timestamp
        });

        // Show receipt dialog after saving data
        _showReceiptDialog(
          supplierName: _nameController.text,
          phone: _phoneController.text,
          transactionAmount: transactionAmount,
          cashPayment: cashPayment,
          remainingAmount: supplierTransaction,
          transactionDate: DateFormat('dd/MM/yyyy').format(transactionDate),
        );

        print("Supplier Data Saved: $supplierData");

        // Clear form after saving
        _formKey.currentState!.reset();
        setState(() {
          _nameController.clear(); // Clear name field
          _phoneController.clear(); // Clear phone number field
          _transactionController.clear(); // Clear transaction field
          _cashPaymentController.clear(); // Clear cash payment field
          _descriptionController.clear();
          _selectedDate = DateTime.now(); // Reset to today's date after saving
          _selectedImage = null;
        });
      }
    } catch (e) {
      // Handle any errors during the save process
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving supplier: $e')),
        );
      }
    } finally {
      // After everything is done, reset the _isSaving flag
      setState(() {
        _isSaving = false; // Allow future submissions
      });
    }
  }

//এখান থেকে রিসিটের পিডিএফ এর কোড শুরু
  Future<void> generatePdfReceipt({
    required String supplierName,
    required String phone,
    required double transactionAmount,
    required double cashPayment,
    required double remainingAmount,
    required String transactionDate,
  }) async {
    // Load the font from assets
    final fontData =
    await rootBundle.load("assets/fonts/NotoSerifBengali-Regular.ttf");

    // Convert Uint8List to ByteData
    final byteData = ByteData.sublistView(fontData.buffer.asUint8List());

    final pdf = pw.Document();

    final ttf = pw.Font.ttf(byteData);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Container(
            padding: pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        "Hature Store",
                        style: pw.TextStyle(
                            font: ttf,
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900),
                      ),
                      pw.Text(
                        "Address: 2/1, Balashpur Road, Sadar, Mymensingh",
                        style: pw.TextStyle(
                            font: ttf,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black),
                      ),
                      pw.Text(
                        "Mobile: 01521444472, 01558993341",
                        style: pw.TextStyle(
                            font: ttf, fontSize: 14, color: PdfColors.black),
                      ),
                      pw.Text(
                        "Purchase Invoice",
                        style: pw.TextStyle(
                            font: ttf,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        "Date: $transactionDate",
                        style: pw.TextStyle(
                            font: ttf, fontSize: 14, color: PdfColors.grey700),
                      ),
                      pw.Divider(thickness: 2, color: PdfColors.blueAccent),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // Supplier Info
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Supplier's Phone No.: $phone",
                        style: pw.TextStyle(font: ttf, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Transaction Details Header
                pw.Text(
                  "Transaction Details",
                  style: pw.TextStyle(
                      font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),

                pw.SizedBox(height: 10),

                // Transaction Details Section
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildTransactionRow(
                          "Total Price", "$transactionAmount", ttf),
                      _buildTransactionRow("Cash Payment", "$cashPayment", ttf),
                      _buildTransactionRow(
                          "Due Amount", "$remainingAmount", ttf),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Footer/Thank you note
                pw.Center(
                  child: pw.Text(
                    "Thank you for shopping with us!",
                    style: pw.TextStyle(
                        font: ttf, fontSize: 14, color: PdfColors.green700),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Save or share the generated PDF as needed
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/receipt.pdf");
    await file.writeAsBytes(await pdf.save());

    // Optionally open or share the file
    await OpenFile.open(file.path);
  }

// Helper method to build rows for transaction details
  pw.Widget _buildTransactionRow(String label, String value, pw.Font ttf) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
                font: ttf,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black),
          ),
          pw.Text(
            value,
            style:
            pw.TextStyle(font: ttf, fontSize: 14, color: PdfColors.black),
          ),
        ],
      ),
    );
  }

// এখানে পিডিএফ এর কোড শেষ

// Show receipt dialog with print option
  void _showReceiptDialog({
    required String supplierName,
    required String phone,
    required double transactionAmount,
    required double cashPayment,
    required double remainingAmount,
    required String transactionDate,
  }) {
    FocusScope.of(context).requestFocus(FocusNode());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.brown, size: 30),
                  SizedBox(width: 8),
                  Text(
                    'ক্রয়ের রসিদ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.download, color: Colors.brown),
                onPressed: () async {
                  await generatePdfReceipt(
                    supplierName: supplierName,
                    phone: phone,
                    transactionAmount: transactionAmount,
                    cashPayment: cashPayment,
                    remainingAmount: remainingAmount,
                    transactionDate: transactionDate,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('রসিদ সফলভাবে ডাউনলোড হয়েছে!')),
                  );
                },
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: Colors.brown, thickness: 1.5),
                SizedBox(height: 10),
                _buildReceiptRow(
                  label: 'সাপ্লায়ারের নাম:',
                  value: supplierName,
                  valueStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildReceiptRow(
                  label: 'ফোন নম্বর:',
                  value: phone,
                  valueStyle: TextStyle(
                      color: Colors.brown, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Divider(color: Colors.grey[300], thickness: 1),
                SizedBox(height: 10),
                _buildReceiptRow(
                  label: 'মোট ক্রয়মূল্য:',
                  value: '${transactionAmount.toStringAsFixed(2)} টাকা',
                  icon: Icons.monetization_on_sharp,
                ),
                _buildReceiptRow(
                  label: 'নগদ পরিশোধ:',
                  value: '${cashPayment.toStringAsFixed(2)} টাকা',
                  icon: Icons.credit_card,
                ),
                _buildReceiptRow(
                  label: 'অবশিষ্ট দেনা:',
                  value: '${remainingAmount.toStringAsFixed(2)} টাকা',
                  icon: Icons.money_off,
                  valueStyle:
                  TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Divider(color: Colors.grey[300], thickness: 1),
                SizedBox(height: 10),
                _buildReceiptRow(
                  label: 'ক্রয়ের তারিখ:',
                  value: transactionDate,
                  icon: Icons.calendar_today,
                  valueStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          actions: [
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  children: [
                    SwitchListTile(
                      title: Text('ক্যাশবক্স দেখুন'),
                      value: _redirectToCashBoxScreenSwitch,
                      onChanged: (value) {
                        setState(() {
                          _redirectToCashBoxScreenSwitch = value;
                        });
                      },
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus(); // Close the dialog
                        if (_redirectToCashBoxScreenSwitch) {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => CashBoxScreen()),
                          );
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 8),
                        child: Text(
                          'ঠিক আছে',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );

  }

  // Helper method to build rows in the receipt dialog
  Widget _buildReceiptRow({
    required String label,
    required String value,
    IconData? icon,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          if (icon != null)
            Icon(
              icon,
              size: 16,
              color: Colors.brown,
            ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: valueStyle ??
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle,
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown[700],
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss the keyboard when tapping outside of the text fields
          FocusScope.of(context).unfocus();
        },
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Picker with icon and formatted text (dd/mm/yyyy)
                  Text(
                    "লেনদেনের তারিখ",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding:
                      EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(_selectedDate),
                            // Always show selected date or today's date
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                          Icon(Icons.calendar_today, color: Colors.black54),
                          // Calendar icon
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  Text(
                    "সাপ্লায়ারের ছবি",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Center(
                    // Center the image box
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          image: _selectedImage == null
                              ? DecorationImage(
                            image: AssetImage('assets/error.jpg'),
                            // ব্যাকগ্রাউন্ড ইমেজ
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? Center(
                            child: Text('ছবি নির্বাচন করুন',
                                style: TextStyle(color: Colors.black)))
                            : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 150,
                            height: 150,
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'নাম',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 12.0), // Adjust vertical padding
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'এখানে নাম লিখুন';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 10),

                  // Phone Input
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'ফোন নম্বর',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 12.0), // Adjust vertical padding
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'এখানে ফোন নম্বর লিখুন';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 10),

                  // Transaction Input
                  TextFormField(
                    controller: _transactionController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'মোট ক্রয়মূল্য/ পূর্বের বাকির পরিমাণ (টাকা)',
                      labelStyle: TextStyle(fontSize: 15.0),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 12.0), // Adjust vertical padding
                    ),
                  ),
                  SizedBox(height: 10),

                  // New Cash Payment Input
                  TextFormField(
                    controller: _cashPaymentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'নগদ পরিশোধ(টাকা নগদ পেলে)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 12.0), // Adjust vertical padding
                    ),
                  ),
                  SizedBox(height: 10),
                  // Description Input
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(labelText: 'বিবরণ', border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 6.0, horizontal: 12.0),),
                    maxLines: 3,),
                  SizedBox(height: 10),
                  // Save Button
                  Center(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSupplier,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        backgroundColor: Colors.brown[700],),
                      child: _isSaving
                          ? CircularProgressIndicator(color: Colors.white) :Text('সেভ করুন',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
