class GameMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderPhotoURL;
  final String text;
  final int timestamp;

  const GameMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoURL = '',
    required this.text,
    required this.timestamp,
  });

  factory GameMessage.fromMap(String id, Map<String, dynamic> data) {
    return GameMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Unknown',
      senderPhotoURL: data['senderPhotoURL'] as String? ?? '',
      text: data['text'] as String? ?? '',
      timestamp: data['timestamp'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoURL': senderPhotoURL,
        'text': text,
        'timestamp': timestamp,
      };
}
