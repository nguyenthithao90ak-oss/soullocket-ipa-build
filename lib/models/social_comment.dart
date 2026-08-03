import 'package:json_annotation/json_annotation.dart';

part 'social_comment.g.dart';

Object? _readAuthorName(Map map, String key) =>
    map['author'] ?? map['name'] ?? map['u'] ?? '';
Object? _readContent(Map map, String key) => map['c'] ?? map['text'] ?? '';
Object? _readTimestamp(Map map, String key) {
  final ts = map['ts'] ?? map['timestamp'];
  if (ts != null && (ts is int || ts is num)) {
    return DateTime.fromMillisecondsSinceEpoch(ts.toInt()).toIso8601String();
  }
  return DateTime.now().toIso8601String();
}

Object? _readId(Map map, String key) => map['id'] ?? '';
Object? _readPostId(Map map, String key) => map['postId'] ?? '';
Object? _readHouseId(Map map, String key) => map['houseId'] ?? map['uid'] ?? '';
Object? _readAuthorAvt(Map map, String key) => map['avt'] ?? '';

@JsonSerializable(explicitToJson: true)
class SocialComment {
  @JsonKey(readValue: _readId)
  final String id;

  @JsonKey(readValue: _readPostId)
  final String postId;

  @JsonKey(readValue: _readHouseId)
  final String houseId;

  @JsonKey(readValue: _readAuthorName)
  final String authorName;

  @JsonKey(readValue: _readAuthorAvt)
  final String authorAvt;

  @JsonKey(readValue: _readContent)
  final String content;

  @JsonKey(readValue: _readTimestamp)
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

  factory SocialComment.fromJson(Map<dynamic, dynamic> json) =>
      _$SocialCommentFromJson(Map<String, dynamic>.from(json));

  Map<String, dynamic> toJson() {
    final map = _$SocialCommentToJson(this);
    return {
      'id': map['id'],
      'postId': map['postId'],
      'houseId': map['houseId'],
      'uid': map['houseId'],
      'author': map['authorName'],
      'name': map['authorName'],
      'u': map['authorName'],
      'avt': map['authorAvt'],
      'c': map['content'],
      'text': map['content'],
      'ts': timestamp.millisecondsSinceEpoch,
    };
  }
}
