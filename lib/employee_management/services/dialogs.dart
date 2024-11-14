// lib/utils/dialog_util.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DialogUtil {
  // Function to show the image selection dialog
  static Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Choose Image Source'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              child: Text('Camera'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: Text('Gallery'),
            ),
          ],
        );
      },
    );
  }

  // Function to show image in a dialog
  static void showImageDialog(BuildContext context, String? imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: AspectRatio(
          aspectRatio: 1,
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(imageUrl, fit: BoxFit.cover)
              : Image.asset('assets/placeholder.png', fit: BoxFit.cover),
        ),
      ),
    );
  }
}
