import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../services/room_service.dart';

// ── Public rooms (polling) ────────────────────────────────────────────────

class RoomsNotifier extends StateNotifier<AsyncValue<List<Room>>> {
  RoomsNotifier() : super(const AsyncValue.loading()) {
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Timer? _timer;

  Future<void> _load() async {
    try {
      final rooms = await RoomService.instance.listRooms();
      if (mounted) state = AsyncValue.data(rooms);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void refresh() => _load();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final publicRoomsProvider =
    StateNotifierProvider<RoomsNotifier, AsyncValue<List<Room>>>(
  (ref) => RoomsNotifier(),
);

// ── Single room (one-shot fetch) ──────────────────────────────────────────

final roomFutureProvider = FutureProvider.autoDispose.family<Room, String>(
  (ref, id) => RoomService.instance.getRoom(id),
);

// ── Available categories ──────────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<String>>(
  (ref) => RoomService.instance.getCategories(),
);

