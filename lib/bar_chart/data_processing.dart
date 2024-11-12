import 'package:fl_chart/fl_chart.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

dartz.Tuple2<List<String>, List<BarChartGroupData>> processSalesData(
    List<Map<String, dynamic>> salesData, String timeRange) {
  Map<String, double> salesByPeriod = {};
  DateTime now = DateTime.now();
  String dayName = DateFormat('EEE').locale;

  if (timeRange == 'Daily') {
    // Generate the last 7 days of dates
    for (int i = 6; i >= 0; i--) {
      DateTime date = now.subtract(Duration(days: i));
      String formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}"; // Format as DD/MM
      salesByPeriod[formattedDate] = 0.0; // Initialize with zero
    }

    // Sum sales for each date in the salesData
    for (var sale in salesData) {
      DateTime date = sale['time'];
      String formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}"; // Format as DD/MM
      if (salesByPeriod.containsKey(formattedDate)) {
        salesByPeriod[formattedDate] = salesByPeriod[formattedDate]! + sale['amount'];
      }
    }
  } else if (timeRange == 'Monthly') {
    // Generate the last 12 months
    for (int i = 0; i < 12; i++) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      String formattedMonth = "${month.month.toString().padLeft(2, '0')}/${month.year}"; // Format as MM/YYYY
      salesByPeriod[formattedMonth] = 0.0; // Initialize with zero
    }

    // Sum sales for each month in the salesData
    for (var sale in salesData) {
      DateTime date = sale['time'];
      String formattedMonth = "${date.month.toString().padLeft(2, '0')}/${date.year}"; // Format as MM/YYYY
      if (salesByPeriod.containsKey(formattedMonth)) {
        salesByPeriod[formattedMonth] = salesByPeriod[formattedMonth]! + sale['amount'];
      }
    }
  } else if (timeRange == 'Yearly') {
    // Generate the last 5 years
    for (int i = 0; i < 5; i++) {
      int year = now.year - i;
      salesByPeriod[year.toString()] = 0.0; // Initialize with zero
    }

    // Sum sales for each year in the salesData
    for (var sale in salesData) {
      DateTime date = sale['time'];
      String year = date.year.toString();
      if (salesByPeriod.containsKey(year)) {
        salesByPeriod[year] = salesByPeriod[year]! + sale['amount'];
      }
    }
  } else {
    throw Exception("Invalid time range");
  }

  // Convert the map into a list of BarChartGroupData and the corresponding labels
  List<BarChartGroupData> barGroups = [];
  List<String> salePeriods = [];
  int index = 0;

  salesByPeriod.forEach((period, totalSales) {
    barGroups.add(BarChartGroupData(
      x: index++, // Use incremental index for the x-axis
      barRods: [
        BarChartRodData(
          toY: totalSales, // Use the total sales for the period
          width: 20.0,
          color: Colors.blue,
        ),
      ],
    ));
    salePeriods.add(period); // Keep track of the sale periods
  });

  return dartz.Tuple2(salePeriods, barGroups); // Return both sale periods and bar groups
}
