class AlbumItem {
  final String id;
  final String url;
  final String thumbUrl;
  final String caption;
  final String role;
  final String authorName;
  final DateTime timestamp;
  final String type; // 'image' or 'video'
  final int likes;

  const AlbumItem({
    required this.id,
    required this.url,
    this.thumbUrl = '',
    this.caption = '',
    this.role = 'user1',
    this.authorName = '',
    required this.timestamp,
    this.type = 'image',
    this.likes = 0,
  });

  factory AlbumItem.fromJson(String id, Map<dynamic, dynamic> json) {
    return AlbumItem(
      id: id,
      url: (json['url'] ?? json['imageUrl'] ?? '').toString(),
      thumbUrl: (json['thumbUrl'] ?? '').toString(),
      caption: (json['caption'] ?? json['text'] ?? '').toString(),
      role: (json['role'] ?? 'user1').toString(),
      authorName: (json['authorName'] ?? json['a'] ?? '').toString(),
      timestamp: json['ts'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['ts'] as int)
          : json['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
              : DateTime.now(),
      type: (json['type'] ?? 'image').toString(),
      likes: (json['likes'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'thumbUrl': thumbUrl,
        'caption': caption,
        'role': role,
        'authorName': authorName,
        'ts': timestamp.millisecondsSinceEpoch,
        'type': type,
        'likes': likes,
      };
}
