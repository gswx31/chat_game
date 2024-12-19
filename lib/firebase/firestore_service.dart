import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late FirebaseAuth _auth; // Declare FirebaseAuth instance
  String? _currentUserId; // Declare a variable to store the current user ID

  FirestoreService() {
    _auth = FirebaseAuth.instance;
    _currentUserId = _auth.currentUser?.uid; // Initialize the current user ID
  }

  Future<bool> moveRoomToHistory(String roomId) async {
    try {
      DocumentSnapshot roomSnapshot = await _db.collection('rooms').doc(roomId).get();
      print('roomSnapshot');
      print(roomSnapshot);
      print(roomSnapshot.data);
      if (roomSnapshot.exists) {
        // Before moving the room data to history, ensure that you have access to the current user's data
        if (_currentUserId != null) {
          // Optionally handle user-specific actions here if necessary
          await _db.collection('history').doc(roomId).set(roomSnapshot.data()! as Map<String, dynamic>);
          // Example of a user-specific action, if needed:
           final userRef = _db.collection('rooms').doc(roomId).collection('users').doc(_currentUserId);
           await userRef.delete(); // or any other user-specific handling
          return true;  // Successfully processed
        } else {
          print("Current user ID is null");
          return false;  // Current user ID was not found
        }
      }
      return false;  // roomSnapshot does not exist
    } catch (e) {
      print('An error occurred: $e');
      return false;  // Exception occurred
    }
  }
}
