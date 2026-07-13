import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// Raw Firebase auth state — null means signed out.
final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.instance.authStateChanges;
});

/// Derived: is the user currently signed in?
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

/// Current user Firebase UID.
final currentUidProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) throw StateError('Not authenticated');
  return user.uid;
});

/// User profile from the backend (nickname, photoURL, email).
/// The [uid] parameter is accepted for API compatibility but the backend
/// always returns the profile for the JWT bearer, so uid is unused.
final memberProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, uid) => AuthService.instance.getMemberProfile(uid),
);
