import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/ws_game_room.dart';

/// WebSocket game room provider — one per roomId.
/// Auto-disposed when all listeners go away (screen unmounts → WS closes).
final wsGameRoomProvider = StateNotifierProvider.autoDispose
    .family<WsGameRoom, WsGameRoomState, String>(
  (ref, roomId) {
    final token = ApiService.instance.token ?? '';
    return WsGameRoom(roomId: roomId, token: token);
  },
);
