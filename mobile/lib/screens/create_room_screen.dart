import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_exception.dart';
import '../core/app_theme.dart';
import '../core/router.dart';
import '../providers/question_set_provider.dart';
import '../providers/room_provider.dart';
import '../services/room_service.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  String _roomName = '';
  bool _isPublic = true;
  int _winScore = 20;
  String? _selectedQuestionSetId;
  int _roundSeconds = 30;
  int _maxPlayers = 30;
  final Set<String> _selectedCategories = {};
  bool _loading = false;

  String _roomErrorMessage(Object e) {
    // ApiException.toString() 은 이미 사용자용 문장이다 (네트워크/401/422/서버 메시지).
    if (e is ApiException) return e.message;
    return '방을 만들 수 없어요. 잠시 후 다시 시도해주세요.';
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);
    try {
      final room = await RoomService.instance.createRoom(
        name: _roomName.trim(),
        isPublic: _isPublic,
        winScore: _winScore,
        roundSeconds: _roundSeconds,
        maxPlayers: _maxPlayers,
        categories: _selectedQuestionSetId != null ? [] : _selectedCategories.toList(),
        questionSetId: _selectedQuestionSetId,
      );
      if (mounted) context.go(Routes.lobby(room.id));
    } catch (e) {
      if (mounted) AppSnackBar.show(context, _roomErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final qSetsAsync = ref.watch(myQSetsProvider);

    return Scaffold(
      appBar: const GradientAppBar(title: '방 만들기'),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: GradientButton(
            label: '방 만들기',
            icon: Icons.meeting_room_rounded,
            onPressed: _loading ? null : _createRoom,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 방 이름 ──────────────────────────────────────
                  _FormSection(
                    icon: Icons.meeting_room_rounded,
                    iconColor: const Color(0xFF6C63FF),
                    title: '방 이름',
                    child: TextFormField(
                      decoration: const InputDecoration(
                        hintText: '예: 우리반 퀴즈왕',
                        prefixIcon: Icon(Icons.edit_outlined,
                            color: AppColors.primary, size: 20),
                      ),
                      maxLength: 40,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '방 이름을 입력해주세요.' : null,
                      onSaved: (v) => _roomName = v ?? '',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 게임 설정 ─────────────────────────────────────
                  _FormSection(
                    icon: Icons.tune_rounded,
                    iconColor: const Color(0xFF00C896),
                    title: '게임 설정',
                    child: Column(
                      children: [
                        _SettingSlider(
                          icon: Icons.emoji_events_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: '목표 점수',
                          value: '$_winScore점',
                          slider: Slider(
                            value: _winScore.toDouble(),
                            min: 5,
                            max: 100,
                            divisions: 19,
                            label: '$_winScore점',
                            onChanged: (v) =>
                                setState(() => _winScore = v.round()),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SettingSlider(
                          icon: Icons.timer_outlined,
                          iconColor: const Color(0xFF6C63FF),
                          label: '라운드 시간',
                          value: '$_roundSeconds초',
                          slider: Slider(
                            value: _roundSeconds.toDouble(),
                            min: 10,
                            max: 120,
                            divisions: 11,
                            label: '$_roundSeconds초',
                            onChanged: (v) =>
                                setState(() => _roundSeconds = v.round()),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SettingSlider(
                          icon: Icons.people_rounded,
                          iconColor: const Color(0xFF0077B6),
                          label: '최대 인원',
                          value: '$_maxPlayers명',
                          slider: Slider(
                            value: _maxPlayers.toDouble(),
                            min: 2,
                            max: 200,
                            divisions: 198,
                            label: '$_maxPlayers명',
                            onChanged: (v) =>
                                setState(() => _maxPlayers = v.round()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 공개 여부 ─────────────────────────────────────
                  _PublicToggle(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  const SizedBox(height: 20),

                  // ── 커스텀 맵 선택 ─────────────────────────────────
                  _FormSection(
                    icon: Icons.map_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: '커스텀 맵 (선택)',
                    subtitle: '내가 만든 맵으로 게임하기',
                    child: qSetsAsync.when(
                      loading: () => const _SmallLoader(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (sets) {
                        if (sets.isEmpty) {
                          return const _EmptyHint(
                            icon: Icons.map_outlined,
                            text: '아직 만든 맵이 없어요. 설정에서 만들 수 있어요.',
                          );
                        }
                        return DropdownButtonFormField<String?>(
                          initialValue: _selectedQuestionSetId,
                          decoration: const InputDecoration(
                            hintText: '기본 문제 풀 사용',
                            prefixIcon: Icon(Icons.quiz_rounded,
                                color: AppColors.primary),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('기본 문제 풀 사용'),
                            ),
                            ...sets.map((s) => DropdownMenuItem<String?>(
                                  value: s.id,
                                  child: Text(
                                      '${s.name} (${s.itemCount}문항)',
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedQuestionSetId = v),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 카테고리 ──────────────────────────────────────
                  _FormSection(
                    icon: Icons.category_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: '카테고리',
                    subtitle: '선택 안 하면 전체 카테고리 혼합',
                    badge: _selectedCategories.isNotEmpty
                        ? '${_selectedCategories.length}개 선택'
                        : null,
                    child: catsAsync.when(
                      loading: () => const _SmallLoader(),
                      error: (e, _) => Text('$e',
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                      data: (cats) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cats.map((c) {
                          final on = _selectedCategories.contains(c);
                          return _CategoryChip(
                            label: c,
                            selected: on,
                            onTap: () => setState(() {
                              if (on) {
                                _selectedCategories.remove(c);
                              } else {
                                _selectedCategories.add(c);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 로딩 오버레이 ──────────────────────────────────────────
          if (_loading)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppShadows.card,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('방을 만드는 중...',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Form section card ─────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? badge;
  final Widget child;

  const _FormSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.badge,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                IconBox(icon: icon, color: iconColor, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge!,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Slider row ────────────────────────────────────────────────────────────

class _SettingSlider extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget slider;

  const _SettingSlider({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
              const Spacer(),
              ValuePill(value),
            ],
          ),
          slider,
        ],
      ),
    );
  }
}

// ── Public toggle ─────────────────────────────────────────────────────────

class _PublicToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PublicToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 16, 6),
        leading: IconBox(
          icon: value ? Icons.public_rounded : Icons.lock_outline_rounded,
          color: value ? const Color(0xFF0077B6) : const Color(0xFF6B7280),
          size: 32,
        ),
        title: Text(
          value ? '공개 방' : '비공개 방',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          value ? '로비 목록에 표시됩니다' : '코드를 알아야 입장 가능합니다',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
              width: 1.5),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _SmallLoader extends StatelessWidget {
  const _SmallLoader();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 36,
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
      ],
    );
  }
}
