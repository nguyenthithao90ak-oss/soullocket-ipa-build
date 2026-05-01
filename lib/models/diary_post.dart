class DiaryPost {
  final String id;
  final String content;
  final String imageUrl;
  final String authorId;
  final String authorRole;
  final String authorName;
  final DateTime timestamp;
  final String mood;
  final int? editedAt;
  final bool pinned;
  final int? pinnedAt;
  final Map<String, dynamic>? likes; // {uid: true}

  const DiaryPost({
    required this.id,
    required this.content,
    this.imageUrl = '',
    required this.authorId,
    this.authorRole = '',
    required this.authorName,
    required this.timestamp,
    this.mood = '😊',
    this.editedAt,
    this.pinned = false,
    this.pinnedAt,
    this.likes,
  });

  bool get isEdited => editedAt != null;

  factory DiaryPost.fromJson(String id, Map<dynamic, dynamic> json) {
    final tsRaw = json['ts'] ?? json['timestamp'];
    final ts = tsRaw is int
        ? DateTime.fromMillisecondsSinceEpoch(tsRaw)
        : DateTime.now();
    final rawAuthorId = (json['authorId'] ?? '').toString().trim();
    final rawAuthorRole =
        (json['authorRole'] ?? json['role'] ?? '').toString().trim();
    final normalizedAuthorRole = rawAuthorRole == 'user1' ||
            rawAuthorRole == 'user2'
        ? rawAuthorRole
        : (rawAuthorId == 'user1' || rawAuthorId == 'user2' ? rawAuthorId : '');
    final normalizedAuthorId =
        rawAuthorId.isNotEmpty ? rawAuthorId : normalizedAuthorRole;

    Map<String, dynamic>? likesMap;
    if (json['likes'] != null && json['likes'] is Map) {
      likesMap = Map<String, dynamic>.from(json['likes'] as Map);
    }

    return DiaryPost(
      id: id,
      content: (json['content'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      authorId: normalizedAuthorId.isNotEmpty ? normalizedAuthorId : 'user1',
      authorRole: normalizedAuthorRole,
      authorName: (json['authorName'] ?? json['a'] ?? 'Người yêu').toString(),
      mood: (json['mood'] ?? '😊').toString(),
      timestamp: ts,
      editedAt: json['editedAt'] as int?,
      pinned: json['pinned'] == true,
      pinnedAt: json['pinnedAt'] is int
          ? json['pinnedAt'] as int
          : (json['pinnedAt'] is num)
              ? (json['pinnedAt'] as num).toInt()
              : int.tryParse('${json['pinnedAt'] ?? ''}'),
      likes: likesMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'imageUrl': imageUrl,
        'authorId': authorId,
        if (authorRole.isNotEmpty) 'authorRole': authorRole,
        'role': authorRole.isNotEmpty ? authorRole : authorId,
        'authorName': authorName,
        'mood': mood,
        'ts': timestamp.millisecondsSinceEpoch,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'pinned': pinned,
        if (pinnedAt != null) 'pinnedAt': pinnedAt,
        if (editedAt != null) 'editedAt': editedAt,
      };
}
