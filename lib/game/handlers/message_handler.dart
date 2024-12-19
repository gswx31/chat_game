import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

class MessageHandler {
  late FirebaseAuth _auth;
  late FirebaseDatabase _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late String _currentUserId;

  MessageHandler() {
    _auth = FirebaseAuth.instance;
    _database = FirebaseDatabase.instance;
    _currentUserId = _auth.currentUser?.uid ?? '';
  }

  Future<void> sendMessage(String roomId, String messageText) async {
    if (messageText.trim().isEmpty) return;

    // 사용자 정보를 포함한 메시지 데이터
    final userDoc = await _firestore.collection('members').doc(_currentUserId).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    // 메시지에 사용자 정보를 복사하여 저장
    final message = {
      'text': messageText.trim(),
      'senderId': _currentUserId,
      'senderName': userData['displayName'] ?? 'Unknown', // 사용자 이름 저장
      'senderPhotoUrl': userData['photoURL'] ?? '', // 사용자 프로필 사진 URL 저장
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    print('Preparing to send message: $message');
    print('Room ID: $roomId');

    try {
      // 메시지를 Realtime Database에 저장
      await _database.ref('rooms/$roomId/messages').push().set(message);
      print('Message successfully sent to Realtime Database');
    } catch (e) {
      print('Failed to send message to Realtime Database: $e');
    }

    try {
      // 메시지를 Firestore에 저장
      await _firestore.collection('rooms').doc(roomId).collection('messages').add(message);
      print('Message successfully sent to Firestore');
    } catch (e) {
      print('Failed to send message to Firestore: $e');
    }
  }


  Future<void> playCorrectAnswerSound() async {
    await _audioPlayer.setSource(AssetSource('sounds/ding.mp3'));
    _audioPlayer.resume();
  }
}
