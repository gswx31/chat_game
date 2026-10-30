import 'package:chat_game/models/game_history.dart';
import 'package:flutter_test/flutter_test.dart';

// 서버(GET /history/me)가 실제로 돌려주는 모양 그대로.
const _serverJson = {
  'games': 2,
  'wins': 1,
  'total_score': 4,
  'items': [
    {
      'id': 7,
      'played_at': '2026-10-23T04:05:00.123456Z',
      'room_name': '전적방',
      'score': 1,
      'rank': 2,
      'player_count': 3,
      'win_score': 3,
      'winner_nickname': '하늘',
      'won': false,
    },
    {
      'id': 6,
      'played_at': '2026-10-23T03:50:00Z',
      'room_name': '금요일 퀴즈방',
      'score': 3,
      'rank': 1,
      'player_count': 3,
      'win_score': 3,
      'winner_nickname': null,
      'won': true,
    },
  ],
};

void main() {
  group('HistorySummary.fromJson', () {
    test('parses the real server response', () {
      final s = HistorySummary.fromJson(_serverJson);
      expect(s.games, 2);
      expect(s.wins, 1);
      expect(s.totalScore, 4);
      expect(s.items, hasLength(2));

      final first = s.items.first;
      expect(first.id, 7);
      expect(first.roomName, '전적방');
      expect(first.rank, 2);
      expect(first.won, isFalse);
      expect(first.winnerNickname, '하늘');
      expect(first.playedAt.isUtc, isTrue);

      expect(s.items.last.winnerNickname, isNull);
      expect(s.items.last.won, isTrue);
    });

    test('an empty history parses', () {
      final s = HistorySummary.fromJson(
          {'games': 0, 'wins': 0, 'total_score': 0, 'items': <dynamic>[]});
      expect(s.items, isEmpty);
      expect(s.isTruncated, isFalse);
    });

    test('isTruncated when the server list is shorter than the total', () {
      final s = HistorySummary.fromJson({..._serverJson, 'games': 250});
      expect(s.isTruncated, isTrue);
    });
  });

  group('labels', () {
    HistoryItem withRank(int rank) => HistoryItem.fromJson({
          ...(_serverJson['items'] as List).first as Map<String, dynamic>,
          'rank': rank,
        });

    test('top three get medals, the rest a number', () {
      expect(withRank(1).rankLabel, '🥇');
      expect(withRank(2).rankLabel, '🥈');
      expect(withRank(3).rankLabel, '🥉');
      expect(withRank(4).rankLabel, '4등');
      expect(withRank(12).rankLabel, '12등');
    });

    test('formatPlayedAt: Korean 12-hour clock', () {
      expect(formatPlayedAt(DateTime(2026, 10, 23, 13, 5)), '10월 23일 오후 1:05');
      expect(formatPlayedAt(DateTime(2026, 1, 2, 0, 0)), '1월 2일 오전 12:00');
      expect(formatPlayedAt(DateTime(2026, 1, 2, 12, 30)), '1월 2일 오후 12:30');
      expect(formatPlayedAt(DateTime(2026, 12, 31, 9, 7)), '12월 31일 오전 9:07');
    });
  });
}
