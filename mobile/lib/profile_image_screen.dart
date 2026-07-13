import 'package:flutter/material.dart';

class ProfileImageScreen extends StatelessWidget {
  final String displayName;
  final String photoURL;

  ProfileImageScreen({required this.displayName, required this.photoURL});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
      ),
      body: Center(
        child: Hero(
          tag: 'profileImage',
          child: Image.network(
            photoURL,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
