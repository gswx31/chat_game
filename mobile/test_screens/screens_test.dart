// 앱 화면 스크린샷 생성기 (폰/에뮬레이터/서버 없이).
//
//   cd mobile; flutter test test_screens/screens_test.dart
//
// 앱의 "진짜" 화면 위젯을 가짜 데이터로 그려서 docs/app-guide/screens/*.png 로 저장한다.
// - 네트워크: package:http 의 MockClient 를 http.runWithClient 로 끼워서 서비스 호출에 가짜 응답을 준다.
// - 게임 소켓: WsGameRoom 을 상속한 FakeWs 로 상태(WsGameRoomState)를 직접 넣는다. 서버는 필요 없다.
// - 폰트: 테스트 기본 폰트는 한글이 네모로 나와서, Windows 의 맑은 고딕(malgun*.ttf)을
//   'Roboto' 이름으로 등록한다(앱 테마가 쓰는 기본 폰트 이름). 이모지는 Segoe UI Emoji 를 예비 폰트로.
// - 이 폴더는 test/ 가 아니라 `flutter test` 기본 실행과 CI 에는 포함되지 않는다.
//
// 데이터는 전부 가짜다(닉네임·방 이름·점수). 문제 문구만 backend/app/questions/seed_data.py 에서 가져왔다.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chat_game/core/app_theme.dart';
import 'package:chat_game/providers/auth_provider.dart';
import 'package:chat_game/providers/game_provider.dart';
import 'package:chat_game/screens/create_room_screen.dart';
import 'package:chat_game/screens/dashboard_screen.dart';
import 'package:chat_game/screens/game/game_screen.dart';
import 'package:chat_game/screens/game/result_screen.dart';
import 'package:chat_game/screens/join_room_screen.dart';
import 'package:chat_game/screens/lobby_screen.dart';
import 'package:chat_game/screens/question_sets/question_set_edit_screen.dart';
import 'package:chat_game/screens/question_sets/question_set_list_screen.dart';
import 'package:chat_game/screens/question_sets/question_set_store_screen.dart';
import 'package:chat_game/mypage/my_page_screen.dart';
import 'package:chat_game/services/ws_game_room.dart';
import 'package:chat_game/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _outDir = r'c:\Users\wooritalk\python\chatGame\docs\app-guide\screens';
const _me = 'u-minsu';

