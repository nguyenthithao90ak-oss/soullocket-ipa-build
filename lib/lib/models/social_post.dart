class SocialPost {
  final String id;
  final String houseId;
  final String legacyHouseId;
  final String houseName;
  final String authorUid;
  final String authorRole;
  final String authorName;
  final String authorAvt;
  final String content;
  final String imageUrl;
  final String videoUrl;
  final int likes;
  final int comments;
  final int reposts;
  final int hotScore;
  final DateTime timestamp;
  final String privacy; // 'public' | 'friends' | 'private'
  final bool isRepost;
  final String? originalPostId;
  final String mood;
  final String moodEmoji;
  final String location;
  final String postType;
  final bool isAnon;
  final bool isLocket;
  final bool commentsEnabled;
  final Map<String, dynamic> likesMap;

  const SocialPost({
    required this.id,
    required this.houseId,
    this.legacyHouseId = '',
    this.houseName = '',
    this.authorUid = '',
    this.authorRole = 'user1',
    this.authorName = '',
    this.authorAvt = '',
    this.content = '',
    this.imageUrl = '',
    this.videoUrl = '',
    this.likes = 0,
    this.comments = 0,
    this.reposts = 0,
    this.hotScore = 0,
    required this.timestamp,
    this.privacy = 'public',
    this.isRepost = false,
    this.originalPostId,
    this.mood = '',
    this.moodEmoji = '',
    this.location = '',
    this.postType = 'mood',
    this.isAnon = false,
    this.isLocket = false,
    this.commentsEnabled = true,
    this.likesMap = const <String, dynamic>{},
  });

  factory SocialPost.fromJson(String id, Map<dynamic, dynamic> json) {
    final rawLikesMap = json['likes_map'];
    final likesMap = rawLikesMap is Map
        ? rawLikesMap.map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, dynamic>{};
    final rawLikes = json['likes'];
    final resolvedLikes = likesMap.isNotEmpty
        ? likesMap.length
        : (rawLikes is num ? rawLikes.toInt() : 0);

    return SocialPost(
      id: id,
      houseId: (json['houseId'] ?? json['uid'] ?? '').toString(),
      legacyHouseId: (json['uid'] ?? '').toString(),
      houseName: (json['houseName'] ?? '').toString(),
      authorUid: (json['author_uid'] ?? json['authorUid'] ?? '').toString(),
      authorRole: (json['authorRole'] ?? json['role'] ?? 'user1').toString(),
      authorName:
          (json['authorName'] ?? json['author'] ?? json['a'] ?? '').toString(),
      authorAvt: (json['houseAvt'] ?? json['authorAvt'] ?? json['avt'] ?? '')
          .toString(),
      content: (json['content'] ?? json['text'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['img'] ?? '').toString(),
      videoUrl: (json['videoUrl'] ?? json['vid'] ?? '').toString(),
      likes: resolvedLikes,
      comments: (json['commentCount'] ?? json['comments'] as int?) ?? 0,
      reposts: (json['shareCount'] ?? json['reposts'] as int?) ?? 0,
      hotScore: (json['hotScore'] as int?) ?? 0,
      timestamp: json['ts'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['ts'] as int)
          : json['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
              : DateTime.now(),
      privacy: (json['privacy'] ?? 'public').toString(),
      isRepost: (json['isRepost'] as bool?) ?? false,
      originalPostId: json['originalPostId']?.toString(),
      mood: (json['mood'] ?? '').toString(),
      moodEmoji: (json['moodEmoji'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      postType: (json['postType'] ?? json['type'] ?? 'mood').toString(),
      isAnon: (json['isAnon'] as bool?) ?? false,
      isLocket: (json['isLocket'] as bool?) ?? false,
      commentsEnabled: (json['commentsEnabled'] as bool?) ?? true,
      likesMap: likesMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'houseId': houseId,
        if (legacyHouseId.isNotEmpty) 'uid': legacyHouseId,
        'houseName': houseName,
        if (authorUid.isNotEmpty) 'author_uid': authorUid,
        'authorRole': authorRole,
        'authorName': authorName,
        'authorAvt': authorAvt,
        'houseAvt': authorAvt,
        'content': content,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'likes': likes,
        'commentCount': comments,
        'shareCount': reposts,
        'hotScore': hotScore,
        'ts': timestamp.millisecondsSinceEpoch,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'privacy': privacy,
        'isRepost': isRepost,
        'originalPostId': originalPostId,
        'mood': mood,
        'moodEmoji': moodEmoji,
        'location': location,
        'postType': postType,
        'isAnon': isAnon,
        'isLocket': isLocket,
        'commentsEnabled': commentsEnabled,
        if (likesMap.isNotEmpty)
          'likes_map': Map<String, dynamic>.from(likesMap),
      };

  int get likesCount => likes;

  DateTime get createdAt => timestamp;
}
