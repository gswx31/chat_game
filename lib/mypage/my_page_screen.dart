import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'image_helper.dart';

class MyPageScreen extends StatefulWidget {
  @override
  _MyPageScreenState createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImageHelper _imageHelper = ImageHelper();

  final TextEditingController _displayNameController = TextEditingController();
  String? _photoURL;
  bool _hasChanges = false;
  int _selectedIndex = 0; // 초기값 설정

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final DocumentSnapshot userDoc = await _firestore.collection('members').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _displayNameController.text = userDoc['displayName'];
          _photoURL = userDoc['photoURL'];
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('members').doc(user.uid).update({
        'displayName': _displayNameController.text,
        'photoURL': _photoURL,
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('프로필 수정 완료'),
          content: Text('프로필이 성공적으로 수정되었습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to the previous screen
              },
              child: Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _changeProfileImage(ImageSource source) async {
    final File? image = await _imageHelper.pickImage(source);
    if (image != null) {
      final String? imageUrl = await _imageHelper.uploadImage(image);
      if (imageUrl != null) {
        setState(() {
          _photoURL = imageUrl;
          _hasChanges = true;
        });
      } else {
        print('Image upload failed');
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      return await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('변경 사항 취소'),
          content: Text('프로필 변경을 취소하시겠습니까? 저장하지 않은 정보는 잃게 됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('아니요'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('예'),
            ),
          ],
        ),
      ) ??
          false;
    } else {
      return true;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // 탭에 따라 다른 화면으로 이동하는 로직을 추가할 수 있습니다.
    // 예: if (index == 0) { Navigator.push(...); }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('내 프로필'),
          backgroundColor: Colors.teal,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => BottomSheet(
                        onClosing: () {},
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(Icons.camera_alt),
                              title: Text('카메라로 사진 찍기'),
                              onTap: () {
                                Navigator.pop(context);
                                _changeProfileImage(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.photo),
                              title: Text('앨범에서 사진 선택'),
                              onTap: () {
                                Navigator.pop(context);
                                _changeProfileImage(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _photoURL != null && _photoURL!.isNotEmpty
                        ? NetworkImage(_photoURL!)
                        : AssetImage('assets/images/default_profile_image.png') as ImageProvider,
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: '닉네임',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {
                    _hasChanges = true;
                  });
                },
              ),
              Spacer(),
              ElevatedButton(
                onPressed: _updateProfile,
                child: Text('프로필 수정'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.teal,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
