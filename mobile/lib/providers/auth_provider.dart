import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// 재로그인이 일어날 때마다 올라가는 카운터 — [currentUidProvider] 가 이걸 보고
/// 갱신된다. (첫 실행을 오프라인으로 시작했다가 나중에 로그인되는 경우 uid 가
/// 빈 문자열로 굳어버리는 걸 막는다.)
final authRevisionProvider = StateProvider<int>((ref) => 0);

/// 현재 로그인된 백엔드 user_id (WS 메시지의 user_id와 동일한 값)
final currentUidProvider = Provider<String>((ref) {
  ref.watch(authRevisionProvider);
  return AuthService.instance.userId;
});

/// 사용자 프로필 (닉네임, 사진) — 백엔드 /auth/me 조회
final memberProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, _) => AuthService.instance.getMemberProfile(),
);
