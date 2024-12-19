import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import 'dashboard_screen.dart';

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final defaultImg = null; // 기본 이미지 URL
  final Uuid uuid = Uuid(); // UUID 생성기

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
      final firebase_auth.AuthCredential credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      firebase_auth.UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _handleUser(userCredential.user);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    } catch (e) {
      print('Failed to sign in with Google: $e');
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      firebase_auth.UserCredential userCredential = await _auth.signInAnonymously();
      await _handleUser(userCredential.user);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    } catch (e) {
      print('Failed to sign in anonymously: $e');
    }
  }

  Future<void> _handleUser(firebase_auth.User? user) async {
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('members').doc(user.uid).get();
      if (!userDoc.exists) {
        final String guestName = 'Guest_${uuid.v4().substring(0, 8)}';

        await _firestore.collection('members').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? guestName,
          'photoURL': defaultImg, // 기본 이미지 설정
          'role': 'guest',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isActive': true,
          'metadata': {
            'lastPurchase': null,
            'preferences': {}
          }
        });
      } else {
        await _firestore.collection('members').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Game - Sign In'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Image.asset('assets/images/logo.png', height: 150),
            SizedBox(height: 20),
            Text(
              'Welcome to Chat Game!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: null, // 카카오 로그인 기능 구현 필요
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/kakao_logo.png', height: 24),
                  SizedBox(width: 10),
                  Text('카카오로 로그인', style: TextStyle(fontSize: 18)),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFEE500),
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              //onPressed: _signInWithGoogle,
              onPressed: null, // 카카오 로그인 기능 구현 필요
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/google_logo.png', height: 24),
                  SizedBox(width: 10),
                  Text('구글로 로그인', style: TextStyle(fontSize: 18)),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFEE500),
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: Colors.black),
                ),
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: _signInAnonymously,
              child: Text('게스트로 계속하기', style: TextStyle(fontSize: 16)),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
