/// 한 판의 결과 (서버 `GET /history/me` 의 items 한 줄).
class HistoryItem {
  final int id;
  final DateTime playedAt;
  final String roomName;
  final int score;
  final int rank;
  final int playerCount;
  final int winScore;
  final String? winnerNickname;
  final bool won;

  const HistoryItem({
    required this.id,
    required this.playedAt,
    required this.roomName,
    required this.score,
    required this.rank,
    required this.playerCount,
    required this.winScore,
    required this.winnerNickname,
    required this.won,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: j['id'] as int,
        playedAt: DateTime.parse(j['played_at'] as String),
        roomName: j['room_name'] as String? ?? '',
        score: j['score'] as int? ?? 0,
        rank: j['rank'] as int? ?? 0,
        playerCount: j['player_count'] as int? ?? 1,
        winScore: j['win_score'] as int? ?? 0,
        winnerNickname: j['winner_nickname'] as String?,
        won: j['won'] as bool? ?? false,
      );

  /// 1~3등은 메달, 나머지는 "4등".
  String get rankLabel => switch (rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '$rank등',
      };

  /// "10월 23일 오후 1:05" (기기 시간대).
  String get playedAtLabel => formatPlayedAt(playedAt.toLocal());
}

/// 내 전적 전체: 누적 숫자 + 최근 판 목록.
class HistorySummary {
  final int games;
  final int wins;
  final int totalScore;
  final List<HistoryItem> items;

  const HistorySummary({
    required this.games,
    required this.wins,
    required this.totalScore,
    required this.items,
  });

  factory HistorySummary.fromJson(Map<String, dynamic> j) => HistorySummary(
        games: j['games'] as int? ?? 0,
        wins: j['wins'] as int? ?? 0,
        totalScore: j['total_score'] as int? ?? 0,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// 서버가 준 목록이 전체보다 짧으면(오래된 판은 잘림) true.
  bool get isTruncated => items.length < games;
}

/// 로케일 초기화(intl) 없이 쓰는 한국어 날짜 표기.
String formatPlayedAt(DateTime t) {
  final period = t.hour < 12 ? '오전' : '오후';
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '${t.month}월 ${t.day}일 $period $hour12:$minute';
}
