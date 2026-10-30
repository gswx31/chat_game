import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_exception.dart';
import '../core/app_theme.dart';
import '../core/router.dart';
import '../models/room.dart';
import '../providers/room_provider.dart';
import '../services/room_service.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _searchCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinByCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) { _snack('방코드는 6자리예요'); return; }
    setState(() => _joining = true);
    try {
      final room = await RoomService.instance.getRoomByCode(code);
      if (!mounted) return;
      if (room.isEnded) { _snack('이미 종료된 방이에요'); return; }
      _navigateToRoom(room);
    } catch (e) {
      _snack(e is ApiException && e.isNetwork
          ? e.message
          : '해당 코드의 방을 찾을 수 없어요');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _joinRoom(Room room) async {
    if (room.isEnded) { _snack('이미 종료된 방이에요'); return; }
    _navigateToRoom(room);
  }

  void _navigateToRoom(Room room) {
    if (room.isPlaying) {
      context.go(Routes.game(room.id));
    } else {
      context.go(Routes.lobby(room.id));
    }
  }

  void _snack(String msg) => AppSnackBar.show(context, msg);

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(publicRoomsProvider);
    final keyword = _searchCtrl.text.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('방 참가하기'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Code join bar
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '방 이름으로 검색...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.search,
                        color: Colors.white.withValues(alpha: 0.7)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide:
                          const BorderSide(color: Colors.white54, width: 1),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                // Code input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          letterSpacing: 4,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: '방코드 (ABCD42)',
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              letterSpacing: 2,
                              fontWeight: FontWeight.normal,
                              fontSize: 14),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide:
                                const BorderSide(color: Colors.white54),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                        onSubmitted: (_) => _joinByCode(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _joining ? null : _joinByCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      child: _joining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: AppColors.primary, strokeWidth: 2))
                          : const Text('입장',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Rooms list
          Expanded(
            child: roomsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('서버에 연결할 수 없어요'),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: () =>
                            ref.invalidate(publicRoomsProvider),
                        child: const Text('다시 시도')),
                  ],
                ),
              ),
              data: (rooms) {
                final filtered = keyword.isEmpty
                    ? rooms
                    : rooms
                        .where((r) =>
                            r.name.toLowerCase().contains(keyword) ||
                            r.code.toLowerCase().contains(keyword))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room_outlined,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('참가 가능한 방이 없어요',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('직접 방을 만들어보세요!',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RoomCard(
                      room: filtered[i],
                      onTap: () => _joinRoom(filtered[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPlaying = room.isPlaying;
    final pct = (room.playerCount / room.maxPlayers.clamp(1, 200)).clamp(0.0, 1.0);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: isPlaying ? AppColors.accent_ : AppColors.primary_,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPlaying
                      ? Icons.play_circle_outline_rounded
                      : Icons.group_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: isPlaying ? '진행중' : '대기중',
                          color: isPlaying ? AppColors.accent : AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '코드: ${room.code}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '선 ${room.winScore}점',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                room.playerCount >= room.maxPlayers
                                    ? AppColors.danger
                                    : AppColors.primary,
                              ),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${room.playerCount}/${room.maxPlayers}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: room.playerCount >= room.maxPlayers
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
