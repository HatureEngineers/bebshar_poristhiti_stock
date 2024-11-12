import 'package:bebshar_poristhiti_stock/product_management/product.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StockManagementPage extends StatefulWidget {
  @override
  _StockManagementPageState createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  String _searchQuery = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => unfocusKeyboard(context),
      child: Scaffold(
        appBar: buildAppBar(context, userId, _firestore),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              buildSearchField(_searchProducts),
              SizedBox(height: 20),
              Expanded(
                child: buildProductList(_firestore, userId, _searchQuery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to update the search query
  void _searchProducts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  // Function to unfocus the keyboard when tapping outside
  void unfocusKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  // Function to build the AppBar
  AppBar buildAppBar(BuildContext context, String userId, FirebaseFirestore firestore) {
    return AppBar(
      backgroundColor: const Color.fromARGB(122, 3, 180, 148),
      elevation: 0,
      title: const Text('Stock Management'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            final newProduct = await Navigator.push<Product>(
              context,
              MaterialPageRoute(builder: (context) => ProductPage()),
            );
            if (newProduct != null) {
              firestore.collection('users').doc(userId).collection('stock').add(newProduct.toMap());
            }
          },
        ),
      ],
    );
  }

  // Function to build the search field
  Widget buildSearchField(Function(String) onSearch) {
    return Material(
      elevation: 5,
      shadowColor: Colors.grey.withOpacity(0.2),
      borderRadius: BorderRadius.circular(10),
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Search Products',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: onSearch,
      ),
    );
  }

  // Function to build the product list with search functionality
  Widget buildProductList(FirebaseFirestore firestore, String userId, String searchQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('users').doc(userId).collection('stock').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot> productDocs = snapshot.data!.docs;
        List<Product> products = productDocs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;

          // Convert fields and handle boolean for isPacket
          return Product(
            name: data['name'] as String,
            price: _parseStringToDouble(data['price']),
            quantity: _parseStringToInt(data['quantity']),
            totalAmount: _parseStringToDouble(data['totalAmount']),
            size: _parseStringToDouble(data['size']),
            unitUnit: data['unitUnit'] as String,
            isPacket: _parseStringToBool(data['isPacket']),
            stockUnit: data['stockUnit'] as String,
          );
        }).toList();

        // Filter products by search query
        if (searchQuery.isNotEmpty) {
          products = products.where((product) => product.name.toLowerCase().contains(searchQuery)).toList();
        }

        return products.isEmpty
            ? const Center(
          child: Text(
            'No products found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        )
            : ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final docId = productDocs[index].id;

            // Upload updated data back to Firestore with correct types
            _updateFirestoreTypes(firestore, userId, docId, product);

            return buildProductCard(context, firestore, userId, product, docId);
          },
        );
      },
    );
  }

  // Convert string to double if necessary
  double _parseStringToDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  int _parseStringToInt(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is double) {
      return value.toInt();
    } else if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  bool _parseStringToBool(dynamic value) {
    if (value is bool) {
      return value;
    } else if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  // Update Firestore with the correct data types
  void _updateFirestoreTypes(FirebaseFirestore firestore, String userId, String docId, Product product) {
    firestore.collection('users').doc(userId).collection('stock').doc(docId).update({
      'price': product.price,
      'quantity': product.quantity,
      'totalAmount': product.totalAmount,
      'size': product.size,
      'isPacket': product.isPacket,
    });
  }

  // Format the price, removing unnecessary trailing zeros
  String formatPrice(double price) {
    return price == price.toInt() ? price.toInt().toString() : price.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  }

  // Function to build the individual product card
  // Function to build the individual product card
  Widget buildProductCard(BuildContext context, FirebaseFirestore firestore, String userId, Product product, String docId) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color.fromARGB(255, 252, 255, 235),
      child: GestureDetector(
        onTap: () {
          _showProductDetailsDialog(context, product); // Show product details on card tap
        },
        child: ListTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Unit Size: ${formatPrice(product.size)} ${product.size <= 1000 ? (product.unitUnit == 'kg' ? 'gm' : product.unitUnit == 'l' ? 'ml' : product.unitUnit) : product.unitUnit}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          subtitle: Text(
            'Unit Price: ${formatPrice(product.price)}৳',
            style: TextStyle(color: Colors.grey[900], fontSize: 13),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                child: Text(
                  'Stock:\n ${product.totalAmount} ${product.isPacket ? 'pcs' : product.stockUnit}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(width: 6),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    _showStockEditDialog(context, firestore, userId, docId, product); // Open stock edit dialog
                  },
                  child: const Icon(
                    Icons.edit, // Change to edit icon
                    size: 18,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // Show product details in a dialog
  void _showProductDetailsDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Price: ${formatPrice(product.price)}৳'),
              Text('Size: ${formatPrice(product.size)} ${product.unitUnit}'),
              Text('Stock: ${product.totalAmount} ${product.isPacket ? 'pcs' : product.stockUnit}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }



  // Stock edit dialog
  void _showStockEditDialog(BuildContext context, FirebaseFirestore firestore, String userId, String docId, Product product) {
    TextEditingController stockController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Rounded corners
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Stock for',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    product.name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  SizedBox(height: 4), // Space between title and current stock
                  Text(
                    'Current Stock: ${product.totalAmount} ${product.isPacket ? 'pcs' : product.stockUnit}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the current dialog
                  _showDeleteConfirmation(context, firestore, userId, docId); // Open delete confirmation dialog
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              const SizedBox(height: 16), // Space between input and buttons
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 16), // Padding for alignment
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _updateStockAmount(firestore, userId, docId, product, stockController.text, 'add');
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // Corrected parameter
                      padding: EdgeInsets.symmetric(vertical: 2),
                      minimumSize: Size(60, 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Add',style: TextStyle(color: Colors.white),),
                  ),
                  const SizedBox(height: 1), // Space between buttons
                  ElevatedButton(
                    onPressed: () {
                      _updateStockAmount(firestore, userId, docId, product, stockController.text, 'subtract');
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // Corrected parameter
                      padding: EdgeInsets.symmetric(vertical: 2),
                      minimumSize: Size(80, 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Subtract',style: TextStyle(color: Colors.white),),
                  ),
                  const SizedBox(height: 1), // Space between buttons
                  ElevatedButton(
                    onPressed: () {
                      _updateStockAmount(firestore, userId, docId, product, stockController.text, 'update');
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Corrected parameter
                      padding: EdgeInsets.symmetric(vertical: 2),
                      minimumSize: Size(100, 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Update Stock',style: TextStyle(color: Colors.white),),
                  ),
                ],
              ),
            ),
          ],

        );
      },
    );
  }



// Method to show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, FirebaseFirestore firestore, String userId, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without deleting
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteProduct(firestore, userId, docId);
                Navigator.of(context).pop(); // Close both dialogs
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }


// Function to delete product from Firestore
  void _deleteProduct(FirebaseFirestore firestore, String userId, String docId) {
    firestore.collection('users').doc(userId).collection('stock').doc(docId).delete();
  }


  // Update stock based on the user's choice (add, subtract, or update)
  void _updateStockAmount(FirebaseFirestore firestore, String userId, String docId, Product product, String input, String action) {
    double inputAmount = double.tryParse(input) ?? 0;
    double updatedStock = product.totalAmount;

    if (action == 'add') {
      updatedStock += inputAmount;
    } else if (action == 'subtract') {
      updatedStock -= inputAmount;
    } else if (action == 'update') {
      updatedStock = inputAmount;
    }

    firestore.collection('users').doc(userId).collection('stock').doc(docId).update({
      'totalAmount': updatedStock,
    });
  }
}
