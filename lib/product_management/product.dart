import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'stock_management_page.dart';

class Product {
  final String name;
  final double price;
  final int quantity;
  final double size;
  double totalAmount;
  final bool isPacket;
  String unitUnit;  // New field for the selected unit from dropdown
  String stockUnit;

  Product({
    required this.name,
    required this.price,
    required this.quantity,
    required this.size,
    required this.totalAmount,
    required this.isPacket,
    required this.unitUnit, // New parameter
    required this.stockUnit,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
      'unitUnit': unitUnit, // Include unitUnit in the map
      'stockUnit': stockUnit,
      'size': size,
      'totalAmount': totalAmount,
      'isPacket': isPacket,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      name: map['name'],
      price: map['price'],
      quantity: map['quantity'],
      size: map['size'] is double
          ? map['size']
          : double.tryParse(map['size'].toString()) ?? 0.0,
      totalAmount: map['totalAmount'],
      isPacket: map['isPacket'] ?? false,
      unitUnit: map['unitUnit'] ?? '', // Initialize unitUnit
      stockUnit: map['stockUnit'] ?? '',
    );
  }
}

class ProductPage extends StatefulWidget {
  final Product? existingProduct;

  ProductPage({this.existingProduct});

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  bool _isSubmitting = false;
  dynamic _selectedUnit = 'pcs';

