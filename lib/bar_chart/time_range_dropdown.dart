import 'package:flutter/material.dart';

class TimeRangeDropdown extends StatelessWidget {
  final String selectedRange;
  final ValueChanged<String?> onChanged;

  const TimeRangeDropdown({required this.selectedRange, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selectedRange,
      items: [
        DropdownMenuItem(child: Text('Daily'), value: 'Daily'),
        DropdownMenuItem(child: Text('Monthly'), value: 'Monthly'),
        DropdownMenuItem(child: Text('Yearly'), value: 'Yearly'),
      ],
      onChanged: onChanged,
    );
  }
}