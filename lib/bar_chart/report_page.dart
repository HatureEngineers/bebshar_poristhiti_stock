import 'package:flutter/material.dart';
import 'bar_chart_sample.dart';
import 'sales_service.dart'; // For fetching sales data
import 'data_processing.dart'; // For processing sales data
import 'time_range_dropdown.dart';
import 'package:fl_chart/fl_chart.dart'; // For the time range dropdown
import 'package:dartz/dartz.dart' as dartz; // Import with alias

class ReportPage extends StatefulWidget {
  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String selectedTimeRange = 'Daily'; // Default to Daily

  Future<dartz.Tuple2<List<String>, List<BarChartGroupData>>> fetchAndProcessSalesData(String timeRange) async {
    // Fetch sales data based on the selected time range
    List<Map<String, dynamic>> salesData = await fetchSalesData(timeRange);
    return processSalesData(salesData, timeRange); // Process the sales data for the chart
  }

  String getBottomTitles(double value, List<String> salePeriods) {
    int index = value.toInt();
    if (index >= 0 && index < salePeriods.length) {
      return salePeriods[index]; // Return the formatted period (date, month, or year)
    } else {
      return ''; // Return an empty string for out-of-bounds values
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Report', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Enhanced dropdown with styling
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 40, // Set a smaller height for the container
              padding: const EdgeInsets.symmetric(horizontal: 8), // Adjust padding for a balanced look
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade200, width: 1),
              ),
              child: Center(
                child: TimeRangeDropdown(
                  selectedRange: selectedTimeRange,
                  onChanged: (newValue) {
                    setState(() {
                      selectedTimeRange = newValue!; // Update selected time range
                    });
                  },
                ),
              ),
            ),

            Expanded(
              child: FutureBuilder<dartz.Tuple2<List<String>, List<BarChartGroupData>>>(
                future: fetchAndProcessSalesData(selectedTimeRange),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error fetching data', style: TextStyle(color: Colors.red, fontSize: 16)));
                  } else if (!snapshot.hasData || snapshot.data!.value2.isEmpty) {
                    return Center(child: Text('No sales data available', style: TextStyle(fontSize: 16)));
                  }

                  // Get the list of sale periods and bar groups from the data
                  List<String> salePeriods = snapshot.data!.value1; // Use value1 for salePeriods
                  List<BarChartGroupData> barGroups = snapshot.data!.value2; // Use value2 for barGroups

                  // Pass the processed sales data and sale periods to the chart
                  return BarChartSample(
                    barGroups: barGroups,
                    getBottomTitles: (double value) {
                      return getBottomTitles(value, salePeriods); // Pass the salePeriods list
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
