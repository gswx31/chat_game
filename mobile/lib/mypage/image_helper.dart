import 'dart:io';
import 'package:image_picker/image_picker.dart';

// Firebase Storage removed. Profile photos come from Google Sign-In photoURL.
// This helper is kept for future use (e.g. uploading to own backend).
class ImageHelper {
  final _picker = ImagePicker();

  Future<File?> pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (xFile == null) return null;
    return File(xFile.path);
  }
}
