import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BarChartSample extends StatelessWidget {
  final List<BarChartGroupData> barGroups;
  final String Function(double) getBottomTitles;

  BarChartSample({required this.barGroups, required this.getBottomTitles});

  @override
  Widget build(BuildContext context) {
    double chartWidth = barGroups.length * 60.0;

    // Find the maximum sales amount for setting Y-axis limits
    double maxY = barGroups.map((group) => group.barRods[0].toY).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        width: chartWidth < MediaQuery.of(context).size.width
            ? MediaQuery.of(context).size.width
            : chartWidth,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toString(),
                      style: TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6,
                      child: Text(
                        getBottomTitles(value),
                        style: TextStyle(fontSize: 10),
                      ),
                    );
                  },
                  reservedSize: 30,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: true),
            gridData: FlGridData(show: true),
            maxY: maxY + (maxY * 0.1),
            minY: 0,
          ),
        ),
      ),
    );
  }
}

Future<List<BarChartGroupData>> fetchAndProcessSalesData(List<Map<String, dynamic>> salesData) async {
  DateTime now = DateTime.now();
  List<DateTime> last7Days = List.generate(7, (index) => now.subtract(Duration(days: index)));

  // Sort salesData by time (ascending order)
  salesData.sort((a, b) => a['time'].compareTo(b['time']));

  // List of bar groups to return
  List<BarChartGroupData> barGroups = [];

  for (int i = 0; i < last7Days.length; i++) {
    DateTime currentDay = last7Days[i];
    String formattedDay = DateFormat('yyyy-MM-dd').format(currentDay);

    // Check if there's sales data for the current day
    var sale = salesData.firstWhere(
          (sale) => DateFormat('yyyy-MM-dd').format(sale['time'].toDate()) == formattedDay,
      orElse: () => <String, dynamic>{}, // Return an empty map instead of null
    );

    // Safely check if sale contains 'amount'
    double salesAmount = sale.isNotEmpty && sale.containsKey('amount') ? sale['amount'].toDouble() : 0.0;

    barGroups.add(
      BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: salesAmount,
            color: Colors.blue,
            width: 10.0, // Adjust the width of each bar
          ),
        ],
      ),
    );
  }

  return barGroups;
}

String getBottomTitles(double value) {
  DateTime now = DateTime.now();
  DateTime date = now.subtract(Duration(days: value.toInt()));

  return DateFormat('dd/MM').format(date); // Format date to show (dd/MM)
}
