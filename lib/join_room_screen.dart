import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class JoinRoomScreen extends StatefulWidget {
  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;
  late FirebaseDatabase _database;
  TextEditingController _searchController = TextEditingController();
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  void _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      setState(() {
        _firestore = FirebaseFirestore.instance;
        _auth = FirebaseAuth.instance;
        _database = FirebaseDatabase.instance;
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = true;
      });
    }
  }

  void _joinRoom(String roomId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _showSnackBar('로그인된 사용자가 없습니다.');
        return;
      }

      DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
      DocumentSnapshot roomSnapshot = await roomRef.get();

      if (roomSnapshot.exists) {
        if (roomSnapshot['status'] == 'waiting') {
          DocumentReference userRef = roomRef.collection('users').doc(userId);
          DocumentSnapshot userSnapshot = await _firestore.collection('members').doc(userId).get();

          if (userSnapshot.exists) {
            final userData = userSnapshot.data() as Map<String, dynamic>;
            await userRef.set({
              'displayName': userData['displayName'],
              'photoURL': userData['photoURL'],
              'status': 'joined',
              'isOnline': true,
              'joinedAt': FieldValue.serverTimestamp(),
            });

          }

          final userStatusRef = _database.ref('status/$roomId/$userId');
          userStatusRef.set(true);
          Navigator.pushReplacementNamed(context, '/lobby', arguments: {'roomId': roomId});
        } else {
          _showSnackBar('방을 찾을 수 없거나 이미 게임이 시작되었습니다.');
        }
      } else {
        _showSnackBar('방을 찾을 수 없습니다.');
      }
    } catch (e) {
      print(e);
      _showSnackBar('방 참가 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Stream<int> _getUserCount(String roomId) {
    return _firestore.collection('rooms').doc(roomId).collection('users').snapshots().map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Scaffold(
        body: Center(child: Text('Firebase 초기화 중 오류가 발생했습니다.')),
      );
    }

    if (!_initialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('방 참가하기'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '방 검색',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('rooms').where('status', isEqualTo: 'waiting').where('isEnd', isEqualTo: false).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final rooms = snapshot.data!.docs.where((room) {
                    final roomName = room.id.toLowerCase();
                    final keyword = _searchController.text.toLowerCase();
                    return roomName.contains(keyword);
                  }).toList();

                  if (rooms.isEmpty) {
                    return Center(child: Text('검색 결과가 없습니다.'));
                  }

                  return ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16.0),
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.group, color: Colors.white),
                            ),
                            title: Text(
                              room.id,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            subtitle: StreamBuilder<int>(
                              stream: _getUserCount(room.id),
                              builder: (context, userCountSnapshot) {
                                if (!userCountSnapshot.hasData) {
                                  return Text('Loading...');
                                }
                                final userCount = userCountSnapshot.data!;
                                return Text(
                                  '난이도: ${room['difficulty']}, 나이대: ${room['ageGroup']}\n현재 인원: $userCount명',
                                  style: TextStyle(fontSize: 14),
                                );
                              },
                            ),
                            trailing: Icon(Icons.arrow_forward_ios, color: Colors.teal),
                            onTap: () => _joinRoom(room.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
