import 'package:flutter/material.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? lastPressed;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
            lastPressed == null || now.difference(lastPressed!) > Duration(seconds: 2);

        if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
          lastPressed = DateTime.now();
          final snackBar = SnackBar(
            content: Text('뒤로 가기를 한 번 더 누르시면 종료됩니다.'),
            duration: Duration(seconds: 2),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          return false; // Prevents the app from closing
        }
        return true; // Closes the app
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('대시보드'),
          automaticallyImplyLeading: false, // 이 줄을 추가하세요
          actions: [
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                  barrierColor: Colors.black45,
                  transitionDuration: Duration(milliseconds: 500),
                  pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.height,
                        color: Colors.white,
                        child: SettingsScreen(),
                      ),
                    );
                  },
                  transitionBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(1.0, 0.0),
                        end: Offset(0.0, 0.0),
                      ).animate(animation),
                      child: child,
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                // image: DecorationImage(
                //   image: AssetImage('assets/images/dashboardbackground.jpg'), // 배경 이미지 경로를 설정하세요
                //   fit: BoxFit.cover,
                // ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  _buildDashboardButton(
                    context,
                    icon: Icons.add,
                    text: '방 만들기',
                    color: Colors.blueAccent,
                    onPressed: () {
                      Navigator.pushNamed(context, '/create_room');
                    },
                  ),
                  SizedBox(height: 20),
                  _buildDashboardButton(
                    context,
                    icon: Icons.group,
                    text: '방 참가하기',
                    color: Colors.greenAccent,
                    onPressed: () {
                      Navigator.pushNamed(context, '/join_room');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardButton(BuildContext context, {required IconData icon, required String text, required Color color, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      child: Card(
        color: color.withOpacity(0.7),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          width: 250,
          height: 100,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
