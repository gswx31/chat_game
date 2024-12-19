import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:chat_game/game/result_screen.dart';
import '../../dashboard_screen.dart';
import '../../firebase/firestore_service.dart';
import '../handlers/message_handler.dart';
import '../handlers/question_handler.dart';
import '../handlers/user_status_handler.dart';
import '../widgets/message_list.dart';
import '../widgets/user_list.dart';
import '../widgets/question_display.dart';

class ChatGameScreen extends StatefulWidget {
  final String roomId;
  const ChatGameScreen({required this.roomId});

  @override
  _ChatGameScreenState createState() => _ChatGameScreenState();
}

class _ChatGameScreenState extends State<ChatGameScreen> with WidgetsBindingObserver {
  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;
  late FirebaseDatabase _database;
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  late AudioPlayer _audioPlayer;
  late UserStatusHandler _userStatusHandler;
  Timer? _inactivityTimer;
  Timer? _questionTimer;

  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> questions = [];

  String? _currentUserId;
  bool _questionAnswered = false;
  bool _skipDisabled = false;

  int currentQuestionIndex = 0;
  int _skipVotes = 0;

  String? answerMessage;
  String? currentAnswer;
  String? initialHint; // 초성 힌트

  final MessageHandler _messageHandler = MessageHandler();
  final QuestionHandler _questionHandler = QuestionHandler();

  bool _isFirstLaunch = true;
  int _remainingTime = 40; // 타이머 초기 설정 (40초)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _database = FirebaseDatabase.instance;
    _audioPlayer = AudioPlayer();
    _userStatusHandler = UserStatusHandler(
      onLeaveRoomCallback: () => showLeaveRoomDialog(),
    );

    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _currentUserId = _auth.currentUser?.uid ?? '';

    _checkUserStatus();  // 사용자 상태를 확인

