import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../core/router.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../services/ws_game_room.dart';

class LobbyScreen extends ConsumerWidget {
  final String roomId;
  const LobbyScreen({required this.roomId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final gs = ref.watch(wsGameRoomProvider(roomId));

    // Navigate to game screen when game starts
    ref.listen(wsGameRoomProvider(roomId), (prev, next) {
      if (next.status == 'playing' && prev?.status != 'playing' && context.mounted) {
        context.go(Routes.game(roomId));
      }
      if (next.status == 'ended' && context.mounted) {
        context.go(Routes.dashboard);
      }
    });

    final isOwner = gs.ownerId == uid;
    final players = gs.players;

    Future<void> leave() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('방을 나가시겠습니까?'),
          content: const Text('나가면 이 방의 게임에 참여할 수 없습니다.'),
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
      );
      if (ok == true && context.mounted) context.go(Routes.dashboard);
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => leave(),
      child: Scaffold(
        body: Column(
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: AppColors.primary_),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white),
                            onPressed: leave,
                          ),
                          Expanded(
                            child: Text(
                              roomId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // connection dot
                          Icon(
                            gs.connected ? Icons.circle : Icons.circle_outlined,
                            color: gs.connected
                                ? AppColors.accent
                                : Colors.white38,
                            size: 10,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _HeaderChip(label: '선 ${gs.winScore}점'),
                            _HeaderChip(label: '${gs.roundSeconds}초/라운드'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Player count bar
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.people_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '참가자 ${players.length}명',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  if (isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('방장',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),

            // Player grid
            Expanded(
              child: players.isEmpty
                  ? const Center(
                      child: Text('입장 중...',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: players.length,
                      itemBuilder: (_, i) {
                        final p = players[i];
                        final isMe = p.userId == uid;
                        final pIsOwner = p.userId == gs.ownerId;
                        return _PlayerCard(
                          player: p,
                          isMe: isMe,
                          isOwner: pIsOwner,
                        );
                      },
                    ),
            ),

            // Bottom action bar
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isOwner
                    ? GradientButton(
                        label: 'Start Game  🎮',
                        icon: Icons.play_arrow_rounded,
                        onPressed: gs.connected && players.length >= 1
                            ? () => ref
                                .read(wsGameRoomProvider(roomId).notifier)
                                .send({'type': 'start_game'})
                            : null,
                      )
                    : Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Text(
                          '방장이 게임을 시작하길 기다리는 중...',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerInfo player;
  final bool isMe;
  final bool isOwner;

  const _PlayerCard({
    required this.player,
    required this.isMe,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppColors.primary.withOpacity(0.3)
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: Text(
                  player.nickname.isNotEmpty
                      ? player.nickname.substring(0, 1)
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              if (isOwner)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: Text('👑', style: TextStyle(fontSize: 14)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              player.nickname,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                color: isMe ? AppColors.primary : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (isMe)
            Text('나', style: TextStyle(fontSize: 10, color: AppColors.primary.withOpacity(0.7))),
        ],
      ),
    );
  }
}
