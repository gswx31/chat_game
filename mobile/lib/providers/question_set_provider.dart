import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question_set.dart';
import '../services/question_set_service.dart';

final myQSetsProvider = FutureProvider.autoDispose<List<QuestionSetBrief>>(
  (ref) => QuestionSetService.instance.getMyQuestionSets(),
);

final questionSetDetailProvider =
    FutureProvider.autoDispose.family<QuestionSetDetail, String>(
  (ref, id) => QuestionSetService.instance.getQuestionSet(id),
);
