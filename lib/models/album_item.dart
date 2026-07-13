import 'package:json_annotation/json_annotation.dart';

part 'album_item.g.dart';

Object? _readUrl(Map map, String key) => map['url'] ?? map['imageUrl'] ?? '';
Object? _readCaption(Map map, String key) => map['caption'] ?? map['text'] ?? '';
Object? _readAuthorName(Map map, String key) => map['authorName'] ?? map['a'] ?? '';
Object? _readTimestamp(Map map, String key) {
  final ts = map['ts'] ?? map['timestamp'];
  if (ts != null && (ts is int || ts is num)) {
    return DateTime.fromMillisecondsSinceEpoch(ts.toInt()).toIso8601String();
  }
  return DateTime.now().toIso8601String();
}
Object? _readRole(Map map, String key) => map['role'] ?? 'user1';
Object? _readType(Map map, String key) => map['type'] ?? 'image';

@JsonSerializable(explicitToJson: true)
class AlbumItem {
  final String id;
  
  @JsonKey(readValue: _readUrl)
  final String url;
  
  @JsonKey(defaultValue: '')
  final String thumbUrl;
  
  @JsonKey(readValue: _readCaption)
  final String caption;
  
  @JsonKey(readValue: _readRole)
  final String role;
  
  @JsonKey(readValue: _readAuthorName)
  final String authorName;
  
  @JsonKey(readValue: _readTimestamp)
  final DateTime timestamp;
  
  @JsonKey(readValue: _readType)
  final String type; // 'image' or 'video'
  
  @JsonKey(defaultValue: 0)
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
    // Add id to the json map so _$AlbumItemFromJson can parse it
    final map = Map<String, dynamic>.from(json);
    map['id'] = id;
    return _$AlbumItemFromJson(map);
  }

  Map<String, dynamic> toJson() {
    final map = _$AlbumItemToJson(this);
    // Remove id from toJson since it wasn't there originally
    map.remove('id');
    // Map internal fields to custom schema
    return {
      'url': map['url'],
      'thumbUrl': map['thumbUrl'],
      'caption': map['caption'],
      'role': map['role'],
      'authorName': map['authorName'],
      'ts': timestamp.millisecondsSinceEpoch,
      'type': map['type'],
      'likes': map['likes'],
    };
  }
}
