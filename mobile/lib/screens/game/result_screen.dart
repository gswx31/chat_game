import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_theme.dart';
import '../../core/router.dart';

class ResultScreen extends StatefulWidget {
  final String roomId;
  final List<Map<String, dynamic>> users;

  const ResultScreen(
      {required this.roomId, required this.users, super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final List<Map<String, dynamic>> _sorted;
  late final AnimationController _anim;
  final List<bool> _visible = [];

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.users]
      ..sort((a, b) =>
          ((b['score'] as int? ?? 0).compareTo(a['score'] as int? ?? 0)));

    _visible.addAll(List.filled(_sorted.length, false));

    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim.forward();

    // Stagger list items
    for (int i = 0; i < _sorted.length; i++) {
      Future.delayed(Duration(milliseconds: 400 + i * 120), () {
        if (mounted) setState(() => _visible[i] = true);
      });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _sorted.take(3).toList();
    final rest = _sorted.skip(3).toList();

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => context.go(Routes.dashboard),
      child: Scaffold(
        body: Stack(
          children: [
            // Background gradient
            const DecoratedBox(
              decoration:
                  BoxDecoration(gradient: AppColors.primary_),
              child: SizedBox.expand(),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Header
                  FadeTransition(
                    opacity: _anim,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Text('🎉',
                              style: TextStyle(fontSize: 44)),
                          SizedBox(height: 8),
                          Text(
                            '게임 종료!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '최종 순위',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Podium (top 3)
                  if (top3.isNotEmpty)
                    FadeTransition(
                      opacity: _anim,
                      child: _Podium(top3: top3),
                    ),

                  const SizedBox(height: 8),

                  // Rest of rankings
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 16, bottom: 8),
                            child: Text('전체 순위',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.textPrimary)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: _sorted.length + 1,
                              itemBuilder: (_, i) {
                                if (i == _sorted.length) {
                                  // Bottom button
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: GradientButton(
                                      label: '메인으로 돌아가기',
                                      icon: Icons.home_rounded,
                                      onPressed: () =>
                                          context.go(Routes.dashboard),
                                    ),
                                  );
                                }
                                final user = _sorted[i];
                                return AnimatedOpacity(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  opacity: _visible[i] ? 1 : 0,
                                  child: AnimatedSlide(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    offset: _visible[i]
                                        ? Offset.zero
                                        : const Offset(0.1, 0),
                                    child: _RankRow(
                                        rank: i + 1, user: user),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> top3;
  const _Podium({required this.top3});

  @override
  Widget build(BuildContext context) {
    // Podium order: 2nd, 1st, 3rd
    final order = <int>[];
    if (top3.length == 1) {
      order.add(0);
    } else if (top3.length == 2) {
      order.addAll([1, 0]);
    } else {
      order.addAll([1, 0, 2]);
    }

    final heights = [80.0, 110.0, 60.0];
    final colors = [AppColors.silver, AppColors.gold, AppColors.bronze];
    final medals = ['🥈', '🥇', '🥉'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: order.map((rank) {
          final user = top3[rank];
          final photoURL = user['photoURL'] as String? ?? '';
          final name = user['displayName'] as String? ?? '';
          final score = user['score'] as int? ?? 0;
          final podiumIdx = order.indexOf(rank);

          return Expanded(
            child: Column(
              children: [
                Text(medals[podiumIdx], style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                CircleAvatar(
                  radius: rank == 0 ? 30 : 24,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  backgroundImage: photoURL.isNotEmpty
                      ? NetworkImage(photoURL) as ImageProvider
                      : const AssetImage(
                          'assets/images/default_profile_image.png'),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                Text(
                  '$score점',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11),
                ),
                const SizedBox(height: 6),
                Container(
                  height: heights[podiumIdx],
                  decoration: BoxDecoration(
                    color: colors[podiumIdx].withOpacity(0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors[podiumIdx].withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${rank + 1}',
                    style: TextStyle(
                      color: rank == 0
                          ? Colors.white
                          : Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w900,
                      fontSize: rank == 0 ? 22 : 18,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> user;

  const _RankRow({required this.rank, required this.user});

  @override
  Widget build(BuildContext context) {
    final photoURL = user['photoURL'] as String? ?? '';
    final name = user['displayName'] as String? ?? 'Unknown';
    final score = user['score'] as int? ?? 0;
    final isTop3 = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTop3
            ? AppColors.primary.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: isTop3
            ? Border.all(color: AppColors.primary.withOpacity(0.15))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              rank <= 3
                  ? ['🥇', '🥈', '🥉'][rank - 1]
                  : '$rank위',
              style: TextStyle(
                  fontSize: rank <= 3 ? 20 : 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            backgroundImage: photoURL.isNotEmpty
                ? NetworkImage(photoURL) as ImageProvider
                : const AssetImage(
                    'assets/images/default_profile_image.png'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontWeight:
                        isTop3 ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: isTop3 ? AppColors.primary_ : null,
              color: isTop3 ? null : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$score점',
              style: TextStyle(
                color: isTop3 ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
