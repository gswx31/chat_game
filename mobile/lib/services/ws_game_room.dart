import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/api_config.dart';
import 'api_service.dart';
import 'auth_service.dart';

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

/// Close codes the server uses to say "don't bother retrying".
/// Mirrors `backend/app/ws/router.py`.
const _kFatalCloseReasons = <int, String>{
  4401: '로그인이 만료됐는데 다시 로그인하지 못했어요. 인터넷을 확인하고 다시 들어와 주세요',
  4403: '방장에 의해 강퇴되었습니다',
  4404: '방이 사라졌어요',
  4413: '방 정원이 가득 찼어요',
  4423: '이미 시작된 게임이라 입장할 수 없어요',
};

class WsGameRoomState {
  final bool connected;

  /// Non-null once the server refused us for a reason retrying can't fix.
  /// Reconnection stops and the UI shows this instead of a spinner.
  final String? fatalError;
  final String status; // waiting / playing / ended
  final String? ownerId;
  final int winScore;
  final int roundSeconds;
  final String roomName;
  final String roomCode;
  final List<PlayerInfo> players;
  final RoundInfo? round;
  final List<ChatMsg> chat;
  final SkipInfo? skipState;
  final GameResult? finalResult;

  const WsGameRoomState({
    this.connected = false,
    this.fatalError,
    this.status = 'waiting',
    this.ownerId,
    this.winScore = 20,
    this.roundSeconds = 30,
    this.roomName = '',
    this.roomCode = '',
    this.players = const [],
    this.round,
    this.chat = const [],
    this.skipState,
    this.finalResult,
  });

  WsGameRoomState copyWith({
    bool? connected,
    String? fatalError,
    String? status,
    String? ownerId,
    int? winScore,
    int? roundSeconds,
    String? roomName,
    String? roomCode,
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
        fatalError: fatalError ?? this.fatalError,
        status: status ?? this.status,
        ownerId: ownerId ?? this.ownerId,
        winScore: winScore ?? this.winScore,
        roundSeconds: roundSeconds ?? this.roundSeconds,
        roomName: roomName ?? this.roomName,
        roomCode: roomCode ?? this.roomCode,
        players: players ?? this.players,
        round: clearRound ? null : (round ?? this.round),
        chat: chat ?? this.chat,
        skipState: clearSkipState ? null : (skipState ?? this.skipState),
        finalResult: clearFinalResult ? null : (finalResult ?? this.finalResult),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class WsGameRoom extends StateNotifier<WsGameRoomState> with WidgetsBindingObserver {
  WsGameRoom({required this.roomId, required this.token})
      : super(const WsGameRoomState()) {
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !this.state.connected &&
        !_disposed &&
        !_fatal) {
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      _sub?.cancel();
      _channel?.sink.close();
      _connect();
    }
  }

  final String roomId;
  final String token;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  /// Server told us retrying is pointless (kicked, room gone, bad token).
  /// Distinct from [_disposed] so the screen stays alive to show why.
  bool _fatal = false;

  /// 4401(토큰 만료) 때 재로그인을 이미 한 번 시도했는지. 메시지가 정상 수신되면
  /// 다시 false 로 돌아가서, 나중에 또 만료돼도 한 번은 자동 복구된다.
  bool _reauthTried = false;
  int _chatSeq = 0;

  void _connect() {
    if (_disposed) return;
    // 재연결은 생성 시점의 토큰이 아니라 "지금" 토큰으로 — 중간에 재로그인됐을 수 있다.
    final currentToken = ApiService.instance.token ?? token;
    final uri = Uri.parse(
      '${ApiConfig.wsBase}/ws/rooms/$roomId?token=${Uri.encodeComponent(currentToken)}',
    );
    try {
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (data) {
          final str = data is String ? data : utf8.decode(data as List<int>);
          _reconnectAttempts = 0; // reset on successful message
          _reauthTried = false;
          if (!state.connected) state = state.copyWith(connected: true);
          try {
            _handle(json.decode(str) as Map<String, dynamic>);
          } catch (e) {
            debugPrint('WS parse error: $e');
          }
        },
        onDone: () {
          if (!mounted) return;
          // Check *why* the socket closed. Blindly reconnecting meant a kicked
          // player walked straight back in one second later, and an expired
          // token span forever at the 30s ceiling.
          final code = _channel?.closeCode ?? -1;
          if (code == 4401 && !_reauthTried) {
            // 토큰 만료 — 같은 기기 ID 로 재로그인해서 한 번만 다시 붙어본다.
            _reauthTried = true;
            _reconnectTimer?.cancel();
            state = state.copyWith(connected: false);
            AuthService.instance.signInAsGuest().then((ok) {
              if (_disposed || !mounted) return;
              if (ok) {
                _connect();
              } else {
                _fatal = true;
                state = state.copyWith(
                  fatalError: _kFatalCloseReasons[4401],
                );
                _addSystem('🚫 ${_kFatalCloseReasons[4401]}');
              }
            });
            return;
          }
          final reason = _kFatalCloseReasons[code];
          if (reason != null) {
            _fatal = true;
            _reconnectTimer?.cancel();
            state = state.copyWith(connected: false, fatalError: reason);
            _addSystem('🚫 $reason');
            return;
          }
          state = state.copyWith(connected: false);
          _scheduleReconnect();
        },
        onError: (e) {
          debugPrint('WS error: $e');
          if (!mounted) return;
          state = state.copyWith(connected: false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('WS connect error: $e');
      if (mounted) {
        state = state.copyWith(connected: false);
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _fatal) return;
    final delay = Duration(seconds: min(1 << _reconnectAttempts, 30));
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_disposed) {
        _sub?.cancel();
        _channel?.sink.close();
        _connect();
      }
    });
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
        final joinUid = m['user_id'] as String?;
        final joinNick = m['nickname'] as String? ?? '?';
        if (joinUid != null && !state.players.any((p) => p.userId == joinUid)) {
          state = state.copyWith(
            players: [
              ...state.players,
              PlayerInfo(userId: joinUid, nickname: joinNick, score: 0),
            ],
          );
        }
        _addSystem('$joinNick 님이 입장했습니다');
        break;
      case 'player_leave':
        final leaveUid = m['user_id'] as String?;
        final leaveNick = m['nickname'] as String? ?? '?';
        if (leaveUid != null) {
          state = state.copyWith(
            players: state.players.where((p) => p.userId != leaveUid).toList(),
          );
        }
        _addSystem('$leaveNick 님이 나갔습니다');
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
        final kickedUid = m['user_id'] as String?;
        final kickedNick = m['nickname'] as String? ?? '?';
        if (kickedUid != null) {
          state = state.copyWith(
            players: state.players.where((p) => p.userId != kickedUid).toList(),
          );
        }
        _addSystem('🚫 $kickedNick 님이 강퇴되었습니다');
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
        hint: c['hint'] as String?,
      );
    }

    state = state.copyWith(
      status: st,
      ownerId: m['owner_id'] as String?,
      winScore: m['win_score'] as int? ?? 20,
      roundSeconds: m['round_seconds'] as int? ?? 30,
      roomName: m['room_name'] as String? ?? state.roomName,
      roomCode: m['room_code'] as String? ?? state.roomCode,
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
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
