import '../models/room.dart';
import 'api_service.dart';

class MyQuestionSet {
  final String id;
  final String title;
  final String theme;
  final int questionCount;

  const MyQuestionSet({
    required this.id,
    required this.title,
    required this.theme,
    required this.questionCount,
  });

  factory MyQuestionSet.fromJson(Map<String, dynamic> j) => MyQuestionSet(
        id: j['id'] as String,
        title: j['title'] as String,
        theme: j['theme'] as String? ?? '',
        questionCount: j['question_count'] as int? ?? 0,
      );
}

class RoomService {
  RoomService._();
  static final instance = RoomService._();

  Future<List<Room>> listRooms() async {
    final data = await ApiService.instance.get('/rooms') as List;
    return data.map((j) => Room.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Room> getRoom(String id) async {
    final data = await ApiService.instance.get('/rooms/$id') as Map<String, dynamic>;
    return Room.fromJson(data);
  }

  Future<Room> getRoomByCode(String code) async {
    final data = await ApiService.instance
        .get('/rooms/by-code/${Uri.encodeComponent(code.toUpperCase())}') as Map<String, dynamic>;
    return Room.fromJson(data);
  }

  Future<Room> createRoom({
    required String name,
    bool isPublic = true,
    int maxPlayers = 30,
    int winScore = 20,
    int roundSeconds = 30,
    List<String> categories = const [],
    String? questionSetId,
  }) async {
    final data = await ApiService.instance.post('/rooms', {
      'name': name,
      'is_public': isPublic,
      'max_players': maxPlayers,
      'win_score': winScore,
      'round_seconds': roundSeconds,
      'categories': categories,
      if (questionSetId != null) 'question_set_id': questionSetId,
    });
    return Room.fromJson(data);
  }

  Future<List<String>> getCategories() async {
    final data = await ApiService.instance.get('/questions/categories') as List;
    return data.cast<String>();
  }

  Future<List<MyQuestionSet>> getMyQuestionSets() async {
    final data = await ApiService.instance.get('/question-sets/my') as List;
    return data
        .map((j) => MyQuestionSet.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
