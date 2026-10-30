import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_history.dart';
import '../services/history_service.dart';

/// 화면을 열 때마다 새로 불러온다(autoDispose) — 방금 끝난 판이 바로 보이게.
final myHistoryProvider = FutureProvider.autoDispose<HistorySummary>(
  (ref) => HistoryService.instance.fetchMine(),
);
