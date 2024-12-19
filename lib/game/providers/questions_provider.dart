import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_game/questions/level1_questions.dart';
import 'package:chat_game/questions/level2_questions.dart';
import 'package:chat_game/questions/level3_questions.dart';
import 'package:chat_game/questions/level4_questions.dart';
import 'package:chat_game/questions/level5_questions.dart';
import 'package:chat_game/questions/level6_questions.dart';

class QuestionsProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initializeQuestions(String roomId, List<String> selectedGenres, String difficulty) async {
    List<Map<String, dynamic>> questions = [];

    // Fetch questions based on difficulty
    if (difficulty == '쉬움') {
      questions.addAll(level1Questions);
      questions.addAll(level2Questions);
    } else if (difficulty == '보통') {
      questions.addAll(level3Questions);
      questions.addAll(level4Questions);
    } else if (difficulty == '어려움') {
      questions.addAll(level5Questions);
      questions.addAll(level6Questions);
    }

    // Filter questions based on genres
    if (!selectedGenres.contains('전체')) {
      questions = questions.where((question) => selectedGenres.contains(question['genre'])).toList();
    }

    questions.shuffle();

    await _firestore.collection('rooms').doc(roomId).set({
      'questions': questions,
      'currentQuestionIndex': 0,
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> loadQuestions(String roomId) async {
    DocumentSnapshot roomSnapshot = await _firestore.collection('rooms').doc(roomId).get();
    if (roomSnapshot.exists) {
      List<dynamic> loadedQuestions = roomSnapshot['questions'] ?? [];
      return List<Map<String, dynamic>>.from(loadedQuestions);
    }
    return [];
  }
}
