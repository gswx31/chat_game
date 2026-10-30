// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
//
// LIVE test: the app's real client classes (ApiService / AuthService /
// RoomService / WsGameRoom) against a REAL running backend. Nothing is mocked
// except the OS keychain. Lives in test_live/ so `flutter test` and CI skip it.
//
// 1. Start the backend (Postgres + Redis up, questions synced), e.g. from backend/:
//      uvicorn app.main:app --port 8765          (use a scratch DB, not your dev data)
// 2. From mobile/:
//      flutter test test_live/live_game_test.dart \
//        --dart-define=API_BASE_URL=http://127.0.0.1:8765 \
//        --dart-define=WS_BASE_URL=ws://127.0.0.1:8766 --timeout 120s
//
// WS_BASE_URL=ws://127.0.0.1:8766 makes the test start a tiny WebSocket proxy on
// that port (-> API_BASE_URL). It lets the test sever one player's socket the way
// a Wi-Fi drop would and watch the app's OWN auto-reconnect. Without it the test
// still runs; the "network drop" step falls back to dispose + new connection.
//
// test_live/answers.json (prompt -> accepted answers) is generated on first run
// from backend/app/questions/seed_data.py and is git-ignored.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chat_game/core/api_config.dart';
import 'package:chat_game/models/room.dart';
import 'package:chat_game/services/api_service.dart';
import 'package:chat_game/services/auth_service.dart';
import 'package:chat_game/services/room_service.dart';
import 'package:chat_game/services/ws_game_room.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _proxyPort = 8766;

// ── helpers ──────────────────────────────────────────────────────────────

Future<void> until(
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 20),
  required String why,
}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) {
      fail('timed out after ${timeout.inSeconds}s waiting for: $why');
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
}

String _uuid() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

class Client {
  Client(this.name);
  final String name;
  late String deviceId;
  late String token;
  late String userId;
  late String nickname;
  WsGameRoom? room;

  WsGameRoomState get s => room!.state;
}

/// Tiny WS man-in-the-middle: client <-> proxy <-> backend. Lets the test cut one
/// player's socket (as a network drop would) and count connection attempts.
class WsProxy {
  WsProxy(this.upstream);
  final String upstream; // ws://127.0.0.1:8765
  late HttpServer _server;
  final _byToken = <String, List<WebSocket>>{};
  final connectsByRoom = <String, int>{};

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _proxyPort);
    _server.listen((req) async {
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = 400;
        await req.response.close();
        return;
      }
      final roomId = req.uri.pathSegments.last;
      connectsByRoom[roomId] = (connectsByRoom[roomId] ?? 0) + 1;
      final token = req.uri.queryParameters['token'] ?? '';
      final client = await WebSocketTransformer.upgrade(req);
      final up = await WebSocket.connect('$upstream${req.uri}');
      _byToken.putIfAbsent(token, () => []).add(client);

      client.listen(
        up.add,
        onDone: () => up.close(),
        onError: (_) => up.close(),
      );
      up.listen(
        client.add,
        onDone: () {
          final code = up.closeCode;
          // dart:io only allows 1000 and 3000..4999 as explicit close codes.
          final ok = code != null && (code == 1000 || (code >= 3000 && code <= 4999));
          client.close(ok ? code : null, up.closeReason);
        },
        onError: (_) => client.close(),
      );
    });
  }

  void sever(String token) {
    for (final ws in _byToken[token] ?? const <WebSocket>[]) {
      ws.close(3999, 'test: network drop');
    }
  }

  Future<void> stop() => _server.close(force: true);
}