// ───────────────────────────── fonts ─────────────────────────────────────

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (!f.existsSync()) throw StateError('폰트 파일이 없어요: $p');
    loader.addFont(f.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

// ───────────────────────────── fakes ─────────────────────────────────────

/// WsGameRoom 은 만들어질 때 진짜 소켓 연결을 시도하지만, 테스트의 가짜 시계 안에서는
/// 그 결과(실패)가 도착하지 않는다. 그래서 상태를 직접 넣어도 덮어써지지 않는다.
class FakeWs extends WsGameRoom {
  FakeWs(WsGameRoomState initial) : super(roomId: 'room-1', token: 'fake') {
    state = initial;
  }
  void set(WsGameRoomState s) => state = s;
}

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(json.encode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _room(String id, String code, String name, int n,
        {int win = 20, String status = 'waiting'}) =>
    {
      'id': id,
      'code': code,
      'name': name,
      'is_public': true,
      'player_count': n,
      'max_players': 30,
      'status': status,
      'win_score': win,
      'created_at': '2026-10-23T11:00:00+09:00',
    };

Map<String, dynamic> _qset(String id, String code, String name, String desc,
        String who, List<String> tags, int plays, int items,
        {bool public = true}) =>
    {
      'id': id,
      'code': code,
      'name': name,
      'description': desc,
      'creator_id': 'u-$who',
      'creator_nickname': who,
      'is_public': public,
      'tags': tags,
      'play_count': plays,
      'item_count': items,
    };

Map<String, dynamic> _item(String id, String prompt, String answer, String cat,
        int diff, {String? hint, List<String> alt = const []}) =>
    {
      'id': id,
      'set_id': 'set-1',
      'prompt': prompt,
      'answer': answer,
      'accepted_answers': alt,
      'category': cat,
      'difficulty': diff,
      if (hint != null) 'hint': hint,
      'order': 0,
    };

final _mySets = [
  _qset('set-1', 'HIST24', '한국사 완전정복', '고조선부터 현대까지 한국사 퀴즈', '민수', ['한국사', '역사'], 128, 42,
      public: true),
  _qset('set-2', 'FAM777', '우리 가족 퀴즈', '명절에 다같이 풀어요', '민수', ['기타'], 9, 15, public: false),
  _qset('set-3', 'SCI555', '초등 과학 상식', '아이와 함께 푸는 과학', '민수', ['과학'], 31, 25),
];

final _storeSets = [
  _qset('s-10', 'KHIS88', '수능 한국사 핵심', '시대별 핵심 사건 총정리', '하늘', ['한국사', '역사'], 1520, 60),
  _qset('s-11', 'WORLD1', '세계 수도 맞히기', '195개국 수도 퀴즈', '지연', ['지리'], 980, 80),
  _qset('s-12', 'ENG100', '영어 단어 챌린지', '토익 필수 단어', '도윤', ['영어'], 640, 100),
  _qset('s-13', 'MOVIE5', '한국 영화 상식', '봉준호부터 박찬욱까지', '하늘', ['예술'], 412, 35),
  _qset('s-14', 'ITQUIZ', 'IT 용어 퀴즈', '개발자라면 다 맞힌다?', '도윤', ['IT'], 355, 40),
];

final _editDetail = {
  ..._mySets[0],
  'items': [
    _item('q1', '임진왜란이 시작된 해는?', '1592', '역사', 1, hint: '1○○○', alt: ['1592년']),
    _item('q2', '세종 때 장영실이 만든 자동 물시계의 이름은?', '자격루', '역사', 2, hint: 'ㅈㄱㄹ'),
    _item('q3', '고려 때 윤관이 여진 정벌을 위해 만든 특수 부대는?', '별무반', '역사', 3),
    _item('q4', '1950년 9월 맥아더가 지휘해 전세를 뒤집은 상륙 작전은?', '인천상륙작전', '역사', 2),
  ],
};

http.Client _mockServer() => MockClient((req) async {
      final p = req.url.path;
      if (p == '/rooms') {
        return _json([
          _room('r1', 'K7M2QX', '금요일 퀴즈방', 4),
          _room('r2', 'HIST99', '한국사 도전!', 7, win: 15),
          _room('r3', 'FAMLY2', '우리 가족 퀴즈', 3),
          _room('r4', 'NIGHT1', '야식 내기 한 판', 2, win: 10),
        ]);
      }
      if (p == '/questions/categories') {
        return _json(['역사', '과학', '지리', '스포츠', '일반상식', '문학', '예술', 'IT']);
      }
      if (p == '/question-sets/my') return _json(_mySets);
      if (p == '/question-sets/browse') return _json(_storeSets);
      if (p == '/question-sets/set-1') return _json(_editDetail);
      return _json({'detail': 'not faked: $p'}, 404);
    });

// ───────────────────────────── game states ───────────────────────────────

double _nowPlus(int sec) => DateTime.now().millisecondsSinceEpoch / 1000 + sec;

List<PlayerInfo> _players({Map<String, int> scores = const {}}) => [
      PlayerInfo(userId: _me, nickname: '민수', score: scores['민수'] ?? 0),
      PlayerInfo(userId: 'u-jiyeon', nickname: '지연', score: scores['지연'] ?? 0),
      PlayerInfo(userId: 'u-haneul', nickname: '하늘', score: scores['하늘'] ?? 0),
      PlayerInfo(userId: 'u-doyoon', nickname: '도윤', score: scores['도윤'] ?? 0),
    ];

int _id = 0;
ChatMsg _chat(String who, String text, {String? uid}) => ChatMsg(
    id: ++_id,
    userId: uid ?? 'u-$who',
    nickname: who,
    text: text,
    timestamp: DateTime(2026, 10, 23, 12, 0, _id).millisecondsSinceEpoch);
ChatMsg _sys(String text) => ChatMsg(
    id: ++_id,
    nickname: 'system',
    text: text,
    isSystem: true,
    timestamp: DateTime(2026, 10, 23, 12, 0, _id).millisecondsSinceEpoch);

WsGameRoomState _lobbyState() => WsGameRoomState(
      connected: true,
      status: 'waiting',
      ownerId: _me,
      winScore: 20,
      roundSeconds: 30,
      roomName: '금요일 퀴즈방',
      roomCode: 'K7M2QX',
      players: _players(),
      chat: [_sys('지연 님이 입장했습니다'), _sys('하늘 님이 입장했습니다'), _sys('도윤 님이 입장했습니다')],
    );

WsGameRoomState _gameState({String? hint, RoundResult? ended, int sec = 21}) {
  final scores = {'민수': 3, '지연': 5, '하늘': 4, '도윤': 1};
  if (ended != null) scores['하늘'] = 5;
  return WsGameRoomState(
    connected: true,
    status: 'playing',
    ownerId: _me,
    winScore: 20,
    roundSeconds: 30,
    roomName: '금요일 퀴즈방',
    roomCode: 'K7M2QX',
    players: _players(scores: scores),
    round: RoundInfo(
      round: 13,
      prompt: '임진왜란이 시작된 해는?',
      category: '역사',
      difficulty: 1,
      deadlineTs: _nowPlus(sec),
      hint: hint,
      ended: ended,
    ),
    chat: [
      _sys('라운드 13 시작!'),
      _chat('지연', '1597?'),
      _chat('도윤', '1598 아닌가'),
      _chat('민수', '앗 헷갈려', uid: _me),
      if (hint != null) _sys('💡 힌트: $hint'),
      if (hint != null && ended == null) _chat('지연', '1590?'),
      if (ended != null) _chat('하늘', '1592'),
      if (ended != null) _sys('✅ ${ended.winnerNickname} 님 정답! (${ended.answer})'),
    ],
  );
}

// ───────────────────────────── harness ───────────────────────────────────

class _Scenario {
  _Scenario(
    this.file,
    this.build, {
    this.overrides = const [],
    this.size = const Size(390, 844),
    this.interact,
    this.settleMs = 1200,
    this.tight = false,
  });
  final String file;
  final Widget Function() build;
  final List<Override> overrides;
  final Size size;
  final Future<void> Function(WidgetTester t)? interact;
  final int settleMs;

  /// 줄 간격을 줄여 그린다. 게임 화면의 점수판 카드(lib/game/widgets/mini_scoreboard.dart:86)는
  /// 본문 줄 높이 때문에 5px 넘쳐서, 디버그 전용 빨간 줄무늬가 스크린샷에 찍힌다.
  final bool tight;
}

List<Override> _baseOverrides({FakeWs? ws}) => [
      currentUidProvider.overrideWithValue(_me),
      memberProfileProvider
          .overrideWith((ref, _) async => {'displayName': '민수', 'photoURL': ''}),
      if (ws != null) wsGameRoomProvider.overrideWith((ref, id) => ws),
    ];

const _fallback = ['AppKorean', 'AppEmoji'];

TextStyle _withFont(TextStyle? s) => (s ?? const TextStyle())
    .copyWith(fontFamily: 'Roboto', fontFamilyFallback: _fallback);

/// M3 의 기본 본문 줄 높이(1.43)는 ThemeData 에 값으로 들어 있지 않고 위젯이 채워 넣는다.
/// 그래서 배율이 아니라 bodyMedium 에 직접 줄 높이를 준다. (tight 일 때만)
TextTheme _tighten(TextTheme t, bool tight) => tight
    ? t.copyWith(
        bodyMedium: (t.bodyMedium ?? const TextStyle()).copyWith(height: 1.05))
    : t;

Widget _app(GlobalKey key, Widget screen, List<Override> overrides,
    {bool tight = false}) {
  final base = AppTheme.theme;
  final appBarTitle = base.appBarTheme.titleTextStyle ?? const TextStyle();
  final theme = base.copyWith(
    textTheme: _tighten(
        base.textTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: _fallback),
        tight),
    primaryTextTheme:
        base.primaryTextTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: _fallback),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: _withFont(appBarTitle),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: base.elevatedButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
            _withFont(base.elevatedButtonTheme.style?.textStyle?.resolve({}))),
      ),
    ),
    snackBarTheme: base.snackBarTheme
        .copyWith(contentTextStyle: _withFont(base.snackBarTheme.contentTextStyle)),
    chipTheme: base.chipTheme.copyWith(labelStyle: _withFont(base.chipTheme.labelStyle)),
  );
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => screen),
    GoRoute(path: '/:any(.*)', builder: (_, __) => const SizedBox()),
  ]);
  return RepaintBoundary(
    key: key,
    child: ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: theme,
        routerConfig: router,
      ),
    ),
  );
}

