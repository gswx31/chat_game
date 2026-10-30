import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/ws_game_room.dart';

class PlayersSheet extends StatelessWidget {
  final List<PlayerInfo> players;
  final String? ownerId;
  final String meId;
  final bool canKick;
  final void Function(String userId) onKick;

  const PlayersSheet({
    required this.players,
    required this.ownerId,
    required this.meId,
    required this.canKick,
    required this.onKick,
    super.key,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final p = sorted[i];
              final isMe = p.userId == meId;
              final isOwner = p.userId == ownerId;
              const podium = ['🥇', '🥈', '🥉'];
              final medal = i < 3 ? podium[i] : '${i + 1}위';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    p.nickname.isNotEmpty ? p.nickname.substring(0, 1) : '?',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      p.nickname,
                      style: TextStyle(
                        fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                        color: isMe ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 4),
                      const Text('👑', style: TextStyle(fontSize: 14)),
                    ],
                  ],
                ),
                subtitle:
                    Text('${p.score}점', style: const TextStyle(fontSize: 12)),
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
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child:
                            const Text('강퇴', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
                tileColor:
                    i < 3 ? AppColors.primary.withValues(alpha: 0.04) : null,
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
