import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../core/router.dart';
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
  int _roundSeconds = 30;
  int _maxPlayers = 30;
  final Set<String> _selectedCategories = {};
  bool _loading = false;

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
        categories: _selectedCategories.toList(),
      );
      if (mounted) context.go(Routes.lobby(room.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('방 생성 실패: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('방 만들기')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                  // Room name
                  _SectionLabel('방 이름'),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: '예: 우리반 퀴즈왕',
                      prefixIcon: Icon(Icons.meeting_room_rounded,
                          color: AppColors.primary),
                    ),
                    maxLength: 40,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '방 이름을 입력해주세요.' : null,
                    onSaved: (v) => _roomName = v ?? '',
                  ),
                  const SizedBox(height: 24),

                  // Settings grid
                  _SectionLabel('게임 설정'),
                  const SizedBox(height: 12),
                  _SettingRow(
                    label: '목표 점수',
                    value: '$_winScore점',
                    child: Slider(
                      value: _winScore.toDouble(),
                      min: 5,
                      max: 100,
                      divisions: 19,
                      label: '$_winScore점',
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _winScore = v.round()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingRow(
                    label: '라운드 시간',
                    value: '${_roundSeconds}초',
                    child: Slider(
                      value: _roundSeconds.toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      label: '${_roundSeconds}초',
                      activeColor: AppColors.primary,
                      onChanged: (v) =>
                          setState(() => _roundSeconds = v.round()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingRow(
                    label: '최대 인원',
                    value: '$_maxPlayers명',
                    child: Slider(
                      value: _maxPlayers.toDouble(),
                      min: 2,
                      max: 200,
                      divisions: 198,
                      label: '$_maxPlayers명',
                      activeColor: AppColors.primary,
                      onChanged: (v) =>
                          setState(() => _maxPlayers = v.round()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Public toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SwitchListTile(
                      title: const Text('공개 방',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          const Text('로비 목록에 표시됩니다', style: TextStyle(fontSize: 12)),
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                      activeColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Categories
                  Row(
                    children: [
                      const Expanded(child: _SectionLabel('카테고리')),
                      if (_selectedCategories.isNotEmpty)
                        Text(
                          '${_selectedCategories.length}개 선택',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('선택 안 하면 전체 카테고리',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 10),
                  catsAsync.when(
                    loading: () => const SizedBox(
                        height: 40,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary, strokeWidth: 2))),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cats) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cats.map((c) {
                        final on = _selectedCategories.contains(c);
                        return FilterChip(
                          label: Text(c),
                          selected: on,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selectedCategories.add(c);
                            } else {
                              _selectedCategories.remove(c);
                            }
                          }),
                          selectedColor: AppColors.primary.withOpacity(0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: on
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight:
                                on ? FontWeight.w700 : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: on
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16))),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('방을 만드는 중...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary));
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget child;

  const _SettingRow({
    required this.label,
    required this.value,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(value,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