// ── test ─────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test replaces HttpClient with a stub that answers 400 to everything.
  HttpOverrides.global = null;

  late Map<String, List<String>> answers;
  WsProxy? proxy;
  final opened = <WsGameRoom>[];

  List<String> ans(String prompt) {
    final a = answers[prompt];
    if (a == null) fail('prompt not in seed_data: $prompt');
    return a;
  }

  Future<Client> login(String name) async {
    final c = Client(name)..deviceId = 'dev-${_uuid()}';
    FlutterSecureStorage.setMockInitialValues({'device_id': c.deviceId});
    ApiService.instance.clearToken();
    expect(await AuthService.instance.signInAsGuest(), isTrue, reason: '$name guest login');
    c
      ..token = ApiService.instance.token!
      ..userId = AuthService.instance.userId
      ..nickname = AuthService.instance.nickname;
    ApiService.instance.clearToken();
    return c;
  }

  /// Run REST calls as [c]. The global token is cleared afterwards because a
  /// WsGameRoom prefers ApiService's token over the one it was constructed with.
  Future<T> asClient<T>(Client c, Future<T> Function() body) async {
    ApiService.instance.setToken(c.token);
    try {
      return await body();
    } finally {
      ApiService.instance.clearToken();
    }
  }

  WsGameRoom connect(Client c, String roomId, {String? token}) {
    ApiService.instance.clearToken();
    final r = WsGameRoom(roomId: roomId, token: token ?? c.token);
    opened.add(r);
    c.room = r;
    return r;
  }

  setUpAll(() async {
    final base = ApiConfig.baseUrl;
    try {
      final r = await HttpClient().getUrl(Uri.parse('$base/healthz')).then((q) => q.close());
      expect(r.statusCode, 200);
    } catch (e) {
      fail('backend not reachable at $base ($e). Start it first - see the header of this file.');
    }

    final file = File('test_live/answers.json');
    if (!file.existsSync()) {
      final py = Platform.isWindows ? r'..\backend\.venv\Scripts\python.exe' : '../backend/.venv/bin/python';
      final res = await Process.run(
        py,
        [
          '-X',
          'utf8',
          '-c',
          "import json,app.questions.seed_data as d;"
              "print(json.dumps({q['prompt']:[q['answer'],*q.get('accepted',[])] for q in d.SEED},ensure_ascii=False))",
        ],
        workingDirectory: '../backend',
        environment: {'PYTHONUTF8': '1', 'PYTHONPATH': '.'},
        stdoutEncoding: utf8,
      );
      if (res.exitCode != 0) fail('could not build answers.json: ${res.stderr}');
      file.writeAsStringSync(res.stdout as String);
    }
    answers = (json.decode(file.readAsStringSync()) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List).cast<String>()));

    if (ApiConfig.wsBase == 'ws://127.0.0.1:$_proxyPort') {
      proxy = WsProxy(base.replaceFirst(RegExp('^http'), 'ws'));
      await proxy!.start();
      print('[live] WS proxy on :$_proxyPort -> $base (network-drop test uses the app auto-reconnect)');
    } else {
      print('[live] no WS proxy (WS_BASE_URL=${ApiConfig.wsBase}); network drop = dispose + reconnect');
    }
  });

  tearDownAll(() async {
    ApiService.instance.onUnauthorized = null;
    ApiService.instance.clearToken();
    for (final r in opened) {
      if (r.mounted) r.dispose();
    }
    await proxy?.stop();
  });

  // ── REST ───────────────────────────────────────────────────────────────

  group('REST through the real ApiService', () {
    test('guest login is stable per device id; profile + categories parse', () async {
      final a = await login('A');
      FlutterSecureStorage.setMockInitialValues({'device_id': a.deviceId});
      expect(await AuthService.instance.signInAsGuest(), isTrue);
      expect(AuthService.instance.userId, a.userId, reason: 'same device -> same account');
      expect(AuthService.instance.nickname, startsWith('Guest_'));

      final profile = await AuthService.instance.getMemberProfile();
      expect(profile, isNotNull);
      expect(profile!['displayName'], a.nickname);
      ApiService.instance.clearToken();

      final cats = await RoomService.instance.getCategories();
      expect(cats, hasLength(8));
      expect(cats, containsAll(['역사', '문학', '예술', 'IT']));
    });

    test('real server errors become readable ApiExceptions', () async {
      ApiService.instance.clearToken();
      await expectLater(
        RoomService.instance.getRoomByCode('ZZZZZZ'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 404)
            .having((e) => e.message, 'message', '찾을 수 없어요.')),
      );
      await expectLater(
        ApiService.instance.get('/auth/me'),
        throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', isTrue)),
        reason: 'no re-login handler -> surfaces, does not loop',
      );
    });

    test('401 -> guest re-login -> original request retried (also when 3 expire at once)', () async {
      final d = await login('D');
      FlutterSecureStorage.setMockInitialValues({'device_id': d.deviceId});
      var reauths = 0;
      // identical to what main.dart wires up
      ApiService.instance.onUnauthorized = () async {
        reauths++;
        await AuthService.instance.signInAsGuest();
      };
      try {
        ApiService.instance.setToken('expired.or.garbage');
        final profile = await AuthService.instance.getMemberProfile();
        expect(profile, isNotNull, reason: 'request must succeed after transparent re-login');
        expect(reauths, 1);
        expect(ApiService.instance.token, isNot('expired.or.garbage'));
        expect(AuthService.instance.userId, d.userId);

        ApiService.instance.setToken('expired.again');
        final all = await Future.wait([
          for (var i = 0; i < 3; i++) ApiService.instance.get('/auth/me'),
        ]);
        for (final me in all) {
          expect((me as Map)['user_id'], d.userId);
        }
        print('[live] re-logins for 3 concurrent expired requests: ${reauths - 1}');
        expect(reauths - 1, lessThanOrEqualTo(3));
      } finally {
        ApiService.instance.onUnauthorized = null;
        ApiService.instance.clearToken();
      }
    });
  });

  // ── WebSocket refusals ─────────────────────────────────────────────────

  group('WebSocket close codes -> app state', () {
    test('4404 unknown room: fatal "방이 사라졌어요", no retry storm', () async {
      final a = await login('A404');
      final ws = connect(a, 'room-that-does-not-exist');
      await until(() => ws.state.fatalError != null, why: 'fatalError after 4404');
      expect(ws.state.fatalError, '방이 사라졌어요');
      expect(ws.state.connected, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      expect(ws.state.connected, isFalse);
      if (proxy != null) {
        expect(proxy!.connectsByRoom['room-that-does-not-exist'], 1,
            reason: 'a fatal close must not reconnect');
      }
    });

    test('4401 expired token: ONE automatic guest re-login, then connected', () async {
      final d = await login('D4401');
      final room = await asClient(d, () => RoomService.instance.createRoom(name: 'e2e-4401', winScore: 3, roundSeconds: 10));
      FlutterSecureStorage.setMockInitialValues({'device_id': d.deviceId});
      ApiService.instance.setToken('expired.or.garbage');
      final ws = WsGameRoom(roomId: room.id, token: 'expired.or.garbage');
      opened.add(ws);
      try {
        await until(
          () => ws.state.connected && ws.state.players.any((p) => p.userId == d.userId),
          why: 'connected + own player listed after re-login',
        );
        expect(ws.state.fatalError, isNull);
        expect(ApiService.instance.token, isNot('expired.or.garbage'));
        if (proxy != null) {
          expect(proxy!.connectsByRoom[room.id], 2, reason: '1 rejected (4401) + 1 after re-login');
        }
      } finally {
        ws.dispose();
        ApiService.instance.clearToken();
      }
    });

    test('4401 and the re-login itself fails: fatal message, not a spinner', () async {
      FlutterSecureStorage.setMockInitialValues({'device_id': 'short'}); // server: min_length=8 -> 422
      ApiService.instance.setToken('expired.or.garbage');
      final ws = WsGameRoom(roomId: 'whatever', token: 'expired.or.garbage');
      opened.add(ws);
      try {
        await until(() => ws.state.fatalError != null, why: 'fatalError after failed re-login');
        expect(ws.state.fatalError, contains('로그인이 만료'));
        expect(ws.state.connected, isFalse);
      } finally {
        ws.dispose();
        ApiService.instance.clearToken();
      }
    });

    test('4413 full room and 4403 kicked (stays kicked on reconnect)', () async {
      final o = await login('owner');
      final p2 = await login('p2');
      final p3 = await login('p3');
      final room = await asClient(o, () => RoomService.instance.createRoom(name: 'e2e-full', maxPlayers: 2, winScore: 3, roundSeconds: 10));

      connect(o, room.id);
      await until(() => o.s.connected, why: 'owner connected');
      connect(p2, room.id);
      await until(() => o.s.players.length == 2, why: 'owner sees p2');

      connect(p3, room.id);
      await until(() => p3.s.fatalError != null, why: '4413 for the third player');
      expect(p3.s.fatalError, '방 정원이 가득 찼어요');

      // owner kicks p2 (exactly what game_screen sends)
      o.room!.send({'type': 'kick', 'target_user_id': p2.userId});
      await until(() => p2.s.fatalError != null, why: 'p2 told they were kicked');
      expect(p2.s.fatalError, '방장에 의해 강퇴되었습니다');
      await until(() => !o.s.players.any((p) => p.userId == p2.userId), why: 'owner list drops p2');

      // p2 comes back with a fresh connection -> refused again with 4403
      p2.room!.dispose();
      connect(p2, room.id);
      await until(() => p2.s.fatalError != null, why: 'kick ban holds');
      expect(p2.s.fatalError, '방장에 의해 강퇴되었습니다');
    });
  });

  // ── The game ───────────────────────────────────────────────────────────

  test('3 players play a full game (answer, hint, drop+reconnect, skip, win, rematch)', () async {
    final a = await login('A');
    final b = await login('B');
    final c = await login('C');

    // create + lookup + list
    final created = await asClient(a, () => RoomService.instance.createRoom(name: 'e2e', winScore: 3, roundSeconds: 10));
    expect(created.code, hasLength(6));
    expect(created.ownerId, a.userId);
    expect(created.status, RoomStatus.waiting);
    expect(created.winScore, 3);
    expect(created.roundSeconds, 10);
    final looked = await asClient(b, () => RoomService.instance.getRoomByCode(created.code.toLowerCase()));
    expect(looked.id, created.id);
    final listed = await asClient(c, () => RoomService.instance.listRooms());
    expect(listed.map((r) => r.id), contains(created.id));
    final roomId = created.id;

    // join over WS
    connect(a, roomId);
    await until(() => a.s.connected && a.s.ownerId == a.userId, why: 'A connected, room_state parsed');
    expect(a.s.winScore, 3);
    expect(a.s.roundSeconds, 10);
    expect(a.s.roomCode, created.code);
    connect(b, roomId);
    connect(c, roomId);
    await until(() => a.s.players.length == 3 && b.s.players.length == 3 && c.s.players.length == 3,
        why: 'everyone sees 3 players');

    // only the owner may start
    b.room!.send({'type': 'start_game'});
    await until(() => b.s.chat.any((m) => m.text.contains('방장만 시작')), why: 'non-owner start rejected');
    expect(a.s.status, 'waiting');

    a.room!.send({'type': 'start_game'});
    await until(() => a.s.status == 'playing' && b.s.status == 'playing', why: 'game_start');

    Future<RoundInfo> nextRound(int n) async {
      await until(() => a.s.round?.round == n, timeout: const Duration(seconds: 25), why: 'round $n starts');
      await until(() => b.s.round?.round == n && c.s.round?.round == n, why: 'round $n reaches B and C');
      return a.s.round!;
    }

    Future<void> endedWith(int n, String reason) => until(
          () => a.s.round?.round == n && a.s.round?.ended?.reason == reason,
          why: 'round $n ends with "$reason"',
        );

    int scoreOf(Client viewer, Client who) =>
        viewer.s.players.firstWhere((p) => p.userId == who.userId).score;

    // round 1: a wrong guess is ignored, B's right answer scores
    var r = await nextRound(1);
    var answer = ans(r.prompt);
    print('[live] R1 [${r.category}] ${r.prompt} -> ${answer.first}');
    c.room!.send({'type': 'chat', 'text': '이건 절대 정답이 아닌 말 ㅋㅋ'});
    await until(() => a.s.chat.any((m) => !m.isSystem && m.userId == c.userId && m.text.contains('절대')),
        why: 'chat message parsed with its author');
    expect(a.s.round!.ended, isNull);
    b.room!.send({'type': 'chat', 'text': answer.first});
    await endedWith(1, 'correct');
    expect(a.s.round!.ended!.winnerNickname, b.nickname);
    expect(a.s.round!.ended!.answer, answer.first);
    await until(() => scoreOf(a, b) == 1, why: 'score_update: B = 1');

    // round 2: hint arrives, B's connection drops mid-round, comes back with the hint
    r = await nextRound(2);
    answer = ans(r.prompt);
    print('[live] R2 [${r.category}] ${r.prompt} -> ${answer.first}');
    expect(a.s.round!.hint, isNull);
    await until(() => a.s.round?.round == 2 && a.s.round?.hint != null,
        timeout: const Duration(seconds: 12), why: 'hint event parsed into RoundInfo.hint');
    final hint = a.s.round!.hint!;
    print('[live]   hint = $hint');
    expect(hint, isNotEmpty);
    expect(answer.map((x) => x.toLowerCase()), isNot(contains(hint.toLowerCase())),
        reason: 'the hint must not be the answer');
    expect(a.s.chat.any((m) => m.isSystem && m.text.contains(hint)), isTrue);
    await until(() => b.s.round?.hint == hint && c.s.round?.hint == hint, why: 'B and C got the hint live');

    if (proxy != null) {
      proxy!.sever(b.token);
      await until(() => !b.s.connected, why: 'B notices the drop');
      await until(() => b.s.connected && b.s.round?.round == 2,
          timeout: const Duration(seconds: 15), why: 'B auto-reconnects (backoff 1s)');
    } else {
      b.room!.dispose();
      connect(b, roomId);
      await until(() => b.s.connected && b.s.round?.round == 2, why: 'B reconnects');
    }
    expect(b.s.status, 'playing');
    expect(b.s.round!.prompt, r.prompt);
    expect(b.s.round!.hint, hint, reason: 'room_state.current.hint restores the hint after reconnect');
    expect(b.s.players, hasLength(3));
    expect(scoreOf(b, b), 1, reason: 'reconnect keeps score');

    // C answers with the last alias (exercises `accepted` matching)
    c.room!.send({'type': 'chat', 'text': answer.last});
    await endedWith(2, 'correct');
    expect(a.s.round!.ended!.winnerNickname, c.nickname);

    // round 3: skip vote (3 players -> 2 needed)
    r = await nextRound(3);
    print('[live] R3 [${r.category}] ${r.prompt} (skip)');
    a.room!.send({'type': 'skip'});
    await until(() => b.s.skipState?.votes == 1 && b.s.skipState?.needed == 2, why: 'skip_progress 1/2');
    c.room!.send({'type': 'skip'});
    await endedWith(3, 'skipped');
    expect(a.s.round!.ended!.answer, ans(r.prompt).first);

    // rounds 4..: the owner answers until the win score
    var guard = 0;
    while (a.s.finalResult == null && guard++ < 8) {
      final expected = (a.s.round?.round ?? 3) + 1;
      await until(() => a.s.finalResult != null || a.s.round?.round == expected,
          timeout: const Duration(seconds: 25), why: 'round $expected or game over');
      if (a.s.finalResult != null) break;
      r = a.s.round!;
      answer = ans(r.prompt);
      print('[live] R$expected [${r.category}] ${r.prompt} -> ${answer.first}');
      final typed = answer.first.codeUnits.every((u) => u < 128) ? answer.first.toUpperCase() : answer.first;
      a.room!.send({'type': 'chat', 'text': typed});
      await endedWith(expected, 'correct');
    }

    await until(() => a.s.finalResult != null && b.s.finalResult != null && c.s.finalResult != null,
        timeout: const Duration(seconds: 15), why: 'game_over reaches everyone');
    for (final p in [a, b, c]) {
      expect(p.s.status, 'ended');
      expect(p.s.finalResult!.winnerId, a.userId);
      final fin = {for (final s in p.s.finalResult!.scores) s.userId: s.score};
      expect(fin, {a.userId: 3, b.userId: 1, c.userId: 1});
    }
    // The server broadcasts game_over first and persists the final status right after,
    // so REST can briefly still say "playing". Poll instead of asserting instantly.
    var restStatus = RoomStatus.playing;
    for (var i = 0; i < 20 && restStatus != RoomStatus.ended; i++) {
      restStatus = (await asClient(a, () => RoomService.instance.getRoom(roomId))).status;
      if (restStatus != RoomStatus.ended) await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    expect(restStatus, RoomStatus.ended, reason: 'REST room status after game_over');

    // rematch: only the owner
    b.room!.send({'type': 'rematch'});
    await until(() => b.s.chat.any((m) => m.text.contains('방장만 리매치')), why: 'non-owner rematch rejected');
    a.room!.send({'type': 'rematch'});
    await until(() => a.s.status == 'waiting' && b.s.status == 'waiting' && c.s.status == 'waiting',
        why: 'room_state(waiting) after rematch');
    for (final p in [a, b, c]) {
      expect(p.s.finalResult, isNull);
      expect(p.s.round, isNull);
      expect(p.s.players, hasLength(3));
      expect(p.s.players.every((x) => x.score == 0), isTrue, reason: 'scores reset');
    }
    final afterRematch = await asClient(a, () => RoomService.instance.getRoom(roomId));
    expect(afterRematch.status, RoomStatus.waiting);
  }, timeout: const Timeout(Duration(seconds: 110)));
}
