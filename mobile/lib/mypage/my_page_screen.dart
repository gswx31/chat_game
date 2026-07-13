import 'package:flutter/material.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('닉네임을 입력해주세요.'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUidProvider);
      await AuthService.instance.updateDisplayName(uid, name);
      // Invalidate provider so DashboardScreen / SettingsScreen refresh
      ref.invalidate(memberProfileProvider(uid));
      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('프로필이 저장되었습니다.'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('변경 취소'),
            content: const Text('저장하지 않은 변경 사항이 있습니다. 나가시겠습니까?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('계속 편집')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger),
                  child: const Text('나가기')),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final profileAsync = ref.watch(memberProfileProvider(uid));

    // Pre-fill name field once profile loads
    profileAsync.whenData((p) {
      if (_nameController.text.isEmpty && p != null) {
        _nameController.text = p['displayName'] as String? ?? '';
      }
    });

    final photoURL = profileAsync.valueOrNull?['photoURL'] as String? ?? '';

    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final leave = await _onWillPop();
          if (leave && mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('내 프로필'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Avatar — shows Google photo if available, else initials
              CircleAvatar(
                radius: 56,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                backgroundImage: photoURL.isNotEmpty
                    ? NetworkImage(photoURL) as ImageProvider
                    : const AssetImage(
                        'assets/images/default_profile_image.png'),
              ),
              if (photoURL.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '구글 로그인 시 프로필 사진이 표시됩니다',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),

              // Name field
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  prefixIcon:
                      Icon(Icons.person_rounded, color: AppColors.primary),
                ),
                maxLength: 20,
                onChanged: (_) => setState(() => _hasChanges = true),
              ),
              const SizedBox(height: 32),

              GradientButton(
                label: '저장하기',
                icon: Icons.save_rounded,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
