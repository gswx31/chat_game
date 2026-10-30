import 'dart:convert';

/// REST 호출 실패. [toString] 이 곧 사용자에게 보여줄 문장이라서 화면 쪽에서
/// `'저장 실패: $e'` 처럼 그대로 붙여 써도 JSON 덩어리가 노출되지 않는다.
class ApiException implements Exception {
  /// HTTP 상태 코드. 0 이면 서버에 닿지 못한 것(오프라인·타임아웃·DNS).
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isNetwork => statusCode == 0;
  bool get isUnauthorized => statusCode == 401;

  static const network = ApiException(
    0,
    '서버에 연결할 수 없어요. 인터넷 연결을 확인하고 잠시 후 다시 시도해주세요.',
  );

  /// FastAPI 에러 본문(`{"detail": ...}`)에서 사람이 읽을 문장을 뽑는다.
  /// 서버가 한글로 준 메시지는 그대로 쓰고, 영문/구조화된 값은 상태 코드별
  /// 한글 문장으로 바꾼다.
  factory ApiException.fromResponse(int status, List<int> bodyBytes) {
    String? detail;
    try {
      final body = json.decode(utf8.decode(bodyBytes));
      if (body is Map && body['detail'] is String) {
        detail = body['detail'] as String;
      }
    } catch (_) {
      // 본문이 JSON 이 아님 — 프록시/게이트웨이 에러 페이지 등
    }

    if (detail != null && _hasHangul(detail)) {
      return ApiException(status, detail);
    }
    return ApiException(status, _byStatus(status));
  }

  static bool _hasHangul(String s) =>
      s.runes.any((r) => r >= 0xAC00 && r <= 0xD7A3);

  static String _byStatus(int status) {
    switch (status) {
      case 400:
        return '요청을 처리할 수 없어요. 입력을 확인해주세요.';
      case 401:
        return '로그인이 만료됐어요. 다시 시도해주세요.';
      case 403:
        return '권한이 없어요.';
      case 404:
        return '찾을 수 없어요.';
      case 422:
        return '입력 값을 확인해주세요.';
      case 429:
        return '요청이 너무 많아요. 잠시 후 다시 시도해주세요.';
    }
    if (status >= 500) return '서버에 문제가 생겼어요. 잠시 후 다시 시도해주세요.';
    return '요청에 실패했어요. ($status)';
  }

  @override
  String toString() => message;
}