    // Firebase에서 타이머 값 읽기 및 타이머 시작
    _database.ref('rooms/${widget.roomId}/timer').onValue.listen((event) {
      final timerValue = event.snapshot.value as int?;
      if (timerValue != null && timerValue >= 0) {
        setState(() {
          _remainingTime = timerValue;
        });
        if (_questionTimer == null || !_questionTimer!.isActive) {
          _startQuestionTimer(); // 타이머가 없는 경우 새로 시작
        }
      }
    });
  }

  void showLeaveRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('연결 끊김'),
        content: Text('장기간 접속이 없어 방에서 나가졌습니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
            child: Text('확인'),
          ),
        ],
      ),
    );
  }
  void _checkUserStatus() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      final userRef = _firestore.collection('rooms').doc(widget.roomId).collection('users').doc(_currentUserId);
      final userSnapshot = await userRef.get();

      if (userSnapshot.exists && !(userSnapshot.data()?['isOnline'] ?? true)) {
        // 사용자가 오프라인 상태라면 로비 화면으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      } else {
        _initializeGame();  // 온라인 상태라면 게임 초기화
      }
    }
  }

  @override
  void dispose() {
    print("Disposing ChatGameScreen");
    _inactivityTimer?.cancel();
    _questionTimer?.cancel();
    _userStatusHandler.setUserOffline(widget.roomId);
    _audioPlayer.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // 앱이 백그라운드로 전환될 때
      _userStatusHandler.startBackgroundTimer(widget.roomId);
    } else if (state == AppLifecycleState.resumed) {
      // 앱이 다시 활성화될 때
      _userStatusHandler.cancelBackgroundTimer();
    } else if (state == AppLifecycleState.detached) {
      // 앱이 완전히 종료될 때
      _userStatusHandler.leaveRoom(widget.roomId);
    }
  }


  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: 1), () {
      _setUserOffline();
      _leaveRoom();
    });
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
  }

  void _initializeGame() {
    print("Initializing game, setting up user status listener.");

    if (!_userStatusHandler.isListenerSetup) {
      _setupUserStatusListener();
    } else {
      print("User status listener already set up.");
    }

    _listenToMessages();
    _listenToUsers();
    _loadQuestions();
    _listenToRoomUpdates();

    _setUserOnline();
  }

  void _setUserOnline() async {
    print("Setting user online");
    await _userStatusHandler.setUserOnline(widget.roomId);
  }

  void _setUserOffline() async {
    print("Setting user offline");
    await _userStatusHandler.setUserOffline(widget.roomId);
  }

  void _setupUserStatusListener() {
    if (!_userStatusHandler.isListenerSetup) {
      print("Setting up user status listener");
      _userStatusHandler.setupUserStatusListener(widget.roomId);
    } else {
      print("User status listener already set up.");
    }
  }

  void _listenToMessages() {
    _database.ref('rooms/${widget.roomId}/messages')
        .orderByChild('timestamp').onValue.listen((event) {
      final data = (event.snapshot.value as Map<dynamic, dynamic>?) ?? {};
      final sortedMessages = data.entries.map((e) => Map<String, dynamic>.from(e.value)).toList()
        ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
      setState(() {
        messages = sortedMessages;
      });
      _scrollToBottom();
    });
  }

  void _listenToUsers() {
    _firestore.collection('rooms').doc(widget.roomId).collection('users')
        .snapshots().listen((snapshot) async {
      List<Map<String, dynamic>> updatedUsers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final memberDoc = await _firestore.collection('members').doc(doc.id).get();
        final memberData = memberDoc.data() as Map<String, dynamic>;

        updatedUsers.add({
          'uid': doc.id,
          'displayName': memberData['displayName'] ?? 'Unknown',
          'photoURL': memberData['photoURL'],
          'isOnline': data['isOnline'] == true,
          'score': data['score'] ?? 0,
        });
      }

      setState(() {
        users = updatedUsers;
      });

      for (var user in snapshot.docChanges) {
        if (user.type == DocumentChangeType.removed) {
          final userData = user.doc.data() as Map<String, dynamic>;
          final userName = userData['displayName'] ?? 'Unknown';
          _messageHandler.sendMessage(widget.roomId, '$userName 님이 나갔습니다.');
        }
      }
    });
  }

  void _loadQuestions() {
    _questionHandler.loadQuestions(widget.roomId).then((_) {
      setState(() {
        questions = _questionHandler.questions;
        currentAnswer = _questionHandler.currentAnswer;
      });
      _startQuestionTimer(); // 타이머 시작
    });
  }

  void _listenToRoomUpdates() {
    _firestore.collection('rooms').doc(widget.roomId).snapshots().listen((snapshot) {
      if (mounted && snapshot.exists) {
        setState(() {
          currentQuestionIndex = (snapshot.data() as Map<String, dynamic>)['currentQuestionIndex'] ?? 0;
          if (!_questionAnswered) {
            currentAnswer = questions.isNotEmpty ? questions[currentQuestionIndex]['answer'] : null;
            answerMessage = (snapshot.data() as Map<String, dynamic>)['correctAnswer'];
          }
        });
      }
    });
  }

  void _scrollToBottom({bool animated = false}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      return;
    }
    String messageText = _messageController.text.trim();
    _messageController.clear();
    await _messageHandler.sendMessage(widget.roomId, messageText);

    if (!_questionAnswered && messageText == currentAnswer) {
      await _handleCorrectAnswer(_currentUserId ?? '');
    }

    // 메시지를 보낸 후 스크롤을 아래로 이동
    _scrollToBottom(animated: true);
  }

  Future<void> _handleCorrectAnswer(String userId) async {
    final DocumentReference roomRef = _firestore.collection('rooms').doc(widget.roomId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot roomSnapshot = await transaction.get(roomRef);

      if (roomSnapshot.exists) {
        final data = roomSnapshot.data() as Map<String, dynamic>;

        // 이미 누군가 정답을 맞췄는지 확인
        bool isAlreadyAnswered = data['lastAnswer'] != null;

        if (!isAlreadyAnswered) {
          // 첫 번째로 정답을 맞춘 사람임을 확인한 경우에만 점수를 업데이트
          transaction.update(roomRef, {
            'lastAnswer': userId, // 정답을 맞춘 사용자의 ID 기록
            'correctAnswer': '정답: ${questions[currentQuestionIndex]['answer']}', // 정답 저장
          });

          final userRef = roomRef.collection('users').doc(userId);
          DocumentSnapshot userSnapshot = await transaction.get(userRef);

          if (userSnapshot.exists) {
            int currentScore = (userSnapshot.data() as Map<String, dynamic>)['score'] ?? 0;
            transaction.update(userRef, {'score': currentScore + 1});
          }

          setState(() {
            _questionAnswered = true;
            answerMessage = '${getSenderName(userId)}님이 정답을 맞추셨습니다!\n정답: ${questions[currentQuestionIndex]['answer']}';
          });

          _messageHandler.playCorrectAnswerSound();

          // 2초 뒤에 다음 문제로 넘어가도록 설정
          Future.delayed(Duration(seconds: 2), () {
            _transitionToNextQuestion();
          });
        }
      }
    });
  }


  void _skipQuestion() async {
    if (_skipDisabled) return;

    final userRef = _firestore
        .collection('rooms')
        .doc(widget.roomId)
        .collection('users')
        .doc(_currentUserId);

    DocumentSnapshot userSnapshot = await userRef.get();

    if (userSnapshot.exists) {
      bool hasVoted = (userSnapshot.data() as Map<String, dynamic>)['hasVoted'] ?? false;
      if (hasVoted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이미 투표하셨습니다.'))
        );
        return;
      } else {
        // 사용자가 투표하지 않았다면 투표 처리
        await userRef.update({'hasVoted': true});
        setState(() {
          _skipVotes++;
        });
      }
    }

    // 온라인 유저 수 계산
    int onlineUsers = users.where((user) => user['isOnline'] == true).length;

    // 스킵 투표가 절반 이상일 경우 문제를 건너뜀
    if (_skipVotes >= (onlineUsers / 2).ceil()) {
      _disableSkipButton();
      await _firestore.collection('rooms').doc(widget.roomId).update({
        'skipVotes': FieldValue.increment(1),
        'correctAnswer': '문제가 건너뛰어졌습니다.\n정답: $currentAnswer'
      });

      await Future.delayed(Duration(seconds: 2));
      _resetVotes();
      _transitionToNextQuestion();
    } else {
      final votesNeeded = (onlineUsers / 2).ceil();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('현재 $_skipVotes표 / $votesNeeded표'))
      );
    }
  }

  void _resetVotes() async {
    final roomRef = _firestore.collection('rooms').doc(widget.roomId);
    final usersRef = roomRef.collection('users');

    final batch = _firestore.batch();

    QuerySnapshot usersSnapshot = await usersRef.get();
    for (var doc in usersSnapshot.docs) {
      batch.update(doc.reference, {'hasVoted': false});
    }

    await batch.commit();

    await roomRef.update({'skipVotes': 0});

    setState(() {
      _skipVotes = 0;
    });
  }

  Future<void> _transitionToNextQuestion() async {
    int newIndex = (currentQuestionIndex + 1) % questions.length;

    // Reset the correctAnswer field when moving to the next question
    await _firestore.collection('rooms').doc(widget.roomId).update({
      'correctAnswer': null,
    });

    await _questionHandler.updateCurrentQuestionIndex(widget.roomId, newIndex);
    setState(() {
      _questionAnswered = false;
      answerMessage = null;
      _skipVotes = 0;
      currentAnswer = questions.isNotEmpty ? questions[newIndex]['answer'] : null;
      initialHint = null;
    });
    _enableSkipButton();
    _startQuestionTimer(); // 모든 사용자의 타이머를 재설정

    if (newIndex == 0 || _checkGameEndCondition()) {
      _endGame();
    }
  }


  void _startQuestionTimer() {
    if (_questionTimer != null) {
      _questionTimer!.cancel();
    }

    // 타이머 값을 Firebase Realtime Database에 저장
    final timerRef = _database.ref('rooms/${widget.roomId}/timer');
    timerRef.set(40);

    _questionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _remainingTime--;

      // Firebase에 타이머 값을 업데이트
      timerRef.set(_remainingTime);

      setState(() {
        // 로컬 상태를 업데이트
      });

      if (_remainingTime == 20 && initialHint == null) {
        initialHint = extractInitials(currentAnswer ?? '');
      }

      if (_remainingTime <= 0) {
        timer.cancel();
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    setState(() {
      answerMessage = '시간 초과! 정답: $currentAnswer';
      _questionAnswered = true;
    });

    // 타이머가 종료되었을 때 Firebase 타이머 값을 초기화
    _database.ref('rooms/${widget.roomId}/timer').set(40);

    // 타이머가 종료되었을 때 다음 질문으로 넘어가는 로직
    Future.delayed(Duration(seconds: 2), () {
      _transitionToNextQuestion();
    });
  }


  bool _checkGameEndCondition() {
    final int targetScore = 1000000;
    for (var user in users) {
      if (user['score'] >= targetScore) {
        return true;
      }
    }
    return false;
  }

  void _endGame() async {
    final userId = _auth.currentUser?.uid;
    await FirestoreService().moveRoomToHistory(widget.roomId);
    _saveGameHistory();
    _setRoomEndStatus();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(users: users, roomId: widget.roomId),
      ),
    );
  }



  Future<void> _leaveRoom() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final roomRef = _firestore.collection('rooms').doc(widget.roomId);
    final userRef = roomRef.collection('users').doc(userId);

    try {
      await userRef.delete();

      final userStatusRef = _database.ref('status/${widget.roomId}/$userId');
      await userStatusRef.remove();

      DocumentSnapshot roomSnapshot = await roomRef.get();
      if (roomSnapshot.exists && roomSnapshot['owner'] == userId) {
        QuerySnapshot userSnapshot = await roomRef.collection('users').orderBy('joinedAt').limit(1).get();
        if (userSnapshot.docs.isNotEmpty) {
          await roomRef.update({'owner': userSnapshot.docs.first.id});
        }
      }

      if (!mounted) return;
    } catch (e) {
      print('방을 나가는 중 오류 발생: $e');
    }
  }

  void _disableSkipButton() {
    setState(() {
      _skipDisabled = true;
    });
  }

  void _enableSkipButton() {
    setState(() {
      _skipDisabled = false;
    });
  }

  void _saveGameHistory() async {
    if (_currentUserId == null) return;

    final roomRef = _firestore.collection('rooms').doc(widget.roomId);
    final roomSnapshot = await roomRef.get();

    if (!roomSnapshot.exists) return;

    final gameHistoryRef = _firestore.collection('game_history').doc(widget.roomId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot gameHistorySnapshot = await transaction.get(gameHistoryRef);
      List<dynamic> games = gameHistorySnapshot.exists ? (gameHistorySnapshot.data() as Map<String, dynamic>)['games'] : [];
      games.add({
        'timestamp': DateTime.now(),
        'roomId': widget.roomId,
        'roomName': (roomSnapshot.data() as Map<String, dynamic>)['roomName'],
        'players': users,
      });
      transaction.set(gameHistoryRef, {'games': games});
    });
  }

  void _setRoomEndStatus() {
    _firestore.collection('rooms').doc(widget.roomId).update({'endedAt': DateTime.now()});
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('나가기'),
        content: Text('정말 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _leaveRoom();
              Navigator.of(context).pop(true);
            },
            child: Text('나가기'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _removeExtraUsers() {
    users.sort((a, b) => a['isOnline'] ? -1 : 1);
    while (users.length > 8) {
      final user = users.removeLast();
      _firestore.collection('rooms').doc(widget.roomId).collection('users').doc(user['uid']).delete();
    }
  }

  String getSenderName(String senderId) {
    final sender = users.firstWhere((user) => user['uid'] == senderId, orElse: () => {});
    return sender.isNotEmpty ? sender['displayName'] ?? 'Unknown' : 'Unknown';
  }

  String getSenderPhotoUrl(String senderId) {
    final sender = users.firstWhere((user) => user['uid'] == senderId, orElse: () => {});
    return sender.isNotEmpty ? sender['photoURL'] ?? '' : '';
  }

  String formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm:ss.SSS').format(dateTime);
  }

  String extractInitials(String text) {
    const Map<String, String> initialsMap = {
      '가': 'ㄱ', '나': 'ㄴ', '다': 'ㄷ', '라': 'ㄹ', '마': 'ㅁ', '바': 'ㅂ', '사': 'ㅅ',
      '아': 'ㅇ', '자': 'ㅈ', '차': 'ㅊ', '카': 'ㅋ', '타': 'ㅌ', '파': 'ㅍ', '하': 'ㅎ',
      // Add more mappings as needed
    };

    return text.split('').map((char) {
      String initial = initialsMap[char] ?? char;
      return initial;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _showExitConfirmationDialog,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.roomId}'),
          actions: [
            IconButton(
              icon: Icon(Icons.list),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return UserList(users: users);
                  },
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.skip_next),
              onPressed: _skipDisabled ? null : _skipQuestion,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                if (questions.isNotEmpty)
                  QuestionDisplay(
                    question: questions[currentQuestionIndex]['question'],
                    answerMessage: answerMessage,
                    remainingQuestions: questions.length - currentQuestionIndex - 1,
                    skipVotes: _skipVotes,
                    remainingTime: _remainingTime, // 타이머 전달
                    initialHint: initialHint, // 초성 힌트 전달
                  ),
                Expanded(
                  child: MessageList(
                    messages: messages,
                    currentUserId: _currentUserId,
                    scrollController: _scrollController,
                    getSenderName: getSenderName,
                    getSenderPhotoUrl: getSenderPhotoUrl,
                    formatTimestamp: formatTimestamp,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: '메시지를 입력하세요...',
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                          ),
                          onTap: () {
                            // 입력창을 탭할 때 최근 메시지로 스크롤 이동
                            _scrollToBottom(animated: true);
                          },
                          onChanged: (text) {
                            // 입력창에 글씨를 입력할 때마다 스크롤 이동
                            _scrollToBottom(animated: true);
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        resizeToAvoidBottomInset: true, // 키보드가 열리면 화면이 조정되도록 설정
      ),
    );
  }

}