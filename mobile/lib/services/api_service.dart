import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/api_exception.dart';

export '../core/api_exception.dart';

class ApiService {
  ApiService._();
  static final instance = ApiService._();

  /// 무료 호스팅은 첫 요청에 콜드스타트로 수 초 걸린다. 응답이 아예 없을 때
  /// 화면이 영원히 도는 것만 막는 상한.
  static const _defaultTimeout = Duration(seconds: 20);

  String? _token;

  /// 서버가 401 을 주면 호출된다 — main.dart 에서 게스트 재로그인으로 연결.
  /// 끝나면 토큰이 새로 세팅돼 있어야 하고, 그러면 원래 요청을 한 번 재시도한다.
  Future<void> Function()? onUnauthorized;

  Future<void>? _reauth; // 동시에 401 이 여러 번 와도 재로그인은 한 번만

  void setToken(String t) => _token = t;
  void clearToken() => _token = null;
  String? get token => _token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String path, {Duration? timeout}) async {
    final res = await _send('GET', path, null, timeout);
    if (res.statusCode == 204) return null;
    return json.decode(utf8.decode(res.bodyBytes));
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) =>
      _sendJson('POST', path, body, timeout);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _sendJson('PUT', path, body, null);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _sendJson('PATCH', path, body, null);

  Future<void> delete(String path) async {
    await _send('DELETE', path, null, null);
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path,
    Map<String, dynamic> body,
    Duration? timeout,
  ) async {
    final res = await _send(method, path, body, timeout);
    if (res.statusCode == 204) return {};
    return json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// 요청 1회 + (401 이면) 재로그인 후 1회 재시도. 2xx 가 아니면 [ApiException].
  Future<http.Response> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
    Duration? timeout,
  ) async {
    var res = await _once(method, path, body, timeout);

    // /auth/guest 자체가 401 이면 재로그인해도 소용없으므로 제외(무한루프 방지).
    if (res.statusCode == 401 && onUnauthorized != null && path != '/auth/guest') {
      clearToken();
      await (_reauth ??= onUnauthorized!().whenComplete(() => _reauth = null));
      if (_token != null) {
        res = await _once(method, path, body, timeout);
      }
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException.fromResponse(res.statusCode, res.bodyBytes);
    }
    return res;
  }

  Future<http.Response> _once(
    String method,
    String path,
    Map<String, dynamic>? body,
    Duration? timeout,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = _headers;
    final encoded = body == null ? null : json.encode(body);

    final Future<http.Response> req;
    switch (method) {
      case 'GET':
        req = http.get(uri, headers: headers);
      case 'POST':
        req = http.post(uri, headers: headers, body: encoded);
      case 'PUT':
        req = http.put(uri, headers: headers, body: encoded);
      case 'PATCH':
        req = http.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        req = http.delete(uri, headers: headers);
      default:
        throw ArgumentError('unsupported method $method');
    }

    try {
      return await req.timeout(timeout ?? _defaultTimeout);
    } on StateError {
      rethrow; // ApiConfig 설정 오류 — 네트워크 문제로 둔갑시키지 않는다
    } catch (_) {
      // SocketException / ClientException / TimeoutException … 전부 "서버에 못 닿음"
      throw ApiException.network;
    }
  }
}
