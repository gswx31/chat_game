import 'package:flutter/foundation.dart';

/// 서버 주소 설정.
///
/// 백엔드는 `/auth`, `/rooms`, `/ws/rooms/{id}` 처럼 **루트 경로**에 라우트가 있고
/// `/api` 접두사가 없다(웹은 Vite/Vercel 프록시가 `/api`를 떼어줄 뿐). 그래서
/// 모바일의 [baseUrl] 은 경로 없는 origin 이다.
///
/// 주소는 빌드 시점에 주입한다:
///
///     flutter build apk --release --dart-define=API_BASE_URL=https://내서버.fly.dev
///
/// WS 주소는 http→ws, https→wss 로 자동 유도되고, 따로 주려면 `WS_BASE_URL`.
/// 릴리스 빌드에 주소가 없으면 에뮬레이터 주소로 조용히 붙지 않고, 앱이 시작 시
/// 설정 오류 화면을 띄운다 ([ApiConfig.error]).
class ApiConfig {
  ApiConfig._();

  static const String _apiBaseDefine = String.fromEnvironment('API_BASE_URL');
  static const String _wsBaseDefine = String.fromEnvironment('WS_BASE_URL');

  static final ResolvedApiConfig _resolved = ResolvedApiConfig.resolve(
    apiBase: _apiBaseDefine,
    wsBase: _wsBaseDefine,
    isRelease: kReleaseMode,
    isWeb: kIsWeb,
    isAndroid: defaultTargetPlatform == TargetPlatform.android,
  );

  /// 설정이 잘못됐으면 사용자에게 보여줄 설명, 정상이면 null.
  static String? get error => _resolved.error;

  static bool get isConfigured => _resolved.error == null;

  /// REST 기준 주소 (끝 슬래시 없음, `/api` 없음).
  static String get baseUrl => _resolved.baseUrl;

  /// WebSocket 기준 주소 (끝 슬래시 없음).
  static String get wsBase => _resolved.wsBase;
}

/// [ApiConfig] 의 순수 계산부 — 플랫폼 값을 인자로 받아서 단위 테스트가 가능하다.
class ResolvedApiConfig {
  final String? _baseUrl;
  final String? _wsBase;
  final String? error;

  const ResolvedApiConfig._(this._baseUrl, this._wsBase, this.error);

  String get baseUrl => _baseUrl ?? (throw StateError(error!));
  String get wsBase => _wsBase ?? (throw StateError(error!));

  static ResolvedApiConfig _fail(String message) =>
      ResolvedApiConfig._(null, null, message);

  static ResolvedApiConfig resolve({
    required String apiBase,
    String wsBase = '',
    required bool isRelease,
    required bool isWeb,
    required bool isAndroid,
  }) {
    var api = _trimSlash(apiBase.trim());

    if (api.isEmpty) {
      if (isRelease) {
        return _fail(
          '서버 주소가 설정되지 않은 앱이에요.\n'
          '빌드할 때 --dart-define=API_BASE_URL=https://서버주소 를 넣어야 해요.',
        );
      }
      // 개발용 기본값: 안드로이드 에뮬레이터는 호스트 PC 를 10.0.2.2 로 본다.
      api = (!isWeb && isAndroid) ? 'http://10.0.2.2:8000' : 'http://localhost:8000';
    }

    final apiUri = Uri.tryParse(api);
    if (apiUri == null ||
        !(apiUri.scheme == 'http' || apiUri.scheme == 'https') ||
        apiUri.host.isEmpty) {
      return _fail('API_BASE_URL 형식이 잘못됐어요: "$api"\n'
          'http:// 또는 https:// 로 시작하는 주소여야 해요.');
    }
    if (isRelease && apiUri.scheme != 'https') {
      return _fail('릴리스 앱은 https 주소만 쓸 수 있어요: "$api"\n'
          '(안드로이드가 http 통신을 막아요. 테스트는 debug 빌드로 하세요.)');
    }

    var ws = _trimSlash(wsBase.trim());
    if (ws.isEmpty) {
      ws = api.replaceFirst(RegExp(r'^http', caseSensitive: false), 'ws');
    }
    final wsUri = Uri.tryParse(ws);
    if (wsUri == null ||
        !(wsUri.scheme == 'ws' || wsUri.scheme == 'wss') ||
        wsUri.host.isEmpty) {
      return _fail('WS_BASE_URL 형식이 잘못됐어요: "$ws"\n'
          'ws:// 또는 wss:// 로 시작하는 주소여야 해요.');
    }

    return ResolvedApiConfig._(api, ws, null);
  }

  static String _trimSlash(String s) {
    var out = s;
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }
}
