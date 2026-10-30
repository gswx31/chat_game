import 'dart:convert';

import 'package:chat_game/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json200(Object body) => http.Response(
      json.encode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response detail(int status, String d) =>
    http.Response.bytes(utf8.encode(json.encode({'detail': d})), status);

void main() {
  late ApiService api;

  setUp(() {
    api = ApiService.instance;
    api.clearToken();
    api.onUnauthorized = null;
  });

  test('requests go to the bare origin (no /api prefix)', () async {
    Uri? seen;
    await http.runWithClient(() async {
      await api.get('/rooms');
    }, () => MockClient((req) async {
          seen = req.url;
          return json200([]);
        }));
    expect(seen!.path, '/rooms');
    expect(seen.toString(), isNot(contains('/api')));
  });

  test('401 -> re-login -> original request retried once with the new token',
      () async {
    final calls = <String>[];
    api.setToken('expired');
    api.onUnauthorized = () async => api.setToken('fresh');

    late Map<String, dynamic> result;
    await http.runWithClient(() async {
      result = await api.post('/rooms', {'name': 'x'});
    }, () => MockClient((req) async {
          calls.add(req.headers['Authorization'] ?? '-');
          if (req.headers['Authorization'] == 'Bearer fresh') {
            return json200({'id': 'r1'});
          }
          return detail(401, 'Invalid or expired token');
        }));

    expect(result['id'], 'r1');
    expect(calls, ['Bearer expired', 'Bearer fresh']);
  });

  test('failed re-login surfaces the 401 instead of looping', () async {
    var hits = 0;
    api.setToken('expired');
    api.onUnauthorized = () async {}; // sign-in failed: still no token

    await http.runWithClient(() async {
      await expectLater(
        api.get('/question-sets/my'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    }, () => MockClient((req) async {
          hits++;
          return detail(401, 'Not authenticated');
        }));
    expect(hits, 1);
  });

  test('/auth/guest returning 401 never triggers re-login', () async {
    var reauth = 0;
    api.onUnauthorized = () async => reauth++;

    await http.runWithClient(() async {
      await expectLater(
        api.post('/auth/guest', {'device_id': 'x'}),
        throwsA(isA<ApiException>()),
      );
    }, () => MockClient((_) async => detail(401, 'nope')));
    expect(reauth, 0);
  });

  test('error text: Korean detail is shown, English detail is replaced',
      () async {
    await http.runWithClient(() async {
      await expectLater(
        api.get('/question-sets/abc'),
        throwsA(isA<ApiException>()
            .having((e) => e.toString(), 'msg', '맵을 찾을 수 없어요')),
      );
      await expectLater(
        api.get('/rooms/zzz'),
        throwsA(isA<ApiException>()
            .having((e) => e.toString(), 'msg', '찾을 수 없어요.')),
      );
    }, () => MockClient((req) async {
          return req.url.path.startsWith('/question-sets')
              ? detail(404, '맵을 찾을 수 없어요')
              : detail(404, 'Room not found');
        }));
  });

  test('transport failures become a friendly network ApiException', () async {
    await http.runWithClient(() async {
      await expectLater(
        api.get('/rooms'),
        throwsA(
            isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)),
      );
    }, () => MockClient((_) async => throw http.ClientException('boom')));
  });

  test('204 responses are handled for delete', () async {
    await http.runWithClient(() async {
      await api.delete('/question-sets/x');
    }, () => MockClient((_) async => http.Response('', 204)));
  });
}
