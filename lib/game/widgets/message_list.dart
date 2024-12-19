import 'package:flutter/material.dart';

class MessageList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final String? currentUserId;
  final ScrollController scrollController;
  final String Function(String senderId) getSenderName;
  final String Function(String senderId) getSenderPhotoUrl;
  final String Function(int timestamp) formatTimestamp;

  const MessageList({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    required this.getSenderName,
    required this.getSenderPhotoUrl,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isCurrentUser = message['senderId'] == currentUserId;
        final timestamp = message['timestamp'] as int?;

        return Align(
          alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCurrentUser)
                CircleAvatar(
                  backgroundImage: getSenderPhotoUrl(message['senderId']).isNotEmpty
                      ? NetworkImage(getSenderPhotoUrl(message['senderId']))
                      : AssetImage('assets/images/default_profile_image.png') as ImageProvider,
                ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isCurrentUser)
                      Text(getSenderName(message['senderId']),
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)), // 이름을 강조
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCurrentUser ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Column(
                        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(message['text'], style: TextStyle(color: Colors.black87)),
                          SizedBox(height: 5),
                          Text(
                            formatTimestamp(timestamp ?? 0),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
