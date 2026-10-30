import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/app_theme.dart';
import 'core/router.dart';
import 'providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final profileAsync = ref.watch(memberProfileProvider(uid));
    final displayName =
        profileAsync.valueOrNull?['displayName'] as String? ?? '게스트';
    final photoURL =
        profileAsync.valueOrNull?['photoURL'] as String? ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── 프로필 헤더 ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHeader(
              displayName: displayName,
              photoURL: photoURL,
              onTap: () => context.push(Routes.myPage),
            ),
          ),

          // ── 계정 섹션 ─────────────────────────────────────────────
          const SliverToBoxAdapter(child: SectionHeader('계정')),
          SliverToBoxAdapter(
            child: _TileGroup(tiles: [
              _Tile(
                icon: Icons.person_rounded,
                iconColor: const Color(0xFF6C63FF),
                label: '내 프로필',
                onTap: () => context.push(Routes.myPage),
              ),
              _Tile(
                icon: Icons.map_rounded,
                iconColor: const Color(0xFF00C896),
                label: '내 맵',
                subtitle: '커스텀 퀴즈 세트 관리',
                onTap: () => context.push(Routes.questionSets),
              ),
            ]),
          ),

          // ── 앱 섹션 ───────────────────────────────────────────────
          const SliverToBoxAdapter(child: SectionHeader('앱')),
          const SliverToBoxAdapter(
            child: _TileGroup(tiles: [
              _Tile(
                icon: Icons.info_outline_rounded,
                iconColor: Color(0xFF6B7280),
                label: '버전 정보',
                trailing: Text('1.0.0',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                onTap: null,
              ),
            ]),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    ));
  }
}

// ── Profile header ────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String photoURL;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.displayName,
    required this.photoURL,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.indigo_),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              children: [
                // AppBar row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => context.pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                    const Text('설정',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    const SizedBox(width: 36), // balance
                  ],
                ),
                const SizedBox(height: 24),
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    backgroundImage: photoURL.isNotEmpty
                        ? NetworkImage(photoURL) as ImageProvider
                        : const AssetImage(
                            'assets/images/default_profile_image.png'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined,
                          color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text('프로필 수정',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tile group card ───────────────────────────────────────────────────────

class _TileGroup extends StatelessWidget {
  final List<_Tile> tiles;
  const _TileGroup({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1)
              const Divider(
                  height: 1, indent: 64, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: IconBox(icon: icon, color: iconColor),
      title: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12))
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 20)
              : null),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}
