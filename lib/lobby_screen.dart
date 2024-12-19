import 'dart:async';
import 'package:chat_game/game/screens/chat_game_screen.dart';
import 'package:chat_game/profile_image_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dashboard_screen.dart';
import 'game/handlers/user_status_handler.dart';

class LobbyScreen extends StatefulWidget {
  final String roomId;

  const LobbyScreen({required this.roomId});

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  late UserStatusHandler _userStatusHandler;
  bool isRoomOwner = false;
  bool isLoading = true;
  List<Map<String, dynamic>> users = [];
  StreamSubscription<DocumentSnapshot>? roomStatusSubscription;
  StreamSubscription<QuerySnapshot>? usersSubscription;
  Timer? _inactiveTimer;
  bool _isFirstLaunch = true;
  Timer? _roomTimeoutTimer;
  StreamSubscription<DocumentSnapshot>? ownerStatusSubscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 생명주기 옵저버 추가
    _userStatusHandler = UserStatusHandler();
    _loadRoomData();
    _listenToRoomStatus();
    _listenToUsers();
    _setInitialUserStatus();
    _listenToOwnerChanges(); // 방장 변경 리스너 설정
  }

  @override
  void dispose() {
    roomStatusSubscription?.cancel();
    usersSubscription?.cancel();
    ownerStatusSubscription?.cancel(); // 리스너 해제
    _inactiveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _userStatusHandler.setUserOffline(widget.roomId);
    super.dispose();
  }
  void _listenToOwnerChanges() {
    ownerStatusSubscription = _firestore.collection('rooms').doc(widget.roomId).snapshots().listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        bool newIsRoomOwner = snapshot.data()?['owner'] == _auth.currentUser?.uid;
        if (isRoomOwner != newIsRoomOwner) {
          setState(() {
            isRoomOwner = newIsRoomOwner;
          });
        }
      }
    });
  }

  void _setInitialUserStatus() async {
    // 처음 진입 시 온라인 상태 설정
    await _userStatusHandler.setUserOnline(widget.roomId);
    _userStatusHandler.setupUserStatusListener(widget.roomId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isFirstLaunch) {
      _isFirstLaunch = false;
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        print("App is going to background, setting user away");
        _userStatusHandler.setUserAway(widget.roomId);
        _startInactiveTimer();
        break;
      case AppLifecycleState.resumed:
        print("App is resumed, setting user online");
        _handleAppResumed();
        break;
      case AppLifecycleState.detached:
        print("App is detached, setting user offline");
        _userStatusHandler.setUserOffline(widget.roomId);
        break;
    }
  }

  void _startInactiveTimer() {
    _inactiveTimer?.cancel();
    _inactiveTimer = Timer(Duration(minutes: 1), () {
      _userStatusHandler.setUserOffline(widget.roomId);
      _leaveRoom();
    });
  }

  void _cancelInactiveTimer() {
    _inactiveTimer?.cancel();
  }

  void _handleAppResumed() async {
    await _userStatusHandler.setUserOnline(widget.roomId);

    DocumentSnapshot roomSnapshot = await _firestore.collection('rooms').doc(widget.roomId).get();
    if (!roomSnapshot.exists) {
      _showReconnectDialog();
      return;
    }

    DocumentSnapshot userSnapshot = await _firestore
        .collection('rooms')
        .doc(widget.roomId)
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .get();

    if (!userSnapshot.exists) {
      _showReconnectDialog();
      return;
    }

    if (roomSnapshot['status'] == 'started') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatGameScreen(roomId: widget.roomId),
        ),
      );
    }
  }
  void _showReconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('연결 끊김'),
        content: Text('장시간 접속이 없어 방에서 나갔습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/main'),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  void _loadRoomData() async {
    try {
      DocumentSnapshot roomSnapshot = await _firestore.collection('rooms').doc(widget.roomId).get();
      if (!mounted) return;
      if (roomSnapshot.exists) {
        setState(() {
          isRoomOwner = roomSnapshot['owner'] == _auth.currentUser?.uid;
          isLoading = false;
        });
        _startRoomTimeoutTimer(); // 방에 유저가 입장하면 타이머 시작
        _fetchUsers();
      } else {
        setState(() {
          isLoading = false;
        });
        _deleteRoomAndExit(); // 방이 존재하지 않으면 나가기
      }
    } catch (e) {
      _showSnackBar('방 정보를 불러오는 중 오류가 발생했습니다.');
      setState(() {
        isLoading = false;
      });
    }
  }


  void _fetchUsers() async {
    try {
      QuerySnapshot userSnapshot = await _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('users')
          .orderBy('joinedAt')
          .get();
      if (!mounted) return;
      List<Map<String, dynamic>> userList = [];

      for (var doc in userSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final memberDoc = await _firestore.collection('members').doc(doc.id).get();
        final memberData = memberDoc.data() as Map<String, dynamic>? ?? {};

        userList.add({
          'uid': doc.id,
          'displayName': memberData['displayName'] ?? 'Unknown',
          'photoURL': memberData['photoURL'] ?? '', // 기본값으로 빈 문자열 설정
          'isOnline': data['isOnline'] == true,
        });
      }

      setState(() {
        users = userList;
      });
    } catch (e) {
      _showSnackBar('사용자 정보를 불러오는 중 오류가 발생했습니다.');
    }
  }

  void _listenToRoomStatus() {
    roomStatusSubscription = _firestore.collection('rooms').doc(widget.roomId).snapshots().listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists && snapshot.data()?['status'] == 'started') {
        _roomTimeoutTimer?.cancel(); // 게임이 시작되면 타이머 취소
        _initializeMessagesTable();  // 게임 시작 시 messages 테이블 생성
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatGameScreen(roomId: widget.roomId),
          ),
        );
      } else if (!snapshot.exists) {
        _deleteRoomAndExit(); // 방이 삭제된 경우 사용자를 로비로 리디렉션
      }
    }, onError: (e) {
      _showSnackBar("방 상태를 듣는 중 오류 발생: $e");
    });
  }



  void _initializeMessagesTable() async {
    final ref = _database.ref('rooms/${widget.roomId}/messages');
    await ref.set({});  // messages 테이블 생성
  }

  void _listenToUsers() {
    usersSubscription = _firestore
        .collection('rooms')
        .doc(widget.roomId)
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      _fetchUsers();
    }, onError: (e) {
      _showSnackBar("사용자를 듣는 중 오류 발생: $e");
    });
  }

  void _startGame() async {
    try {
      print("Starting game, ensuring all users are online before transition.");

      // 유저 상태를 한번에 업데이트 (모든 유저를 온라인 상태로 설정)
      final usersSnapshot = await _firestore.collection('rooms').doc(widget.roomId).collection('users').get();
      final batch = _firestore.batch();
      for (var userDoc in usersSnapshot.docs) {
        batch.update(userDoc.reference, {'isOnline': true});
      }
      await batch.commit();

      // 방 상태를 'started'로 업데이트하여 모든 사용자가 게임 화면으로 이동할 수 있도록 함
      await _firestore.collection('rooms').doc(widget.roomId).update({'status': 'started'});
      _roomTimeoutTimer?.cancel();

    } catch (e) {
      _showSnackBar("게임 시작 중 오류 발생: $e");
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('방에서 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('아니오'),
          ),
          TextButton(
            onPressed: () {
              _leaveRoom();
            },
            child: Text('예'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _leaveRoom() async {
    final userId = _auth.currentUser?.uid;
    final roomRef = _firestore.collection('rooms').doc(widget.roomId);
    final userRef = roomRef.collection('users').doc(userId);

    try {
      await userRef.delete();
      final userStatusRef = _database.ref('status/${widget.roomId}/$userId');
      await userStatusRef.remove();

      QuerySnapshot userSnapshot = await roomRef.collection('users').get();

      // 방장 권한을 다음 사용자에게 전달
      if (userSnapshot.docs.isNotEmpty && isRoomOwner) {
        final newOwnerId = userSnapshot.docs.first.id;
        await roomRef.update({
          'owner': newOwnerId,
        });

        if (mounted) setState(() => isRoomOwner = (newOwnerId == _auth.currentUser?.uid));
      }

      // 타이머 취소
      _roomTimeoutTimer?.cancel();

      if (!mounted) return;
     Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => DashboardScreen()),
           (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("방을 나가는 중 오류 발생: $e");
    }
  }


  void _showUserProfile(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileImageScreen(
          displayName: user['displayName'],
          photoURL: user['photoURL'] ?? '',
        ),
      ),
    );
  }

  void _startRoomTimeoutWarning() {
    const warningDuration = Duration(minutes: 4, seconds: 30); // 4분 30초 후 경고
    Timer(warningDuration, () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("경고"),
            content: Text("활동이 없어 30초 후에 방에서 자동으로 나갑니다."),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                  _restartRoomTimeoutTimer(); // 타이머를 재설정하여 사용자에게 더 많은 시간을 제공
                },
                child: Text('더 있을래요'),
              ),
            ],
          ),
        );
      }
    });
  }
  void _restartRoomTimeoutTimer() {
    _roomTimeoutTimer?.cancel();
    _startRoomTimeoutTimer(); // 타이머 다시 시작
  }
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  void _startRoomTimeoutTimer() {
    const timeoutDuration = Duration(minutes: 5);
    _roomTimeoutTimer?.cancel();
    _roomTimeoutTimer = Timer(timeoutDuration, _deleteRoomAndExit);

    _startRoomTimeoutWarning(); // 경고 타이머 시작
  }

  void _deleteRoomAndExit() async {
    if (mounted && isRoomOwner) {
      try {
        await _firestore.collection('rooms').doc(widget.roomId).delete();
        Navigator.pushReplacementNamed(context, '/dashborad'); // 메인 화면으로 리디렉션
      } catch (e) {
        print('Error deleting room: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: _showExitConfirmationDialog,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.roomId}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.deepPurple,
          elevation: 0,
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 사용자 목록 출력
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('rooms').doc(widget.roomId).collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final users = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    return {
                      'uid': doc.id,
                      'displayName': data['displayName'] ?? 'Unknown',
                      'photoURL': data['photoURL'] ?? '',
                      'isOnline': data['isOnline'] == true,
                    };
                  }).toList();

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['photoURL'].isNotEmpty
                              ? NetworkImage(user['photoURL'])
                              : AssetImage('assets/images/default_profile_image.png') as ImageProvider,
                        ),
                        title: Text(user['displayName'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        onTap: () => _showUserProfile(user),
                      );
                    },
                  );
                },
              ),
            ),
            // 게임 시작 버튼 (방장만 활성화)
            if (isRoomOwner)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    await _userStatusHandler.setUserOnline(widget.roomId);
                    _startGame();
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('게임 시작하기'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}