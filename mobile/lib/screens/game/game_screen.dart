import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/router.dart';
import '../../game/widgets/message_list.dart';
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

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
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
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('강퇴'),
        content: const Text('이 플레이어를 강퇴하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('강퇴'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true) {
        ref.read(wsGameRoomProvider(widget.roomId).notifier).send({
          'type': 'kick',
          'target_user_id': userId,
        });
      }
    });
  }

  Future<bool> _confirmLeave() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('나가기'),
            content: const Text('정말 나가시겠습니까?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger),
                child: const Text('나가기'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
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

    // Navigate to result when game ends
    ref.listen(wsGameRoomProvider(widget.roomId), (prev, next) {
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

    _scrollToBottom();

    final round = gs.round;
    final isOwner = gs.ownerId == uid;
    final skip = gs.skipState;
    final players = gs.players;

    return PopScope(
      canPop: false,
      onPopInvoked: (_) async {
        final leave = await _confirmLeave();
        if (leave && mounted) context.go(Routes.dashboard);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text(widget.roomId,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          actions: [
            // Connection indicator
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                gs.connected ? Icons.circle : Icons.circle_outlined,
                color: gs.connected ? AppColors.accent : AppColors.danger,
                size: 10,
              ),
            ),
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
                    builder: (_) => _PlayersSheet(
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
        body: Column(
          children: [
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
                          TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
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
                      onTap: _scrollToBottom,
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
      ),
    );
  }
}

// ── Players bottom sheet ───────────────────────────────────────────────────

class _PlayersSheet extends StatelessWidget {
  final List<PlayerInfo> players;
  final String? ownerId;
  final String meId;
  final bool canKick;
  final void Function(String userId) onKick;

  const _PlayersSheet({
    required this.players,
    required this.ownerId,
    required this.meId,
    required this.canKick,
    required this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '참가자 순위',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final p = sorted[i];
              final isMe = p.userId == meId;
              final isOwner = p.userId == ownerId;
              final medal = i == 0
                  ? '🥇'
                  : i == 1
                      ? '🥈'
                      : i == 2
                          ? '🥉'
                          : '${i + 1}위';
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      AppColors.primary.withOpacity(0.15),
                  child: Text(
                    p.nickname.isNotEmpty
                        ? p.nickname.substring(0, 1)
                        : '?',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      p.nickname,
                      style: TextStyle(
                        fontWeight: isMe
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isMe
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 4),
                      const Text('👑', style: TextStyle(fontSize: 14)),
                    ],
                  ],
                ),
                subtitle: Text('${p.score}점',
                    style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(medal, style: const TextStyle(fontSize: 18)),
                    if (canKick && !isMe && !isOwner) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onKick(p.userId);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text('강퇴',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
                tileColor: i < 3
                    ? AppColors.primary.withOpacity(0.04)
                    : null,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              );
            },
          ),
        ),
      ],
    );
  }
}
