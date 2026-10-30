import 'package:flutter/material.dart';

// Map themes and question categories are the room categories (categoriesProvider).

const kDifficultyLabels = {1: '하', 2: '중', 3: '상'};

Color difficultyColor(int difficulty) {
  switch (difficulty) {
    case 1:
      return const Color(0xFF00C896); // accent
    case 3:
      return const Color(0xFFEF4444); // danger
    default:
      return const Color(0xFFF59E0B); // warning
  }
}

class QuestionSetItem {
  final String? id;
  final String? setId;
  final String prompt;
  final String answer;
  final List<String> acceptedAnswers;
  final String category;
  final int difficulty;
  final String? hint;
  final int order;

  const QuestionSetItem({
    this.id,
    this.setId,
    required this.prompt,
    required this.answer,
    required this.acceptedAnswers,
    required this.category,
    required this.difficulty,
    this.hint,
    this.order = 0,
  });

  factory QuestionSetItem.fromJson(Map<String, dynamic> j) => QuestionSetItem(
        id: j['id'] as String?,
        setId: j['set_id'] as String?,
        prompt: j['prompt'] as String,
        answer: j['answer'] as String,
        acceptedAnswers: (j['accepted_answers'] as List?)?.cast<String>() ?? [],
        category: j['category'] as String,
        difficulty: j['difficulty'] as int? ?? 2,
        hint: j['hint'] as String?,
        order: j['order'] as int? ?? 0,
      );

  Map<String, dynamic> toCreateMap() => {
        'prompt': prompt,
        'answer': answer,
        'accepted_answers': acceptedAnswers,
        'category': category,
        'difficulty': difficulty,
        if (hint != null && hint!.isNotEmpty) 'hint': hint,
      };
}

class QuestionSetBrief {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String creatorId;
  final String creatorNickname;
  final bool isPublic;
  final List<String> tags;
  final int playCount;
  final int itemCount;

  const QuestionSetBrief({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.creatorId,
    required this.creatorNickname,
    required this.isPublic,
    required this.tags,
    required this.playCount,
    required this.itemCount,
  });

  factory QuestionSetBrief.fromJson(Map<String, dynamic> j) => QuestionSetBrief(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        creatorId: j['creator_id'] as String,
        creatorNickname: j['creator_nickname'] as String,
        isPublic: j['is_public'] as bool? ?? true,
        tags: (j['tags'] as List?)?.cast<String>() ?? [],
        playCount: j['play_count'] as int? ?? 0,
        itemCount: j['item_count'] as int? ?? 0,
      );
}

class QuestionSetDetail extends QuestionSetBrief {
  final List<QuestionSetItem> items;

  const QuestionSetDetail({
    required super.id,
    required super.code,
    required super.name,
    super.description,
    required super.creatorId,
    required super.creatorNickname,
    required super.isPublic,
    required super.tags,
    required super.playCount,
    required super.itemCount,
    required this.items,
  });

  factory QuestionSetDetail.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List?)
            ?.map((e) => QuestionSetItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return QuestionSetDetail(
      id: j['id'] as String,
      code: j['code'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      creatorId: j['creator_id'] as String,
      creatorNickname: j['creator_nickname'] as String,
      isPublic: j['is_public'] as bool? ?? true,
      tags: (j['tags'] as List?)?.cast<String>() ?? [],
      playCount: j['play_count'] as int? ?? 0,
      itemCount: j['item_count'] as int? ?? items.length,
      items: items,
    );
  }
}
