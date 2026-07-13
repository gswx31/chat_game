import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'core/router.dart';
import 'firebase/firebase_options.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.instance.loadStoredToken();

  // 401 응답 시 자동 로그아웃
  ApiService.instance.onUnauthorized = () async {
    await AuthService.instance.signOut();
  };

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Chat Game',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      routerConfig: buildRouter(),
    );
  }
}
