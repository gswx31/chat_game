import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';

class MessageList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final String? currentUserId;
  final ScrollController scrollController;

  // Legacy callbacks — kept for compatibility but senderName/photoURL
  // are read directly from the message map when available.
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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('아직 메시지가 없어요',
                style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg = messages[i];
        final senderId = msg['senderId'] as String? ?? '';
        final isMe = senderId == currentUserId;

        // Use stored names first, fall back to callbacks
        final senderName = (msg['senderName'] as String?)?.isNotEmpty == true
            ? msg['senderName'] as String
            : getSenderName(senderId);
        final photoURL = (msg['senderPhotoURL'] as String?)?.isNotEmpty == true
            ? msg['senderPhotoURL'] as String
            : getSenderPhotoUrl(senderId);
        final text = msg['text'] as String? ?? '';
        final ts = msg['timestamp'] as int? ?? 0;

        // Grouping: hide avatar/name if previous message is same sender
        final prevMsg = i > 0 ? messages[i - 1] : null;
        final nextMsg = i < messages.length - 1 ? messages[i + 1] : null;
        final isSameAsPrev =
            prevMsg != null && prevMsg['senderId'] == senderId;
        final isSameAsNext =
            nextMsg != null && nextMsg['senderId'] == senderId;

        final isSystem = msg['isSystem'] as bool? ?? false;

        if (isSystem) {
          return _SystemChip(text: text);
        }

        return _MessageBubble(
          text: text,
          senderName: senderName,
          photoURL: photoURL,
          timestamp: ts,
          isMe: isMe,
          showAvatar: !isMe && !isSameAsNext,
          showName: !isMe && !isSameAsPrev,
          showTime: !isSameAsNext,
        );
      },
    );
  }
}

class _SystemChip extends StatelessWidget {
  final String text;
  const _SystemChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final String photoURL;
  final int timestamp;
  final bool isMe;
  final bool showAvatar;
  final bool showName;
  final bool showTime;

  const _MessageBubble({
    required this.text,
    required this.senderName,
    required this.photoURL,
    required this.timestamp,
    required this.isMe,
    required this.showAvatar,
    required this.showName,
    required this.showTime,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(timestamp));

    return Padding(
      padding: EdgeInsets.only(
        bottom: showTime ? 10 : 2,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Avatar (other only)
          if (!isMe) ...[
            SizedBox(
              width: 34,
              child: showAvatar
                  ? CircleAvatar(
                      radius: 17,
                      backgroundColor:
                          AppColors.primary.withOpacity(0.2),
                      backgroundImage: photoURL.isNotEmpty
                          ? NetworkImage(photoURL) as ImageProvider
                          : const AssetImage(
                              'assets/images/default_profile_image.png'),
                    )
                  : const SizedBox(),
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showName && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    if (isMe && showTime)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 2),
                        child: Text(timeStr,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400)),
                      ),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.62,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (!isMe && showTime)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 2),
                        child: Text(timeStr,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
