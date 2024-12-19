import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'firebase/firebase_options.dart';
import 'mypage/my_page_screen.dart';
import 'sign_in_screen.dart';
import 'dashboard_screen.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'game/result_screen.dart';
import 'lobby_screen.dart';
import 'settings_screen.dart';
import 'profile_image_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize App Check
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('6LchhhsqAAAAABvh73QRreNc3FBP5ZBiSssmmwqd'), // Web에서 사용하는 경우
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/result') {
          final arguments = settings.arguments as Map<String, dynamic>;
          final score = arguments['score'] as int;
          return MaterialPageRoute(
            builder: (context) => ResultScreen(users: [], roomId: '',),
          );
        } else if (settings.name == '/lobby') {
          final arguments = settings.arguments as Map<String, dynamic>;
          final roomId = arguments['roomId'] as String;
          return MaterialPageRoute(
            builder: (context) => LobbyScreen(roomId: roomId),
          );
        } else if (settings.name == '/view_game_profile') {
          final arguments = settings.arguments as Map<String, dynamic>;
          final displayName = arguments['displayName'] as String;
          final photoURL = arguments['photoURL'] as String?;
          return MaterialPageRoute(
            builder: (context) => ProfileImageScreen(
              displayName: displayName,
              photoURL: photoURL ?? '', // Handle possible null photoURL
            ),
          );
        } else {
          return null;
        }
      },
      routes: {
        '/signIn': (context) => SignInScreen(),
        '/dashboard': (context) => DashboardScreen(),
        '/create_room': (context) => CreateRoomScreen(),
        '/join_room': (context) => JoinRoomScreen(),
        '/settings': (context) => SettingsScreen(),
        '/mypage': (context) => MyPageScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(Duration(seconds: 2)); // 2초 지연
    // 로그인 상태 확인
    firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 로그인 상태라면 대시보드 화면으로 이동
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // 로그인 상태가 아니라면 로그인 화면으로 이동
      Navigator.pushReplacementNamed(context, '/signIn');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/splash.png'), // 썸네일 이미지
      ),
    );
  }
}
