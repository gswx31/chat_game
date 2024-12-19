import 'package:flutter/material.dart';

import '../dashboard_screen.dart';

class ResultScreen extends StatelessWidget {
  final List<Map<String, dynamic>> users;

  const ResultScreen({required this.users, required String roomId});

  @override
  Widget build(BuildContext context) {
    users.sort((a, b) => b['score'].compareTo(a['score']));

    return WillPopScope(
      onWillPop: () async {
        // 사용자가 뒤로 가기 버튼을 눌렀을 때 실행될 코드
        _goToMainScreen(context);
        return false; // 시스템에 의한 뒤로 가기 이벤트를 비활성화
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '게임이 종료되었습니다!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user['photoURL'] != null
                            ? NetworkImage(user['photoURL'])
                            : AssetImage('assets/images/default_profile_image.png') as ImageProvider,
                      ),
                      title: Text(user['displayName'] ?? 'Unknown'),
                      subtitle: Text('Score: ${user['score'] ?? 0}'),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _goToMainScreen(context),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                  textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('메인 화면으로 돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToMainScreen(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => DashboardScreen()),
          (Route<dynamic> route) => false, // false 반환 시 모든 라우트를 스택에서 제거
    );
  }

}
