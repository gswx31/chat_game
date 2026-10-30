// Backend-shaped payloads (copied from backend/app schemas + ws/engine messages)
// run through the app's parsers, so a field rename on either side fails here.
import 'package:chat_game/models/question_set.dart';
import 'package:chat_game/models/room.dart';
import 'package:chat_game/services/ws_game_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GET /rooms item (RoomListItem has no owner_id/round_seconds/categories)',
      () {
    final r = Room.fromJson({
      'id': 'abc',
      'code': 'K7M2QX',
      'name': '우리방',
      'is_public': true,
      'player_count': 3,
      'max_players': 30,
      'status': 'waiting',
      'win_score': 20,
      'created_at': '2026-10-22T06:00:00Z',
    });
    expect(r.isWaiting, isTrue);
    expect(r.ownerId, isNull);
    expect(r.roundSeconds, 30); // default
    expect(r.categories, isEmpty);
    expect(r.playerCount, 3);
  });

  test('GET /rooms/{id} (RoomDetail)', () {
    final r = Room.fromJson({
      'id': 'abc',
      'code': 'K7M2QX',
      'name': '우리방',
      'is_public': false,
      'owner_id': 'u1',
      'player_count': 1,
      'max_players': 8,
      'status': 'playing',
      'win_score': 10,
      'round_seconds': 45,
      'categories': ['역사', '과학'],
      'difficulty_min': 1,
      'difficulty_max': 5,
      'question_set_id': null,
      'created_at': '2026-10-22T06:00:00Z',
    });
    expect(r.isPlaying, isTrue);
    expect(r.ownerId, 'u1');
    expect(r.categories, ['역사', '과학']);
    expect(r.roundSeconds, 45);
  });

  test('QuestionSetOut with items', () {
    final d = QuestionSetDetail.fromJson({
      'id': 's1',
      'code': 'ABCD',
      'name': '내 맵',
      'description': null,
      'creator_id': 'u1',
      'creator_nickname': '상빈',
      'is_public': true,
      'tags': ['역사'],
      'play_count': 2,
      'item_count': 1,
      'created_at': '2026-10-22T06:00:00Z',
      'updated_at': '2026-10-22T06:00:00Z',
      'items': [
        {
          'id': 'q1',
          'set_id': 's1',
          'prompt': '한글을 만든 왕은?',
          'answer': '세종대왕',
          'accepted_answers': ['세종'],
          'category': '역사',
          'difficulty': 1,
          'hint': null,
          'order': 0,
        }
      ],
    });
    expect(d.items.single.acceptedAnswers, ['세종']);
    expect(d.items.single.hint, isNull);
    expect(d.itemCount, 1);
  });

  test('WS score_update / room_state player rows', () {
    final p = PlayerInfo.fromJson({
      'user_id': 'u1',
      'nickname': 'Guest_ab12cd34',
      'score': 3,
      'online': false,
    });
    expect(p.online, isFalse);
    expect(p.score, 3);

    // "(나감)" rows come from the engine for players who left mid-game.
    final gone = PlayerInfo.fromJson(
        {'user_id': 'u2', 'nickname': '(나감)', 'score': 1, 'online': false});
    expect(gone.nickname, '(나감)');
  });
}