Future<void> _settle(WidgetTester t, int ms) async {
  // 실제 비동기(이미지 디코딩 등)를 한 번 흘려보내고, 가짜 시계를 앞으로 돌린다.
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await t.pump(const Duration(milliseconds: 50));
}

Future<void> _show(WidgetTester t, _Scenario s, GlobalKey key,
    {Size? size, bool status = true, bool? tight}) async {
  final sz = size ?? s.size;
  t.view.devicePixelRatio = 2.5;
  t.view.physicalSize = Size(sz.width * 2.5, sz.height * 2.5);
  if (status) t.view.padding = const FakeViewPadding(top: 60); // 상태 표시줄 24dp
  addTearDown(t.view.reset);

  await t.pumpWidget(_app(key, s.build(), s.overrides, tight: tight ?? s.tight));
  await _settle(t, s.settleMs);
  if (s.interact != null) await s.interact!(t);
}

Future<void> _snap(WidgetTester t, GlobalKey key, String file) async {
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir\\$file').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// 화면을 내리면서 정리한다 — 화면이 가진 타이머/구독이 테스트 끝까지 남지 않게.
Future<void> _unmount(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 6));
}

// ───────────────────────────── scenarios ─────────────────────────────────

/// 파일 이름 -> 시나리오 공장. FakeWs 는 소켓 연결을 시도하므로 테스트 안에서만 만든다.
FakeWs? correctWs; // 07 번 시나리오가 interact 에서 상태를 바꾼다

