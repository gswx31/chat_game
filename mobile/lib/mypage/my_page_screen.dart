import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  final _nameController = TextEditingController();
  bool _hasChanges = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBar.show(context, '닉네임을 입력해주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUidProvider);
      await AuthService.instance.updateDisplayName(name);
      ref.invalidate(memberProfileProvider(uid));
      if (mounted) {
        setState(() => _hasChanges = false);
        AppSnackBar.show(context, '프로필이 저장되었습니다.',
            backgroundColor: AppColors.accent);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppSnackBar.show(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    return ConfirmDialog.show(
      context,
      title: '변경 취소',
      content: '저장하지 않은 변경 사항이 있습니다. 나가시겠습니까?',
      confirmLabel: '나가기',
      cancelLabel: '계속 편집',
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final profileAsync = ref.watch(memberProfileProvider(uid));

    profileAsync.whenData((p) {
      if (_nameController.text.isEmpty && p != null) {
        _nameController.text = p['displayName'] as String? ?? '';
      }
    });

    final photoURL =
        profileAsync.valueOrNull?['photoURL'] as String? ?? '';

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, __) async {
        if (!didPop) {
          final leave = await _onWillPop();
          if (leave && context.mounted) Navigator.pop(context);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // ── 헤더 ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(gradient: AppColors.indigo_),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Column(
                      children: [
                        // AppBar row
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20),
                              onPressed: () async {
                                if (_hasChanges) {
                                  final leave = await _onWillPop();
                                  if (leave && context.mounted) Navigator.pop(context);
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const Spacer(),
                            const Text('내 프로필',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            const Spacer(),
                            if (_saving)
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                ),
                              )
                            else
                              const SizedBox(width: 36),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 52,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.15),
                                backgroundImage: photoURL.isNotEmpty
                                    ? NetworkImage(photoURL) as ImageProvider
                                    : const AssetImage(
                                        'assets/images/default_profile_image.png'),
                              ),
                            ),
                          ],
                        ),
                        if (photoURL.isEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '구글 로그인 시 프로필 사진이 표시됩니다',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── 닉네임 편집 폼 ────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text('닉네임',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: '사용할 닉네임 입력',
                        prefixIcon: Icon(Icons.person_rounded,
                            color: AppColors.primary),
                      ),
                      maxLength: 20,
                      onChanged: (_) =>
                          setState(() => _hasChanges = true),
                    ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: '저장하기',
                      icon: Icons.save_rounded,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),  // Scaffold
      ),    // AnnotatedRegion
    );      // PopScope
  }
}
