import 'package:flutter/material.dart';

class UserList extends StatelessWidget {
  final List<Map<String, dynamic>> users;

  const UserList({required this.users});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final displayName = user['displayName'] ?? 'Unknown';
        final photoURL = user['photoURL'];

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: photoURL != null && photoURL.isNotEmpty
                    ? NetworkImage(photoURL)
                    : AssetImage('assets/images/default_profile_image.png') as ImageProvider,
              ),
              if (user['isOnline'] == true)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(displayName),
          tileColor: user['isOnline'] == false ? Colors.grey[300] : null,
          subtitle: Text(user['isOnline'] == false ? '나감' : 'Score: ${user['score'] ?? 0}'),
          onTap: () {
            // 유저를 탭했을 때 동작 추가 가능
          },
        );
      },
    );
  }
}
