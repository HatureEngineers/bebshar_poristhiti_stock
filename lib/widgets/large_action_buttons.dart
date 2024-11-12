import 'package:flutter/material.dart';
import '../stock_purchase/purchase_with_stock.dart';
import '../stock_sale/sale_with_stock.dart';

class LargeActionButtons extends StatelessWidget {
  final BuildContext context;
  final double screenWidth;
  final double screenHeight;

  LargeActionButtons(this.context, this.screenWidth, this.screenHeight);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLargeActionButton(
          'assets/icon/shopping-cart_6145556.png', // Path to your purchase SVG icon
          'ক্রয়',
          context,
          Colors.brown,
        ),
        _buildLargeActionButton(
          'assets/icon/cash-register_3258571.png', // Path to your sale SVG icon
          'বিক্রয়',
          context,
          Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildLargeActionButton(
      String assetPath, String label, BuildContext context, Color color) {
    // Gradient colors for the buttons
    final Gradient gradient = (label == 'ক্রয়')
        ? LinearGradient(colors: [Colors.blue.shade100, Colors.yellow.shade100, Colors.blue.shade100])
        : LinearGradient(
        colors: [Colors.blue.shade100, Colors.yellow.shade100, Colors.blue.shade100]);

    return Expanded(
      child: InkWell(
        onTap: () {
          if (label == 'ক্রয়') {
            // Navigate to PurchasePage
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => PurchaseStockPage()));
          } else if (label == 'বিক্রয়') {
            // Navigate to SalesPage
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => SaleStockPage()));
          }
        },
        child: Card(
          elevation: 8,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: gradient, // Apply gradient background to the button
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    assetPath, // Use SVG icon
                    width: 90, // Adjust width as needed
                    height: 90, // Set color for the SVG icon
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold, // Make the text bold
                      color: Colors.black, // Change text color to black
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
