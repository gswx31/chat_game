import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/api_config.dart';

// ── Value objects ─────────────────────────────────────────────────────────

class PlayerInfo {
  final String userId;
  final String nickname;
  final int score;
  final bool online;

  const PlayerInfo({
    required this.userId,
    required this.nickname,
    required this.score,
    this.online = true,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
        userId: j['user_id'] as String,
        nickname: j['nickname'] as String,
        score: j['score'] as int? ?? 0,
        online: j['online'] as bool? ?? true,
      );
}

class RoundResult {
  final String reason; // correct / timeout / skipped
  final String answer;
  final String? winnerNickname;

  const RoundResult({
    required this.reason,
    required this.answer,
    this.winnerNickname,
  });
}

class RoundInfo {
  final int round;
  final String prompt;
  final String category;
  final int difficulty;
  final double deadlineTs; // epoch seconds (double)
  final String? hint;
  final RoundResult? ended;

  const RoundInfo({
    required this.round,
    required this.prompt,
    required this.category,
    required this.difficulty,
    required this.deadlineTs,
    this.hint,
    this.ended,
  });

  RoundInfo copyWith({String? hint, RoundResult? ended}) => RoundInfo(
        round: round,
        prompt: prompt,
        category: category,
        difficulty: difficulty,
        deadlineTs: deadlineTs,
        hint: hint ?? this.hint,
        ended: ended ?? this.ended,
      );
}

class SkipInfo {
  final int votes;
  final int needed;
  const SkipInfo({required this.votes, required this.needed});
}

class GameResult {
  final List<PlayerInfo> scores;
  final String? winnerId;
  const GameResult({required this.scores, this.winnerId});
}

class ChatMsg {
  final int id;
  final String? userId;
  final String nickname;
  final String text;
  final bool isSystem;
  final int timestamp;

  const ChatMsg({
    required this.id,
    this.userId,
    required this.nickname,
    required this.text,
    this.isSystem = false,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'senderId': userId ?? '',
        'senderName': nickname,
        'senderPhotoURL': '',
        'text': text,
        'timestamp': timestamp,
        'isSystem': isSystem,
      };
}

// ── State ─────────────────────────────────────────────────────────────────

class WsGameRoomState {
  final bool connected;
  final String status; // waiting / playing / ended
  final String? ownerId;
  final int winScore;
  final int roundSeconds;
  final List<PlayerInfo> players;
  final RoundInfo? round;
  final List<ChatMsg> chat;
  final SkipInfo? skipState;
  final GameResult? finalResult;

  const WsGameRoomState({
    this.connected = false,
    this.status = 'waiting',
    this.ownerId,
    this.winScore = 20,
    this.roundSeconds = 30,
    this.players = const [],
    this.round,
    this.chat = const [],
    this.skipState,
    this.finalResult,
  });

