import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogoutHandler {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signOut(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/signIn', (route) => false);
  }
}
