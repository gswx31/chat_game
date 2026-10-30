import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api_config.dart';
import 'core/app_theme.dart';
import 'core/router.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 서버 주소 없이 만들어진 릴리스 빌드는 에뮬레이터 주소로 조용히 붙는 대신
  // 무엇이 잘못됐는지 화면에 바로 보여준다.
  final configError = ApiConfig.error;
  if (configError != null) {
    runApp(_ConfigErrorApp(message: configError));
    return;
  }

  final container = ProviderContainer();

  await AuthService.instance.loadStored();

  // 토큰 만료(401) 시 같은 기기 ID 로 자동 재로그인. 끝나면 ApiService 가 원래
  // 요청을 한 번 재시도하고, uid 를 쓰는 화면은 authRevision 으로 갱신된다.
  ApiService.instance.onUnauthorized = () async {
    await AuthService.instance.signInAsGuest();
    container.read(authRevisionProvider.notifier).state++;
  };

  // 저장된 토큰은 7일 뒤 만료되므로 시작할 때마다 한 번 새로 받는다. 서버에 못
  // 닿으면(오프라인·콜드스타트) 저장된 값으로 그냥 진행한다 — 첫 실행이면 첫
  // 401 때 위 핸들러가 다시 시도한다.
  await AuthService.instance
      .signInAsGuest(timeout: const Duration(seconds: 6));

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '상식퀴즈배틀',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      routerConfig: buildRouter(),
    );
  }
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_suggest, size: 56),
                  const SizedBox(height: 16),
                  const Text('앱 설정 오류',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