  bool _isPacketChecked = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      _nameController.text = widget.existingProduct!.name;
      _priceController.text = widget.existingProduct!.price.toString();
      _stockController.text = widget.existingProduct!.quantity.toString();
    }
  }


  void _addOrEditProduct() async {
    if (_isSubmitting) return; // Prevent multiple submissions
    setState(() {
      _isSubmitting = true;
    });
    if (_nameController.text.trim().isEmpty) {
      _showErrorDialog('Product name is required.');
      setState(() {
        _isSubmitting = false; // Re-enable the button
      });
      return;
    }

    // Parse the quantity from the stock controller
    int quantity = int.tryParse(_stockController.text.trim()) ?? 1;

    // Check the size input
    double sizeValue = double.tryParse(_sizeController.text.trim()) ?? 0;

    String selectedUnit = _selectedUnit; // Keep the selected unit

    final product = Product(
      name: _nameController.text.trim(),
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      quantity: quantity,
      size: sizeValue,
      unitUnit: selectedUnit,
      stockUnit: selectedUnit, // Initialize stockUnit with selected unit
      totalAmount: _isPacketChecked ? quantity.toDouble() : sizeValue * quantity,
      isPacket: _isPacketChecked,
    );

    // Check if a product with the same name, size, and unitUnit already exists
    final userProductsCollection = _firestore.collection('users').doc(userId).collection('stock');
    final existingProduct = await userProductsCollection
        .where('name', isEqualTo: product.name)
        .where('size', isEqualTo: product.size)
        .where('unitUnit', isEqualTo: product.unitUnit)
        .get();

    if (existingProduct.docs.isNotEmpty) {
      // Show alert dialog that product already exists
      _showProductExistsDialog();
      setState(() {
        _isSubmitting = false; // Re-enable the button
      });
      return; // Exit without adding the product
    }

    // Update stockUnit based on totalAmount and selectedUnit
    if (product.totalAmount > 1000 && !_isPacketChecked) {
      if (selectedUnit == 'gm') {
        product.stockUnit = 'kg'; // Convert to kg
        product.totalAmount = product.totalAmount / 1000; // Convert totalAmount to kg
      } else if (selectedUnit == 'ml') {
        product.stockUnit = 'l'; // Convert to liter
        product.totalAmount = product.totalAmount / 1000; // Convert totalAmount to liter
      }
    }

    await userProductsCollection.add(product.toMap());

    // Show the dialog with product details
    _showProductDetailsDialog(product);

    setState(() {
      _isSubmitting = false; // Re-enable the button after submission
    });
  }
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Error',
            style: TextStyle(color: Colors.red),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearFields();
                FocusScope.of(context).unfocus();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }


  void _showProductExistsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Product Already Exists',
            style: TextStyle(color: Colors.red),
          ),
          content: Text('A product with the same name, size, and unit already exists.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearFields();
                FocusScope.of(context).unfocus();// Close the dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Button color
              ),
              child: Text('OK', style: TextStyle(color: Colors.white)), // White text on button
            ),
          ],
        );
      },
    );
  }





  void _clearFields() {
    _nameController.clear();
    _priceController.clear();
    _stockController.clear();
    _sizeController.clear();
    setState(() {
      _selectedUnit = 'pcs'; // Reset unit selection to default
      _isPacketChecked = false; // Reset checkbox state
    });
    FocusScope.of(context).unfocus(); // Dismiss the keyboard
  }

  void _showProductDetailsDialog(Product product) {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Product Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${product.name}'),
              Text('Price: ৳${(product.price)}'),
              Text('Quantity: ${product.quantity} pcs'),
              Text('Unit Size: ${product.size} ${product.unitUnit}'),
              Text('Total Stock: ${product.totalAmount} ${product.isPacket ? 'pcs' : product.stockUnit}'),
              Text('Packet Sell: ${product.isPacket ? 'Yes' : 'No'}'),
              Text('Total Value: ${product.totalAmount*product.price}')
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _clearFields();
                FocusScope.of(context).unfocus();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(122, 3, 180, 148),
        elevation: 0,
        title: Text(widget.existingProduct == null ? 'Add Product' : 'Edit Product'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0), // Add space from the right edge
            child: ElevatedButton(
              onPressed: () {
                // Navigate to StockManagementPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StockManagementPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, // Customize button color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0), // Rounded rectangular shape
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Adjust padding
                elevation: 6, // Add shadow
                shadowColor: Colors.black.withOpacity(0.5), // Customize shadow color
              ),
              child: Icon(
                Icons.inventory_outlined,
                color: Colors.white, // Adjust icon color
                size: 24, // Customize icon size if needed
              ),
            ),
          ),
        ],
      ),

      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus(); // Dismiss the keyboard on tap outside
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.05), // Dynamic padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.02), // Dynamic height
              _buildTitle('Product Details'),
              SizedBox(height: screenHeight * 0.02),
              _buildTextField(_nameController, 'Product Name', 'Enter product name', Icons.shopping_bag_outlined),
              SizedBox(height: screenHeight * 0.02),
              _buildTextField(
                _priceController,
                'Price',
                'Enter price',
                Icons.attach_money_outlined,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: screenHeight * 0.02),

              // Quantity, Size, and Unit Fields
              Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Center align items vertically
                children: [
                  // Size Field
                  Expanded(
                    flex: 2,
                    child: _buildTextField(_sizeController, 'Per Packet Size', 'Enter size', Icons.straighten_outlined),
                  ),
                  SizedBox(width: screenWidth * 0.01), // Dynamic spacing
                  // Unit Dropdown
                  Expanded(
                    flex: 1,
                    child: _buildDropdown(
                      'Unit',
                      _selectedUnit,
                      ['kg', 'gm', 'pcs', 'L', 'ml'],
                          (value) {
                        setState(() {
                          _selectedUnit = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              Row(
                children: [
                  Checkbox(
                    value: _isPacketChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        _isPacketChecked = value ?? false;
                      });
                    },
                  ),
                  const Text('Packet'),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),
              _buildTextField(
                _stockController,
                'Quantity',
                'Enter quantity',
                Icons.production_quantity_limits_outlined,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: screenHeight * 0.04),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _addOrEditProduct,
                  icon: Icon(
                    widget.existingProduct == null ? Icons.add : Icons.update,
                    color: Colors.white,
                  ),
                  label: Text(
                    widget.existingProduct == null ? 'Add Product' : 'Update Product',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[400],
                    minimumSize: Size(screenWidth * 0.5, 50), // Dynamic button width
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildDropdown(String label, String selectedValue, List<String> items, Function(String?)? onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      value: selectedValue,
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
