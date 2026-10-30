import '../models/question_set.dart';
import 'api_service.dart';

class QuestionSetService {
  QuestionSetService._();
  static final instance = QuestionSetService._();

  Future<List<QuestionSetBrief>> getMyQuestionSets() async {
    final data = await ApiService.instance.get('/question-sets/my') as List;
    return data
        .map((j) => QuestionSetBrief.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<QuestionSetDetail> getQuestionSet(String id) async {
    final data = await ApiService.instance.get('/question-sets/$id')
        as Map<String, dynamic>;
    return QuestionSetDetail.fromJson(data);
  }

  Future<QuestionSetDetail> createQuestionSet({
    required String name,
    String? description,
    bool isPublic = true,
    List<String> tags = const [],
    List<Map<String, dynamic>> items = const [],
  }) async {
    final data = await ApiService.instance.post('/question-sets', {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
      'is_public': isPublic,
      'tags': tags,
      'items': items,
    });
    return QuestionSetDetail.fromJson(data);
  }

  Future<QuestionSetDetail> updateQuestionSet(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
    List<String>? tags,
  }) async {
    final data = await ApiService.instance.put('/question-sets/$id', {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isPublic != null) 'is_public': isPublic,
      if (tags != null) 'tags': tags,
    });
    return QuestionSetDetail.fromJson(data);
  }

  Future<void> deleteQuestionSet(String id) async {
    await ApiService.instance.delete('/question-sets/$id');
  }

  Future<QuestionSetItem> addQuestion(
    String setId, {
    required String prompt,
    required String answer,
    List<String> acceptedAnswers = const [],
    required String category,
    required int difficulty,
    String? hint,
  }) async {
    final data = await ApiService.instance.post(
      '/question-sets/$setId/questions',
      {
        'prompt': prompt,
        'answer': answer,
        'accepted_answers': acceptedAnswers,
        'category': category,
        'difficulty': difficulty,
        if (hint != null && hint.isNotEmpty) 'hint': hint,
      },
    );
    return QuestionSetItem.fromJson(data);
  }

  Future<QuestionSetItem> updateQuestion(
    String setId,
    String questionId, {
    String? prompt,
    String? answer,
    List<String>? acceptedAnswers,
    String? category,
    int? difficulty,
    String? hint,
  }) async {
    final data = await ApiService.instance.put(
      '/question-sets/$setId/questions/$questionId',
      {
        if (prompt != null) 'prompt': prompt,
        if (answer != null) 'answer': answer,
        if (acceptedAnswers != null) 'accepted_answers': acceptedAnswers,
        if (category != null) 'category': category,
        if (difficulty != null) 'difficulty': difficulty,
        if (hint != null) 'hint': hint,
      },
    );
    return QuestionSetItem.fromJson(data);
  }

  Future<void> deleteQuestion(String setId, String questionId) async {
    await ApiService.instance.delete(
        '/question-sets/$setId/questions/$questionId');
  }

  Future<QuestionSetDetail> getByCode(String code) async {
    final data = await ApiService.instance
        .get('/question-sets/by-code/${Uri.encodeComponent(code.toUpperCase())}')
        as Map<String, dynamic>;
    return QuestionSetDetail.fromJson(data);
  }

  Future<List<QuestionSetBrief>> browsePublicSets({
    String? query,
    String? tag,
    String sort = 'popular',
    int offset = 0,
    int limit = 30,
  }) async {
    final params = <String, String>{
      'sort': sort,
      'offset': '$offset',
      'limit': '$limit',
      if (query != null && query.isNotEmpty) 'q': query,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
    };
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final data = await ApiService.instance.get('/question-sets/browse?$qs') as List;
    return data
        .map((j) => QuestionSetBrief.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<QuestionSetDetail> cloneQuestionSet(String setId) async {
    final data = await ApiService.instance.post(
        '/question-sets/$setId/clone', {});
    return QuestionSetDetail.fromJson(data);
  }
}