final Map<String, _Scenario Function()> _factories = {
    '01-home.png': () => _Scenario('01-home.png', () => const DashboardScreen(),
        overrides: _baseOverrides()),
    '02-create-room.png': () => _Scenario('02-create-room.png', () => const CreateRoomScreen(),
        overrides: _baseOverrides(),
        size: const Size(390, 1250),
        interact: (t) async {
          await t.enterText(find.byType(TextFormField).first, '금요일 퀴즈방');
          for (final c in ['역사', '과학']) {
            await t.tap(find.text(c).first);
            await t.pump(); // 애니메이션 시작 프레임
            await t.pump(const Duration(milliseconds: 600));
          }
        }),
    '03-join-room.png': () => _Scenario('03-join-room.png', () => const JoinRoomScreen(),
        overrides: _baseOverrides()),
    '04-lobby.png': () => _Scenario('04-lobby.png', () => const LobbyScreen(roomId: 'room-1'),
        overrides: _baseOverrides(ws: FakeWs(_lobbyState()))),
    '05-game-question.png': () => _Scenario('05-game-question.png', () => const GameScreen(roomId: 'room-1'),
        overrides: _baseOverrides(ws: FakeWs(_gameState())), settleMs: 300, tight: true),
    '06-game-hint.png': () => _Scenario('06-game-hint.png', () => const GameScreen(roomId: 'room-1'),
        overrides: _baseOverrides(ws: FakeWs(_gameState(hint: '1○○○', sec: 12))), settleMs: 300, tight: true),
    '07-game-correct.png': () => _Scenario('07-game-correct.png', () => const GameScreen(roomId: 'room-1'),
        overrides: _baseOverrides(ws: correctWs = FakeWs(_gameState(hint: '1○○○', sec: 9))),
        settleMs: 300,
        tight: true,
        interact: (t) async {
          // 같은 화면에서 상태만 "정답 처리됨"으로 바꾸면 앱이 스스로 축하 오버레이를 띄운다.
          correctWs!.set(_gameState(
            hint: '1○○○',
            sec: 9,
            ended: const RoundResult(
                reason: 'correct', answer: '1592', winnerNickname: '하늘'),
          ));
          await t.pump(const Duration(milliseconds: 500));
        }),
    '08-result.png': () => _Scenario(
        '08-result.png',
        () => ResultScreen(roomId: 'room-1', users: [
              for (final p in _players(
                  scores: {'민수': 14, '지연': 20, '하늘': 17, '도윤': 9}))
                {
                  'uid': p.userId,
                  'displayName': p.nickname,
                  'photoURL': '',
                  'score': p.score,
                }
            ]),
        overrides: _baseOverrides(
            ws: FakeWs(WsGameRoomState(
          connected: true,
          status: 'ended',
          ownerId: _me,
          roomName: '금요일 퀴즈방',
          roomCode: 'K7M2QX',
          players: _players(scores: {'민수': 14, '지연': 20, '하늘': 17, '도윤': 9}),
        ))),
        settleMs: 1500),
    '09-my-maps.png': () => _Scenario('09-my-maps.png', () => const QuestionSetListScreen(),
        overrides: _baseOverrides()),
    '10-add-question.png': () => _Scenario('10-add-question.png',
        () => const QuestionSetEditScreen(setId: 'set-1'),
        overrides: _baseOverrides(),
        size: const Size(390, 1250),
        interact: (t) async {
          await t.tap(find.text('문제 추가'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 600));
          final fields = find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(TextField));
          await t.enterText(fields.at(0), '세종 때 장영실이 만든 자동 물시계의 이름은?');
          await t.enterText(fields.at(1), '자격루');
          await t.enterText(fields.at(2), '자격루 물시계, 물시계');
          await t.enterText(fields.last, 'ㅈㄱㄹ');
          // 카테고리 드롭다운을 열어 '역사' 선택
          await t.tap(find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(DropdownButtonFormField<String>)));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          await t.tap(find.text('역사').last);
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
        }),
    '11-map-store.png': () => _Scenario('11-map-store.png', () => const QuestionSetStoreScreen(),
        overrides: _baseOverrides()),
    '12-my-page.png': () => _Scenario('12-my-page.png', () => const MyPageScreen(),
        overrides: _baseOverrides()),
    '13-settings.png': () => _Scenario('13-settings.png', () => const SettingsScreen(),
        overrides: _baseOverrides()),
};

