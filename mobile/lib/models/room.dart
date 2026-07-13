enum RoomStatus { waiting, playing, ended }

class Room {
  final String id;
  final String code;
  final String name;
  final String? ownerId;
  final RoomStatus status;
  final int playerCount;
  final int maxPlayers;
  final int winScore;
  final int roundSeconds;
  final List<String> categories;

  const Room({
    required this.id,
    required this.code,
    required this.name,
    this.ownerId,
    required this.status,
    required this.playerCount,
    required this.maxPlayers,
    required this.winScore,
    required this.roundSeconds,
    this.categories = const [],
  });

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        ownerId: j['owner_id'] as String?,
        status: _parseStatus(j['status'] as String?),
        playerCount: j['player_count'] as int? ?? 0,
        maxPlayers: j['max_players'] as int? ?? 8,
        winScore: j['win_score'] as int? ?? 20,
        roundSeconds: j['round_seconds'] as int? ?? 30,
        categories: List<String>.from(j['categories'] as List? ?? []),
      );

  static RoomStatus _parseStatus(String? s) {
    switch (s) {
      case 'playing':
        return RoomStatus.playing;
      case 'ended':
        return RoomStatus.ended;
      default:
        return RoomStatus.waiting;
    }
  }

  bool get isWaiting => status == RoomStatus.waiting;
  bool get isPlaying => status == RoomStatus.playing;
  bool get isEnded => status == RoomStatus.ended;

  // Legacy compat alias
  bool get isStarted => isPlaying;
}
