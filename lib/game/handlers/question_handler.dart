import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/questions_provider.dart';

class QuestionHandler {
  late FirebaseFirestore _firestore;
  final QuestionsProvider _questionsProvider = QuestionsProvider();
  List<Map<String, dynamic>> questions = [];
  String? currentAnswer;

  QuestionHandler() {
    _firestore = FirebaseFirestore.instance;
  }

  Future<void> loadQuestions(String roomId) async {
    questions = await _questionsProvider.loadQuestions(roomId);
    currentAnswer = questions.isNotEmpty ? questions[0]['answer'] : null;
  }

  Future<void> updateCurrentQuestionIndex(String roomId, int newIndex) async {
    await _firestore.collection('rooms').doc(roomId).update({'currentQuestionIndex': newIndex});
  }
}