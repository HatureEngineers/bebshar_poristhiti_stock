import 'package:flutter/material.dart';
import '../expense/expense.dart';
import '../purchase_management/old_supplier_purchase.dart';
import '../sales_management/due/customer_due_list.dart'; // due page
import '../purchase_management/payment/supplier_page.dart';
import '../product_management/stock_management_page.dart';
import '../sales_management/report/sale_report.dart';

class ActionGrid extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  ActionGrid(this.screenWidth, this.screenHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: screenHeight * 0.31, // Set a height for the grid to prevent overflow
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        childAspectRatio: (screenWidth / (screenHeight * 0.5)), // Adjust aspect ratio based on height
        children: [
          _buildGridItem(
            context,
            'assets/icon/transaction_6145523.png',
            'পার্টি লেনদেন',
            OldSupplierPurchase(),
            Colors.blue.shade100,
            Colors.yellow.shade100,
          ),
          _buildGridItem(
            context,
            'assets/icon/analytics_2518147.png',
            'বিক্রয় সমূহ',
            SaleReportPage(),
            Colors.blue.shade100,
            Colors.yellow.shade100,
          ),
          _buildGridItem(
            context,
            'assets/icon/due.png',
            'বাকির খাতা',
            DuePage(),
            Colors.blue.shade100,
            Colors.yellow.shade100,
          ),
          _buildGridItem(
            context,
            'assets/icon/logistic-distribution_14669990.png',
            'প্রোডাক্ট স্টক',
            StockManagementPage(),
            Colors.yellow.shade100,
            Colors.blue.shade100,
          ),
          _buildGridItem(
            context,
            'assets/icon/wallet_1747291.png',
            'খরচের হিসাব',
            ExpensePage(),
            Colors.yellow.shade100,
            Colors.blue.shade100,
          ),
          _buildGridItem(
            context,
            'assets/icon/book_8998090.png',
            'পার্টি/সাপ্লায়ার',
            SupplierPage(),
            Colors.yellow.shade100,
            Colors.blue.shade100,
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, String assetPath, String label, Widget? page, Color color1, Color color2) {
    return InkWell(
      onTap: () {
        if (page != null) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => page,
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        }
      },
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color1, color2], // Use the provided gradient colors
              begin: Alignment.topCenter, // Starting point of the gradient
              end: Alignment.bottomCenter, // Ending point of the gradient
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                assetPath,
                width: 50, // Increased width
                height: 50, // Increased height
              ),
              SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold), // Changed text color to black
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis, // Handle overflow
                maxLines: 1, // Center the text
              ),
            ],
          ),
        ),

      ),
    );
  }
}
