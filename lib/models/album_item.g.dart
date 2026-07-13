// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AlbumItem _$AlbumItemFromJson(Map<String, dynamic> json) => AlbumItem(
      id: json['id'] as String,
      url: _readUrl(json, 'url') as String,
      thumbUrl: json['thumb_url'] as String? ?? '',
      caption: _readCaption(json, 'caption') as String? ?? '',
      role: _readRole(json, 'role') as String? ?? 'user1',
      authorName: _readAuthorName(json, 'author_name') as String? ?? '',
      timestamp: DateTime.parse(_readTimestamp(json, 'timestamp') as String),
      type: _readType(json, 'type') as String? ?? 'image',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$AlbumItemToJson(AlbumItem instance) => <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'thumb_url': instance.thumbUrl,
      'caption': instance.caption,
      'role': instance.role,
      'author_name': instance.authorName,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': instance.type,
      'likes': instance.likes,
    };
