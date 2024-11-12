import 'package:flutter/material.dart';

class EditNameDialog extends StatelessWidget {
  final TextEditingController controller;
  final Function onSave;

  EditNameDialog({
    required this.controller,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('নাম পরিবর্তন করুন', style: TextStyle(fontSize: 20)),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: "নতুন নাম লিখুন"),
      ),
      actions: <Widget>[
        ElevatedButton(
          child: Text('সংরক্ষণ করুন'),
          onPressed: () {
            onSave();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
