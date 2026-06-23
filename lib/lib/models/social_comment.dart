class SocialComment {
  final String id;
  final String postId;
  final String houseId;
  final String authorName;
  final String authorAvt;
  final String content;
  final DateTime timestamp;

  const SocialComment({
    required this.id,
    required this.postId,
    required this.houseId,
    this.authorName = '',
    this.authorAvt = '',
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'houseId': houseId,
        'uid': houseId,
        'author': authorName,
        'name': authorName,
        'u': authorName,
        'avt': authorAvt,
        'c': content,
        'text': content,
        'ts': timestamp.millisecondsSinceEpoch,
      };
}
