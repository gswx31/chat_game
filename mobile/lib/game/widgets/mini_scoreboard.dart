import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/ws_game_room.dart';

class MiniScoreboard extends StatelessWidget {
  final List<PlayerInfo> players;
  final int winScore;
  final String myUid;

  const MiniScoreboard({
    required this.players,
    required this.winScore,
    required this.myUid,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = players[i];
          final isMe = p.userId == myUid;
          final progress = (p.score / winScore).clamp(0.0, 1.0);
          final isLeading = i == 0 && p.score > 0;
          return _MiniCard(
            player: p,
            isMe: isMe,
            isLeading: isLeading,
            progress: progress,
            winScore: winScore,
          );
        },
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final PlayerInfo player;
  final bool isMe;
  final bool isLeading;
  final double progress;
  final int winScore;

  const _MiniCard({
    required this.player,
    required this.isMe,
    required this.isLeading,
    required this.progress,
    required this.winScore,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isLeading
        ? AppColors.accent
        : isMe
            ? AppColors.primary
            : AppColors.textSecondary;

    return Container(
      width: 88,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withValues(alpha: 0.07)
            : isLeading
                ? AppColors.accent.withValues(alpha: 0.06)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.25)
              : isLeading
                  ? AppColors.accent.withValues(alpha: 0.25)
                  : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: baseColor.withValues(alpha: 0.18),
                child: Text(
                  player.nickname.isNotEmpty ? player.nickname[0] : '?',
                  style: TextStyle(
                      color: baseColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  player.nickname,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                    color: baseColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLeading) const Text('👑', style: TextStyle(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${player.score}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: baseColor),
              ),
              Text(
                '/$winScore',
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                progress >= 0.8 ? AppColors.danger : baseColor,
              ),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
