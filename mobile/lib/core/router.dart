import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/dashboard_screen.dart';
import '../screens/create_room_screen.dart';
import '../screens/join_room_screen.dart';
import '../screens/history_screen.dart';
import '../screens/lobby_screen.dart';
import '../screens/game/game_screen.dart';
import '../screens/game/result_screen.dart';
import '../screens/question_sets/question_set_list_screen.dart';
import '../screens/question_sets/question_set_edit_screen.dart';
import '../screens/question_sets/question_set_store_screen.dart';
import '../mypage/my_page_screen.dart';
import '../settings_screen.dart';

class Routes {
  static const dashboard = '/';
  static const createRoom = '/room/create';
  static const joinRoom = '/room/join';
  static const history = '/history';
  static String lobby(String roomId) => '/room/$roomId/lobby';
  static String game(String roomId) => '/room/$roomId/game';
  static String result(String roomId) => '/room/$roomId/result';
  static const myPage = '/profile';
  static const settings = '/settings';
  static const questionSets = '/question-sets';
  static const questionSetCreate = '/question-sets/new';
  static const questionSetStore = '/question-sets/store';
  static String questionSetEdit(String id) => '/question-sets/$id';
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.dashboard,
    routes: [
      GoRoute(
        path: Routes.dashboard,
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: Routes.createRoom,
        builder: (_, __) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: Routes.joinRoom,
        builder: (_, __) => const JoinRoomScreen(),
      ),
      GoRoute(
        path: '/room/:roomId/lobby',
        builder: (_, state) {
          final roomId = state.pathParameters['roomId']!;
          return LobbyScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/room/:roomId/game',
        builder: (_, state) {
          final roomId = state.pathParameters['roomId']!;
          return GameScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/room/:roomId/result',
        builder: (_, state) {
          final roomId = state.pathParameters['roomId']!;
          final users = state.extra as List<Map<String, dynamic>>? ?? [];
          return ResultScreen(roomId: roomId, users: users);
        },
      ),
      GoRoute(
        path: Routes.history,
        builder: (_, __) => const HistoryScreen(),
      ),
      GoRoute(
        path: Routes.myPage,
        builder: (_, __) => const MyPageScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.questionSets,
        builder: (_, __) => const QuestionSetListScreen(),
      ),
      GoRoute(
        path: Routes.questionSetCreate,
        builder: (_, __) => const QuestionSetEditScreen(),
      ),
      GoRoute(
        path: Routes.questionSetStore,
        builder: (_, __) => const QuestionSetStoreScreen(),
      ),
      GoRoute(
        path: '/question-sets/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return QuestionSetEditScreen(setId: id);
        },
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('페이지를 찾을 수 없습니다: ${state.error}')),
    ),
  );
}
