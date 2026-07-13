class AppUser {
  final String uid;
  final String displayName;
  final String photoURL;
  final bool isOnline;
  final int score;

  const AppUser({
    required this.uid,
    required this.displayName,
    this.photoURL = '',
    this.isOnline = false,
    this.score = 0,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      displayName: data['displayName'] as String? ?? 'Unknown',
      photoURL: data['photoURL'] as String? ?? '',
      isOnline: data['isOnline'] as bool? ?? false,
      score: data['score'] as int? ?? 0,
    );
  }

  AppUser copyWith({
    String? displayName,
    String? photoURL,
    bool? isOnline,
    int? score,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isOnline: isOnline ?? this.isOnline,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'photoURL': photoURL,
        'isOnline': isOnline,
        'score': score,
      };
}
