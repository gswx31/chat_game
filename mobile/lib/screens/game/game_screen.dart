import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/router.dart';
import '../../game/widgets/message_list.dart';
import '../../game/widgets/mini_scoreboard.dart';
import '../../game/widgets/players_sheet.dart';
import '../../game/widgets/question_display.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../services/ws_game_room.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomId;
  const GameScreen({required this.roomId, super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _navigatingToResult = false;
  bool _autoScroll = true;
  int _betweenRoundCount = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    _autoScroll = pos.pixels >= pos.maxScrollExtent - 80;
  }

  void _startBetweenRoundCountdown() {
    _countdownTimer?.cancel();
    setState(() => _betweenRoundCount = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _betweenRoundCount--;
        if (_betweenRoundCount <= 0) {
          t.cancel();
          _betweenRoundCount = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    _autoScroll = true;
    ref.read(wsGameRoomProvider(widget.roomId).notifier).send({
      'type': 'chat',
      'text': text,
    });
  }

  void _voteSkip() {
    ref.read(wsGameRoomProvider(widget.roomId).notifier).send({'type': 'skip'});
  }

  void _kick(String userId) {
    if (!mounted) return;
    ConfirmDialog.show(
      context,
      title: '강퇴',
      content: '이 플레이어를 강퇴하시겠습니까?',
      confirmLabel: '강퇴',
    ).then((ok) {
      if (ok) {
        ref.read(wsGameRoomProvider(widget.roomId).notifier).send({
          'type': 'kick',
          'target_user_id': userId,
        });
      }
    });
  }

  Future<bool> _confirmLeave() => ConfirmDialog.show(
        context,
        title: '나가기',
        content: '정말 나가시겠습니까?',
        confirmLabel: '나가기',
      );

  void _scrollToBottom({bool force = false}) {
    if (!force && !_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTs(int ts) =>
      DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));

  String _answerMessage(RoundResult r) {
    if (r.reason == 'correct') return '🎉 ${r.winnerNickname ?? ''} 정답: ${r.answer}';
    if (r.reason == 'skipped') return '⏭️ 건너뜀 — 정답: ${r.answer}';
    return '⌛ 시간 초과 — 정답: ${r.answer}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final gs = ref.watch(wsGameRoomProvider(widget.roomId));

    // Navigate to result when game ends; auto-scroll on new messages; countdown between rounds
    ref.listen(wsGameRoomProvider(widget.roomId), (prev, next) {
      // Kicked / room gone / token expired — the socket won't come back.
      if (prev?.fatalError == null && next.fatalError != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.fatalError!)),
        );
        context.go(Routes.dashboard);
        return;
      }
      // Compare the newest message, not the count: the log keeps only the last 300 rows, so
      // once it is full its length never changes and a length check would stop scrolling.
      if (prev?.chat.lastOrNull?.id != next.chat.lastOrNull?.id) {
        _scrollToBottom();
      }
      // Between-round countdown. (There used to be a full-screen "정답!" overlay here; it
      // covered every player's screen for 2.2 s and swallowed taps while the next question
      // was already coming, so slower players lost the next round. The winner and the answer
      // are shown inside the question card instead, which never hides the question.)
      final prevEnded = prev?.round?.ended;
      final nextEnded = next.round?.ended;
      if (prevEnded == null && nextEnded != null && next.status == 'playing') {
        _startBetweenRoundCountdown();
      }
      if (prevEnded != null && nextEnded == null) {
        _countdownTimer?.cancel();
        setState(() => _betweenRoundCount = 0);
      }
      if (!_navigatingToResult &&
          next.status == 'ended' &&
          next.finalResult != null &&
          prev?.status != 'ended' &&
          mounted) {
        _navigatingToResult = true;
        final usersData = next.finalResult!.scores
            .map((p) => {
                  'uid': p.userId,
                  'displayName': p.nickname,
                  'photoURL': '',
                  'score': p.score,
                })
            .toList();
        context.go(Routes.result(widget.roomId), extra: usersData);
      }
    });

    final round = gs.round;
    final isOwner = gs.ownerId == uid;
    final skip = gs.skipState;
    final players = gs.players;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        final leave = await _confirmLeave();
        if (leave && context.mounted) context.go(Routes.dashboard);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                gs.roomName.isNotEmpty ? gs.roomName : widget.roomId,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              if (round != null)
                Text(
                  '라운드 ${round.round}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500),
                ),
            ],
          ),
          actions: [
            // Players
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.people_rounded),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => PlayersSheet(
                      players: players,
                      ownerId: gs.ownerId,
                      meId: uid,
                      canKick: isOwner,
                      onKick: _kick,
                    ),
                  ),
                ),
                if (players.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: AppColors.accent, shape: BoxShape.circle),
                      child: Text(
                        '${players.length}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            // Skip
            if (gs.status == 'playing' && round != null && round.ended == null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton.icon(
                  onPressed: _voteSkip,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text(
                    skip != null ? '스킵 ${skip.votes}/${skip.needed}' : '스킵',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
              ),
          ],
        ),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Column(
              children: [
            // Disconnect banner
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: gs.connected
                  ? const SizedBox.shrink()
                  : const Material(
                      color: AppColors.danger,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              '연결이 끊겼습니다. 재연결 중...',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Waiting state
            if (gs.status == 'waiting')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: AppColors.primary_,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const Text('⏳ 게임 시작 대기 중',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      '방장이 게임을 시작하면 바로 시작돼요 (${players.length}명 대기)',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                    if (isOwner) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: gs.connected
                            ? () => ref
                                .read(wsGameRoomProvider(widget.roomId)
                                    .notifier)
                                .send({'type': 'start_game'})
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('게임 시작'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Question panel
            if (gs.status == 'playing' && round != null)
              QuestionDisplay(
                question: round.prompt,
                deadlineTs: round.deadlineTs,
                totalSeconds: gs.roundSeconds,
                answerMessage: round.ended != null ? _answerMessage(round.ended!) : null,
                skipVotes: skip?.votes ?? 0,
                hint: round.hint,
              ),

            // Between-round countdown banner
            if (gs.status == 'playing' && round?.ended != null && _betweenRoundCount > 0)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '다음 문제까지 $_betweenRoundCount초...',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── 미니 스코어보드 ──────────────────────────────────────────────
            if (gs.status == 'playing' && players.length > 1)
              MiniScoreboard(
                players: players,
                winScore: gs.winScore,
                myUid: uid,
              ),

            // Chat
            Expanded(
              child: Container(
                color: AppColors.bg,
                child: MessageList(
                  messages: gs.chat.map((c) => c.toMap()).toList(),
                  currentUserId: uid,
                  scrollController: _scrollCtrl,
                  getSenderName: (id) => id,
                  getSenderPhotoUrl: (_) => '',
                  formatTimestamp: _formatTs,
                ),
              ),
            ),

            // Input
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                left: 12,
                right: 8,
                top: 8,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLength: 100,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: gs.connected
                            ? '정답 또는 메시지...'
                            : '연결 중...',
                        counterText: '',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: AppColors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onTap: () => _scrollToBottom(force: true),
                      onSubmitted: (_) => _sendMessage(),
                      enabled: gs.connected,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: gs.connected ? AppColors.primary : Colors.grey,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: gs.connected ? _sendMessage : null,
                      borderRadius: BorderRadius.circular(24),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.send_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
          ],
        ),
      ),
    );
  }
}