// ───────────────────────────── tests ─────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Directory(_outDir).createSync(recursive: true);
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk == null) throw StateError('FLUTTER_ROOT 가 없어요 (flutter test 로 실행하세요)');
    final mf = '$sdk/bin/cache/artifacts/material_fonts';
    // 라틴 문자·숫자는 폰과 같은 Roboto, 아이콘은 MaterialIcons, 한글은 맑은 고딕, 이모지는 Segoe.
    await _loadFont('Roboto', ['$mf/roboto-regular.ttf', '$mf/roboto-medium.ttf', '$mf/roboto-bold.ttf']);
    await _loadFont('MaterialIcons', ['$mf/materialicons-regular.otf']);
    await _loadFont('AppKorean', [r'C:\Windows\Fonts\malgun.ttf', r'C:\Windows\Fonts\malgunbd.ttf']);
    await _loadFont('AppEmoji', [r'C:\Windows\Fonts\seguiemj.ttf']);
    // 방 코드 등에 앱이 fontFamily: 'monospace' 를 직접 쓴다.
    await _loadFont('monospace', [r'C:\Windows\Fonts\consola.ttf', r'C:\Windows\Fonts\consolab.ttf']);
  });

  final names = _factories.keys.toList();

  for (var i = 0; i < names.length; i++) {
    testWidgets('screenshot ${names[i]}', (t) async {
      final s = _factories[names[i]]!();
      final key = GlobalKey();
      // flutter_test 는 그림자를 단색 검은 테두리로 그린다(FAB, 슬라이더 손잡이).
      // 실제 앱처럼 번지게 이 테스트 동안만 끄고, 끝나기 전에 원래대로 돌려놓는다(검증 규칙).
      debugDisableShadows = false;
      try {
        await http.runWithClient(() async {
          await _show(t, s, key);
          await _snap(t, key, s.file);
          await _unmount(t);
        }, _mockServer);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  // 작은 폰(360x640)에서 넘치는 곳이 있는지: PNG 는 저장하지 않고 오류만 모은다.
  testWidgets('small phone 360x640 overflow report', (t) async {
    final report = StringBuffer('작은 폰 360x640 에서 발견한 레이아웃 문제\n');
    var problems = 0;
    final original = FlutterError.onError;
    for (var i = 0; i < names.length; i++) {
      final s = _factories[names[i]]!();
      final errors = <String>[];
      FlutterError.onError = (d) {
        final msg = d.exceptionAsString().split('\n').first;
        errors.add('$msg ${d.stack?.toString().split('\n').firstWhere((l) => l.contains('/lib/'), orElse: () => '') ?? ''}');
      };
      final key = GlobalKey();
      try {
        await http.runWithClient(() async {
          await _show(t, s, key, size: const Size(360, 640), tight: false);
          await _unmount(t);
        }, _mockServer);
      } catch (e) {
        errors.add('EXCEPTION $e');
      } finally {
        FlutterError.onError = original;
      }
      final uniq = errors.toSet().toList();
      problems += uniq.length;
      report.writeln('\n[${s.file}] ${uniq.isEmpty ? "OK" : "${uniq.length}건"}');
      for (final e in uniq) {
        report.writeln('  - $e');
      }
    }
    File('$_outDir\\_small-phone-report.txt')
        .writeAsStringSync(report.toString());
    // ignore: avoid_print
    print(report);
    expect(problems >= 0, isTrue);
  });
}
