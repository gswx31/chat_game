import 'package:chat_game/models/game_history.dart';
import 'package:chat_game/providers/history_provider.dart';
import 'package:chat_game/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryItem _item(int id, String room, int rank, int score, {bool won = false}) =>
    HistoryItem(
      id: id,
      playedAt: DateTime(2026, 10, 23, 13, 5),
      roomName: room,
      score: score,
      rank: rank,
      playerCount: 3,
      winScore: 20,
      winnerNickname: '하늘',
      won: won,
    );

Widget _app(Future<HistorySummary> Function() load) => ProviderScope(
      overrides: [myHistoryProvider.overrideWith((ref) => load())],
      child: const MaterialApp(home: HistoryScreen()),
    );

void main() {
  testWidgets('shows totals and one tile per game', (tester) async {
    await tester.pumpWidget(_app(() async => HistorySummary(
          games: 12,
          wins: 3,
          totalScore: 140,
          items: [
            _item(2, '금요일 퀴즈방', 1, 20, won: true),
            _item(1, '점심 내기', 2, 14),
          ],
        )));
    await tester.pumpAndSettle();

    expect(find.text('12판'), findsOneWidget);
    expect(find.text('3회'), findsOneWidget);
    expect(find.text('140점'), findsOneWidget);
    expect(find.text('금요일 퀴즈방'), findsOneWidget);
    expect(find.text('점심 내기'), findsOneWidget);
    // '우승' = the summary label + exactly one badge (only the won game gets it)
    expect(find.text('우승'), findsNWidgets(2));
    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('🥈'), findsOneWidget);
    expect(find.textContaining('1등 하늘'), findsOneWidget); // shown for the lost game only
  });

  testWidgets('empty history explains how to fill it', (tester) async {
    await tester.pumpWidget(_app(() async => const HistorySummary(
        games: 0, wins: 0, totalScore: 0, items: [])));
    await tester.pumpAndSettle();

    expect(find.text('아직 끝난 게임이 없어요'), findsOneWidget);
    expect(find.textContaining('점수를 낸 게임만'), findsOneWidget);
  });

  testWidgets('a failed load shows a retry button that reloads', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(() async {
      calls++;
      if (calls == 1) throw Exception('서버에 연결할 수 없어요');
      return const HistorySummary(games: 0, wins: 0, totalScore: 0, items: []);
    }));
    await tester.pumpAndSettle();

    expect(find.text('불러오기 실패'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('아직 끝난 게임이 없어요'), findsOneWidget);
  });

  testWidgets('says when only the latest games are shown', (tester) async {
    await tester.pumpWidget(_app(() async => HistorySummary(
          games: 250,
          wins: 10,
          totalScore: 999,
          items: [_item(1, '방', 1, 5, won: true)],
        )));
    await tester.pumpAndSettle();
    expect(find.text('최근 1판만 보여드려요.'), findsOneWidget);
  });
}
