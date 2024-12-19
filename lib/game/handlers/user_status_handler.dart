import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserStatusHandler {
  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;
  late String _currentUserId;
  Timer? _offlineTimer;
  bool _isStatusListenerSetup = false;
  bool _isOnline = false;
  bool _isAway = false;
  bool isListenerSetup = false;
  Timer? _backgroundTimer;
  Function? onLeaveRoomCallback;
  UserStatusHandler({this.onLeaveRoomCallback}) {
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _currentUserId = _auth.currentUser?.uid ?? '';
  }
  Future<void> setUserOnline(String roomId) async {
    if (_currentUserId.isNotEmpty && !_isOnline) {
      final userRef = _firestore.collection('rooms').doc(roomId).collection('users').doc(_currentUserId);
      try {
        // 만약 isOnline 상태가 이미 true라면, 추가적인 업데이트를 하지 않음
        final userDoc = await userRef.get();
        if (userDoc.exists && userDoc.data()?['isOnline'] == true) {
          print('User $_currentUserId is already online, skipping update.');
          _isOnline = true;
          _cancelOfflineTimer();
          return;
        }

        print('Setting user $_currentUserId to online in room $roomId');
        await userRef.update({
          'isOnline': true,
          'isAway': false,
        });
        _isOnline = true;
        _isAway = false;
        _cancelOfflineTimer();
      } catch (e) {
        print('Error setting user online: $e');
      }
    } else {
      print('User $_currentUserId is already online');
    }
  }

  Future<void> setUserOffline(String roomId) async {
    if (_currentUserId.isNotEmpty && (_isAway)) {
      final userRef = _firestore.collection('rooms').doc(roomId).collection('users').doc(_currentUserId);
      try {
        print('Setting user $_currentUserId to offline in room $roomId');
        await userRef.update({
          'isOnline': false,
          'isAway': false,
        });
        _isOnline = false;
        _isAway = false;
        _cancelOfflineTimer();  // 중복 타이머 방지
      } catch (e) {
        print('Error setting user offline: $e');
      }
    } else {
      print('User $_currentUserId is already offline');
    }
  }
  Future<void> setUserAway(String roomId) async {
    if (_currentUserId.isNotEmpty && !_isAway) {
      final userRef = _firestore.collection('rooms').doc(roomId).collection('users').doc(_currentUserId);
      try {
        print('Setting user $_currentUserId to away in room $roomId');
        await userRef.update({
          'isOnline': false,
          'isAway': true,
        });
        _isOnline = false;
        _isAway = true;
        _startOfflineTimer(roomId);
        print('User $_currentUserId is set to away in room $roomId');
      } catch (e) {
        print('Error setting user away: $e');
      }
    } else {
      print('User $_currentUserId is already away');
    }
  }

  void setupUserStatusListener(String roomId) {
    if (!isListenerSetup) {
      final userDocRef = _firestore.collection('rooms').doc(roomId).collection('users').doc(_currentUserId);
      userDocRef.snapshots().listen((snapshot) {
        final data = snapshot.data();
        if (data != null) {
          final isOnline = data['isOnline'] as bool?;
          final isAway = data['isAway'] as bool?;

          if (isOnline != null && isOnline != _isOnline) {
            _isOnline = isOnline;
          }
          if (isAway != null && isAway != _isAway) {
            _isAway = isAway;
          }

          if (!_isOnline && !_isAway) {
            _startOfflineTimer(roomId);
          } else {
            _cancelOfflineTimer();
          }
        }
      });
      isListenerSetup = true;
    }
  }
  void startBackgroundTimer(String roomId) {
    cancelBackgroundTimer();
    _backgroundTimer = Timer(Duration(seconds: 30), () {
      leaveRoom(roomId);
    });
  }

  void cancelBackgroundTimer() {
    if (_backgroundTimer != null) {
      _backgroundTimer!.cancel();
    }
  }
  void _startOfflineTimer(String roomId) {
    _cancelOfflineTimer();  // 타이머 중복 방지
    _offlineTimer = Timer(Duration(seconds: 30), () {
      setUserOffline(roomId);
    });
  }

  void _cancelOfflineTimer() {
    _offlineTimer?.cancel();
  }
  Future<void> leaveRoom(String roomId) async {
    if (_currentUserId.isNotEmpty) {
      final userRef = _firestore.collection('rooms').doc(roomId).collection('users').doc(_currentUserId);
      // Delete user from the room
      await userRef.delete();
      if (onLeaveRoomCallback != null) {
        onLeaveRoomCallback!();
      }
    }
  }

}