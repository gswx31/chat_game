import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'storage_service.dart';

const _kDeviceIdKey = 'device_id';
const _kTokenKey = 'backend_token';
const _kUserIdKey = 'user_id';
const _kNicknameKey = 'user_nickname';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _storage = StorageService.instance;

  String? _userId;
  String? _nickname;

  bool get isSignedIn => _userId != null && ApiService.instance.token != null;
  String get userId => _userId ?? '';
  String get nickname => _nickname ?? 'Guest';

  /// 앱 시작 시 저장된 토큰·userId 복원
  Future<void> loadStored() async {
    _userId = await _storage.read(_kUserIdKey);
    _nickname = await _storage.read(_kNicknameKey);
    final token = await _storage.read(_kTokenKey);
    if (token != null) ApiService.instance.setToken(token);
  }

  /// 기기 고유 ID로 게스트 계정 find-or-create
  Future<bool> signInAsGuest({Duration? timeout}) async {
    try {
      String? deviceId = await _storage.read(_kDeviceIdKey);
      if (deviceId == null) {
        deviceId = _generateDeviceId();
        await _storage.write(_kDeviceIdKey, deviceId);
      }

      final data = await ApiService.instance.post(
        '/auth/guest',
        {'device_id': deviceId},
        timeout: timeout,
      );

      final token = data['access_token'] as String;
      _userId = data['user_id'] as String;
      _nickname = data['nickname'] as String? ?? 'Guest';

      ApiService.instance.setToken(token);
      await _storage.write(_kTokenKey, token);
      await _storage.write(_kUserIdKey, _userId!);
      await _storage.write(_kNicknameKey, _nickname!);
      return true;
    } catch (e) {
      debugPrint('Guest sign-in error: $e');
      return false;
    }
  }

  /// 닉네임 변경 후 새 JWT 수령
  Future<void> updateDisplayName(String name) async {
    final data = await ApiService.instance.patch('/auth/me', {'nickname': name});
    final token = data['access_token'] as String?;
    if (token != null) {
      _nickname = name;
      ApiService.instance.setToken(token);
      await _storage.write(_kTokenKey, token);
      await _storage.write(_kNicknameKey, name);
    }
  }

  /// 백엔드에서 프로필 조회
  Future<Map<String, dynamic>?> getMemberProfile() async {
    try {
      final data =
          await ApiService.instance.get('/auth/me') as Map<String, dynamic>;
      _nickname = data['nickname'] as String? ?? _nickname;
      return {
        'displayName': _nickname,
        'photoURL': data['photo_url'] as String? ?? '',
      };
    } catch (e) {
      debugPrint('getMemberProfile error: $e');
      return null;
    }
  }

  // UUID v4 생성 (외부 패키지 불필요)
  static String _generateDeviceId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
