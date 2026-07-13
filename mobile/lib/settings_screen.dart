import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/app_theme.dart';
import 'core/router.dart';
import 'providers/auth_provider.dart';
import 'services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final profileAsync = ref.watch(memberProfileProvider(uid));
    final displayName =
        profileAsync.valueOrNull?['displayName'] as String? ?? '게스트';
    final photoURL =
        profileAsync.valueOrNull?['photoURL'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header card
            GestureDetector(
              onTap: () => context.push(Routes.myPage),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    OnlineAvatar(
                        photoURL: photoURL, radius: 30, isOnline: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          const Text('프로필 수정 →',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _SectionHeader('계정'),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              label: '내 프로필',
              onTap: () => context.push(Routes.myPage),
            ),

            _SectionHeader('앱'),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: '버전 정보',
              trailing: const Text('1.0.0',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14)),
              onTap: null,
            ),

            _SectionHeader('기타'),
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: '로그아웃',
              labelColor: AppColors.danger,
              iconColor: AppColors.danger,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('로그아웃'),
                    content: const Text('정말 로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('취소')),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger),
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await AuthService.instance.signOut();
                  context.go(Routes.signIn);
                }
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.labelColor,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
        title: Text(label,
            style: TextStyle(
              color: labelColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            )),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary)
                : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