  WsGameRoomState copyWith({
    bool? connected,
    String? status,
    String? ownerId,
    int? winScore,
    int? roundSeconds,
    List<PlayerInfo>? players,
    RoundInfo? round,
    bool clearRound = false,
    List<ChatMsg>? chat,
    SkipInfo? skipState,
    bool clearSkipState = false,
    GameResult? finalResult,
    bool clearFinalResult = false,
  }) =>
      WsGameRoomState(
        connected: connected ?? this.connected,
        status: status ?? this.status,
        ownerId: ownerId ?? this.ownerId,
        winScore: winScore ?? this.winScore,
        roundSeconds: roundSeconds ?? this.roundSeconds,
        players: players ?? this.players,
        round: clearRound ? null : (round ?? this.round),
        chat: chat ?? this.chat,
        skipState: clearSkipState ? null : (skipState ?? this.skipState),
        finalResult: clearFinalResult ? null : (finalResult ?? this.finalResult),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class WsGameRoom extends StateNotifier<WsGameRoomState> {
  WsGameRoom({required this.roomId, required this.token})
      : super(const WsGameRoomState()) {
    _connect();
  }

  final String roomId;
  final String token;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  int _chatSeq = 0;

  void _connect() {
    final uri = Uri.parse(
      '${ApiConfig.wsBase}/ws/rooms/$roomId?token=${Uri.encodeComponent(token)}',
    );
    try {
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (data) {
          final str = data is String ? data : utf8.decode(data as List<int>);
          if (!state.connected) state = state.copyWith(connected: true);
          try {
            _handle(json.decode(str) as Map<String, dynamic>);
          } catch (e) {
            debugPrint('WS parse error: $e');
          }
        },
        onDone: () {
          if (mounted) state = state.copyWith(connected: false);
        },
        onError: (e) {
          debugPrint('WS error: $e');
          if (mounted) state = state.copyWith(connected: false);
        },
      );
    } catch (e) {
      debugPrint('WS connect error: $e');
      state = state.copyWith(connected: false);
    }
  }

  void send(Map<String, dynamic> msg) {
    _channel?.sink.add(json.encode(msg));
  }

  // ── message handlers ──────────────────────────────────────────────────

  void _handle(Map<String, dynamic> m) {
    switch (m['type'] as String?) {
      case 'room_state':
        _onRoomState(m);
        break;
      case 'player_join':
        _addSystem('${m['nickname']} 님이 입장했습니다');
        break;
      case 'player_leave':
        _addSystem('${m['nickname']} 님이 나갔습니다');
        break;
      case 'chat':
        _addChat(
          text: m['text'] as String? ?? '',
          userId: m['user_id'] as String?,
          nickname: m['nickname'] as String? ?? '?',
        );
        break;
      case 'game_start':
        state = state.copyWith(
          status: 'playing',
          clearFinalResult: true,
          clearSkipState: true,
        );
        _addSystem('🎮 게임 시작!');
        break;
      case 'round_start':
        state = state.copyWith(
          round: RoundInfo(
            round: m['round'] as int? ?? 1,
            prompt: m['prompt'] as String? ?? '',
            category: m['category'] as String? ?? '',
            difficulty: m['difficulty'] as int? ?? 1,
            deadlineTs: (m['deadline_ts'] as num).toDouble(),
          ),
          clearSkipState: true,
        );
        break;
      case 'hint':
        if (state.round != null) {
          state = state.copyWith(
            round: state.round!.copyWith(hint: m['hint'] as String?),
          );
        }
        _addSystem('💡 힌트: ${m['hint']}');
        break;
      case 'skip_progress':
        state = state.copyWith(
          skipState: SkipInfo(
            votes: m['votes'] as int? ?? 0,
            needed: m['needed'] as int? ?? 1,
          ),
        );
        break;
      case 'correct':
        if (state.round != null) {
          state = state.copyWith(
            round: state.round!.copyWith(
              ended: RoundResult(
                reason: 'correct',
                answer: m['answer'] as String? ?? '',
                winnerNickname: m['nickname'] as String?,
              ),
            ),
          );
        }
        _addSystem('✅ ${m['nickname']} 님 정답! (${m['answer']})');
        break;
      case 'player_kicked':
        _addSystem('🚫 ${m['nickname']} 님이 강퇴되었습니다');
        break;
      case 'round_end':
        if (state.round != null) {
          state = state.copyWith(
            round: state.round!.copyWith(
              ended: RoundResult(
                reason: m['reason'] as String? ?? 'timeout',
                answer: m['answer'] as String? ?? '',
              ),
            ),
          );
        }
        final reason = m['reason'] as String?;
        if (reason == 'skipped') {
          _addSystem('⏭️ 스킵됨 (정답: ${m['answer']})');
        } else {
          _addSystem('⌛ 시간 초과 (정답: ${m['answer']})');
        }
        break;
      case 'score_update':
        final players = ((m['scores'] as List?) ?? [])
            .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
            .toList();
        state = state.copyWith(players: players);
        break;
      case 'game_over':
        final scores = ((m['scores'] as List?) ?? [])
            .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
            .toList();
        state = state.copyWith(
          status: 'ended',
          finalResult: GameResult(scores: scores, winnerId: m['winner_id'] as String?),
        );
        break;
      case 'error':
        _addSystem('⚠️ ${m['message']}');
        break;
    }
  }

  void _onRoomState(Map<String, dynamic> m) {
    final players = ((m['players'] as List?) ?? [])
        .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
        .toList();

    final st = m['status'] as String? ?? 'waiting';

    RoundInfo? round;
    if (m['current'] != null) {
      final c = m['current'] as Map<String, dynamic>;
      round = RoundInfo(
        round: c['round'] as int? ?? 1,
        prompt: c['prompt'] as String? ?? '',
        category: c['category'] as String? ?? '',
        difficulty: c['difficulty'] as int? ?? 1,
        deadlineTs: (c['deadline_ts'] as num).toDouble(),
      );
    }

    state = state.copyWith(
      status: st,
      ownerId: m['owner_id'] as String?,
      winScore: m['win_score'] as int? ?? 20,
      roundSeconds: m['round_seconds'] as int? ?? 30,
      players: players,
      round: round,
      clearRound: round == null,
      clearFinalResult: st == 'waiting',
      clearSkipState: st == 'waiting',
    );
  }

  void _addChat({required String text, String? userId, required String nickname}) {
    _chatSeq++;
    _appendMsg(ChatMsg(
      id: _chatSeq,
      userId: userId,
      nickname: nickname,
      text: text,
      isSystem: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _addSystem(String text) {
    _chatSeq++;
    _appendMsg(ChatMsg(
      id: _chatSeq,
      nickname: 'system',
      text: text,
      isSystem: true,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _appendMsg(ChatMsg msg) {
    final base = state.chat.length > 300
        ? state.chat.sublist(state.chat.length - 300)
        : state.chat;
    state = state.copyWith(chat: [...base, msg]);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
