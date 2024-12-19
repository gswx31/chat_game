import 'package:chat_game/genre_selection_chip.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game/providers/questions_provider.dart';

class CreateRoomScreen extends StatefulWidget {
  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;
  late QuestionsProvider _questionsProvider;
  String roomId = '';
  String difficulty = '보통';
  String ageGroup = '20대';
  bool _isLoading = false;
  Map<String, bool> genreSelections = {
    '전체': true,
    '문학': true,
    '수학': true,
    '과학': true,
    '역사': true,
    '예술': true,
    '스포츠': true,
    '기타': true,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _questionsProvider = QuestionsProvider();
    _initializeState();
  }

  void _initializeState() {
    roomId = '';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _handleOwnerLeaving();
    }
  }

  void _createRoom() async {
    if (genreSelections.values.every((selected) => !selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('적어도 하나의 장르를 선택해야 합니다.')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      _formKey.currentState!.save();

      DocumentSnapshot existingRoom = await _firestore.collection('rooms').doc(roomId).get();
      Map<String, dynamic>? existingRoomData = existingRoom.data() as Map<String, dynamic>?;

      if (existingRoom.exists && !(existingRoomData?['isEnd'] ?? true)) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('죄송합니다. 이 방 이름은 이미 사용 중입니다. 다른 이름을 선택해 주세요.'),
          ),
        );
        return;
      }

      await _createRoomInFirestore();
    }
  }

  Future<void> _createRoomInFirestore() async {
    DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
    await roomRef.set({
      'status': 'waiting',
      'difficulty': difficulty,
      'ageGroup': ageGroup,
      'owner': _auth.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'genres': genreSelections.entries.where((entry) => entry.value).map((entry) => entry.key).toList(),
      'isEnd': false,
      'endTime': null,
    });

    await _questionsProvider.initializeQuestions(
      roomId,
      genreSelections.entries.where((entry) => entry.value).map((entry) => entry.key).toList(),
      difficulty,
    );

    DocumentSnapshot userSnapshot = await _firestore.collection('members').doc(_auth.currentUser?.uid).get();
    final userData = userSnapshot.data() as Map<String, dynamic>? ?? {};

    DocumentReference userRef = roomRef.collection('users').doc(_auth.currentUser?.uid);
    await userRef.set({
      'displayName': userData['displayName'] ?? 'Unknown',
      'photoURL': userData['photoURL'] ?? '', // 프로필 사진 URL 추가
      'status': 'joined',
      'isOnline': true,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _isLoading = false;
    });

    // Navigate to the lobby screen with the roomId
    Navigator.pushReplacementNamed(
      context,
      '/lobby',
      arguments: {'roomId': roomId},
    );
  }

  void _handleOwnerLeaving() async {
    DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
    DocumentSnapshot roomSnapshot = await roomRef.get();

    if (roomSnapshot.exists && roomSnapshot['owner'] == _auth.currentUser?.uid) {
      QuerySnapshot userSnapshot = await roomRef.collection('users').orderBy('joinedAt').limit(1).get();
      if (userSnapshot.docs.isEmpty) {
        await roomRef.delete();
      } else {
        await roomRef.update({
          'owner': userSnapshot.docs.first.id,
        });
      }
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('방 생성 중단'),
        content: Text('방 생성을 중단하고 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('나가기'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _onGenreSelected(bool selected, String genre) {
    setState(() {
      if (genre == '전체') {
        genreSelections.updateAll((key, value) => selected);
      } else {
        genreSelections[genre] = selected;
        if (genreSelections.values.every((isSelected) => isSelected)) {
          genreSelections['전체'] = true;
        } else {
          genreSelections['전체'] = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await _showExitConfirmationDialog();
        return shouldExit;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('방 만들기', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.teal,
          elevation: 0,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: '방 이름',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          prefixIcon: Icon(Icons.meeting_room, color: Colors.teal),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '방 이름을 입력해주세요.';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          roomId = value!;
                        },
                      ),
                      SizedBox(height: 16),
                      Text('난이도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      DropdownButtonFormField<String>(
                        value: difficulty,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          prefixIcon: Icon(Icons.assessment, color: Colors.teal),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            difficulty = newValue!;
                          });
                        },
                        items: <String>['쉬움', '보통', '어려움']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                      Text('장르', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 10.0,
                        runSpacing: 5.0,
                        children: genreSelections.keys.map((String key) {
                          return Tooltip(
                            message: '$key에 대한 설명',
                            child: GenreSelectionChip(
                              label: key,
                              selected: genreSelections[key]!,
                              onSelected: (selected) {
                                _onGenreSelected(selected, key);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
              _createRoom();
            },
            child: Text('방 만들기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
