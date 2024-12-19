import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageHelper {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return null;
    print('Selected image path: ${image.path}');
    return await _cropImage(File(image.path));
  }

  Future<File?> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.square,
      ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Photo',
          toolbarColor: Colors.teal,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Colors.teal,
        ),
        IOSUiSettings(
          title: 'Edit Photo',
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<String?> uploadImage(File image) async {
    try {
      final FirebaseAuth _auth = FirebaseAuth.instance;
      final User? user = _auth.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'USER_NOT_SIGNED_IN',
          message: 'User is not signed in.',
        );
      }

      print('User ID: ${user.uid}');
      print('Is Anonymous: ${user.isAnonymous}');

      final Reference storageReference = FirebaseStorage.instance
          .ref()
          .child(user.isAnonymous ? 'guest/${user.uid}/profile_image.jpg' : '${user.uid}/profile_image.jpg');

      final UploadTask uploadTask = storageReference.putFile(image);
      final TaskSnapshot downloadUrl = await uploadTask.whenComplete(() => {});
      final String url = await downloadUrl.ref.getDownloadURL();
      print('Image uploaded to: $url');
      return url;
    } catch (e) {
      print('Failed to upload image: $e');
      return null;
    }
  }
}
