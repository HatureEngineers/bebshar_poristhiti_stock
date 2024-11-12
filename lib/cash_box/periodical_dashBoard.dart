import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedPeriod = 'Daily';
  String _selectedMonth = DateFormat('MMMM').format(DateTime.now());
  String _selectedYear = DateFormat('yyyy').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to get the screen size
    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;

    // Define base width and height (design is for a 375x812 base screen)
    double baseWidth = 375.0;
    double baseHeight = 812.0;

    // Calculate scaling factors based on the actual screen dimensions
    double scaleWidth = screenWidth / baseWidth;
    double scaleHeight = screenHeight / baseHeight;

    // Use the smaller of the two scaling factors for consistent scaling
    double scale = scaleWidth < scaleHeight ? scaleWidth : scaleHeight;

    return Scaffold(
      appBar: AppBar(
        title: Text('Business Dashboard'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16 * scale), // Scale padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Period Filter
            _buildDateFilter(scale),
            SizedBox(height: 20 * scale),

            // First two cards in a row, wrapped with Flexible or Expanded
            Row(
              children: [
                // Total Purchases
                Expanded(
                  child: _buildColorfulCard(
                    title: 'Total Purchases',
                    value: '\$10,000',
                    subValue1: 'Paid Instantly: \$7,000',
                    subValue2: 'Pending: \$3,000',
                    icon: Icons.shopping_bag_outlined,
                    gradientColors: [Colors.blue, Colors.blueAccent],
                    scale: scale, // Pass the scaling factor
                  ),
                ),
                SizedBox(width: 10 * scale), // Adjust spacing based on scale

                // Total Sales
                Expanded(
                  child: _buildColorfulCard(
                    title: 'Total Sales',
                    value: '\$15,000',
                    subValue1: 'Hand-to-hand: \$10,000',
                    subValue2: 'Receivable: \$5,000',
                    icon: Icons.attach_money_outlined,
                    gradientColors: [Colors.green, Colors.lightGreen],
                    scale: scale, // Pass the scaling factor
                  ),
                ),
              ],
            ),
            SizedBox(height: 20 * scale),

            // Expenses Section
            _buildColorfulCard(
              title: 'Total Expenses',
              value: '\$5,000',
              icon: Icons.money_off_outlined,
              gradientColors: [Colors.redAccent, Colors.red],
              scale: scale, // Pass the scaling factor
            ),
            SizedBox(height: 20 * scale),

            // Cashbox Section (for daily/weekly/monthly/yearly)
            if (_selectedPeriod == 'Daily' ||
                _selectedPeriod == 'Weekly' ||
                _selectedPeriod == 'Monthly' ||
                _selectedPeriod == 'Yearly')
              _buildColorfulCard(
                title: 'Cashbox',
                value: '\$2,000',
                icon: Icons.savings_outlined,
                gradientColors: [Colors.purple, Colors.deepPurple],
                scale: scale, // Pass the scaling factor
              ),
          ],
        ),
      ),
    );
  }

  // Year Picker
  Widget _buildYearPicker(double scale) {
    return DropdownButton<String>(
      value: _selectedYear,
      onChanged: (String? newValue) {
        setState(() {
          _selectedYear = newValue!;
        });
      },
      items: List.generate(10, (index) {
        String year = (DateTime.now().year - index).toString();
        return DropdownMenuItem<String>(
          value: year,
          child: Text(year, style: TextStyle(fontSize: 16 * scale)),
        );
      }).toList(),
    );
  }

  // Date Filter with Period Selection (Monthly, Yearly, etc.)
  Widget _buildDateFilter(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Period:',
          style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            DropdownButton<String>(
              value: _selectedPeriod,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPeriod = newValue!;
                });
              },
              items: ['Daily', 'Weekly', 'Monthly', 'Yearly']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: TextStyle(fontSize: 16 * scale)),
                );
              }).toList(),
            ),
            SizedBox(width: 20 * scale),
            if (_selectedPeriod == 'Monthly') _buildMonthYearPicker(scale),
            if (_selectedPeriod == 'Yearly') _buildYearPicker(scale),
          ],
        ),
      ],
    );
  }

  // Combined Month and Year Picker
  Widget _buildMonthYearPicker(double scale) {
    return Row(
      children: [
        DropdownButton<String>(
          value: _selectedMonth,
          onChanged: (String? newValue) {
            setState(() {
              _selectedMonth = newValue!;
            });
          },
          items: List.generate(12, (index) {
            String month =
            DateFormat('MMMM').format(DateTime(2020, index + 1, 1));
            return DropdownMenuItem<String>(
              value: month,
              child: Text(month, style: TextStyle(fontSize: 16 * scale)),
            );
          }).toList(),
        ),
        SizedBox(width: 10 * scale),
        _buildYearPicker(scale),
      ],
    );
  }

  // A Colorful Card with Gradient Background
  Widget _buildColorfulCard({
    required String title,
    required String value,
    String? subValue1,
    String? subValue2,
    required IconData icon,
    required List<Color> gradientColors,
    required double scale,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15 * scale)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15 * scale),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 28 * scale, color: Colors.white),
                  SizedBox(width: 10 * scale),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10 * scale),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (subValue1 != null)
                Text(
                  subValue1,
                  style: TextStyle(fontSize: 16 * scale, color: Colors.white70),
                ),
              if (subValue2 != null)
                Text(
                  subValue2,
                  style: TextStyle(fontSize: 16 * scale, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
