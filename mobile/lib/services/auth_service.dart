import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';
import 'storage_service.dart';

const _kTokenKey = 'backend_token';

class UserProfile {
  final String userId;
  final String nickname;
  final String? photoUrl;
  final String? email;
  final bool isGuest;

  const UserProfile({
    required this.userId,
    required this.nickname,
    this.photoUrl,
    this.email,
    this.isGuest = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        userId: j['user_id'] as String,
        nickname: j['nickname'] as String,
        photoUrl: j['photo_url'] as String?,
        email: j['email'] as String?,
        isGuest: j['is_guest'] as bool? ?? false,
      );

  Map<String, dynamic> toDisplayMap() => {
        'displayName': nickname,
        'photoURL': photoUrl ?? '',
        'email': email ?? '',
        'isGuest': isGuest,
      };
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _storage = StorageService.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Restores the backend JWT on app start so API calls work immediately.
  Future<void> loadStoredToken() async {
    final token = await _storage.read(_kTokenKey);
    if (token != null) ApiService.instance.setToken(token);
  }

  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      await _upsertBackend(result.user);
      return result.user;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return null;
    }
  }

  Future<User?> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      await _upsertBackend(result.user);
      return result.user;
    } catch (e) {
      debugPrint('Anonymous sign-in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
    ApiService.instance.clearToken();
    await _storage.delete(_kTokenKey);
  }

  /// Fetch the current user's profile from the backend.
  /// [uid] parameter is kept for API compatibility with memberProfileProvider.
  Future<Map<String, dynamic>?> getMemberProfile(String uid) async {
    try {
      final data = await ApiService.instance.get('/auth/me') as Map<String, dynamic>;
      return UserProfile.fromJson(data).toDisplayMap();
    } catch (e) {
      debugPrint('getMemberProfile error: $e');
      return null;
    }
  }

  /// Update nickname on both backend and local JWT.
  Future<void> updateDisplayName(String uid, String name) async {
    try {
      final data = await ApiService.instance.patch('/auth/me', {'nickname': name});
      final token = data['access_token'] as String?;
      if (token != null) {
        ApiService.instance.setToken(token);
        await _storage.write(_kTokenKey, token);
      }
    } catch (e) {
      debugPrint('updateDisplayName error: $e');
      rethrow;
    }
  }

  // ── private ──────────────────────────────────────────────────────────────

  /// Find-or-create user in the backend DB by firebase_uid.
  /// Returns the same user_id every time, fixing the session-ID drift bug.
  Future<void> _upsertBackend(User? user) async {
    if (user == null) return;
    try {
      final nickname = user.isAnonymous
          ? 'Guest_${user.uid.substring(0, 6)}'
          : (user.displayName ?? 'Player');

      final data = await ApiService.instance.post('/auth/upsert', {
        'firebase_uid': user.uid,
        'nickname': nickname,
        if (user.email != null) 'email': user.email,
        if (user.photoURL != null) 'photo_url': user.photoURL,
        'is_guest': user.isAnonymous,
      });
      final token = data['access_token'] as String;
      ApiService.instance.setToken(token);
      await _storage.write(_kTokenKey, token);
    } catch (e) {
      debugPrint('Backend upsert error: $e');
    }
  }
}
