import 'package:chat_game/core/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

ResolvedApiConfig resolve({
  String api = '',
  String ws = '',
  bool release = false,
  bool web = false,
  bool android = true,
}) =>
    ResolvedApiConfig.resolve(
      apiBase: api,
      wsBase: ws,
      isRelease: release,
      isWeb: web,
      isAndroid: android,
    );

void main() {
  group('debug defaults', () {
    test('android emulator reaches host PC via 10.0.2.2, no /api suffix', () {
      final c = resolve();
      expect(c.error, isNull);
      expect(c.baseUrl, 'http://10.0.2.2:8000');
      expect(c.wsBase, 'ws://10.0.2.2:8000');
    });

    test('web / desktop use localhost', () {
      expect(resolve(web: true).baseUrl, 'http://localhost:8000');
      expect(resolve(android: false).baseUrl, 'http://localhost:8000');
    });
  });

  group('release', () {
    test('missing API_BASE_URL is a loud config error, not a silent default', () {
      final c = resolve(release: true);
      expect(c.error, contains('API_BASE_URL'));
      expect(() => c.baseUrl, throwsStateError);
      expect(() => c.wsBase, throwsStateError);
    });

    test('https address: trailing slashes trimmed, ws derived as wss', () {
      final c = resolve(api: ' https://quiz.fly.dev// ', release: true);
      expect(c.error, isNull);
      expect(c.baseUrl, 'https://quiz.fly.dev');
      expect(c.wsBase, 'wss://quiz.fly.dev');
    });

    test('http address is rejected (Android blocks cleartext)', () {
      final c = resolve(api: 'http://192.168.0.10:8000', release: true);
      expect(c.error, contains('https'));
    });
  });

  group('overrides and validation', () {
    test('explicit WS_BASE_URL wins over derivation', () {
      final c = resolve(
        api: 'https://api.example.com',
        ws: 'wss://ws.example.com/',
        release: true,
      );
      expect(c.baseUrl, 'https://api.example.com');
      expect(c.wsBase, 'wss://ws.example.com');
    });

    test('debug may use plain http and derives ws', () {
      final c = resolve(api: 'http://192.168.0.10:8000');
      expect(c.baseUrl, 'http://192.168.0.10:8000');
      expect(c.wsBase, 'ws://192.168.0.10:8000');
    });

    test('garbage addresses are reported', () {
      expect(resolve(api: 'quiz.fly.dev').error, isNotNull);
      expect(resolve(api: 'ftp://quiz.fly.dev').error, isNotNull);
      expect(
        resolve(api: 'https://ok.dev', ws: 'https://nope.dev').error,
        contains('WS_BASE_URL'),
      );
    });
  });
}
