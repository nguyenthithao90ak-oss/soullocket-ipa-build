// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SocialComment _$SocialCommentFromJson(Map<String, dynamic> json) =>
    SocialComment(
      id: _readId(json, 'id') as String,
      postId: _readPostId(json, 'post_id') as String,
      houseId: _readHouseId(json, 'house_id') as String,
      authorName: _readAuthorName(json, 'author_name') as String? ?? '',
      authorAvt: _readAuthorAvt(json, 'author_avt') as String? ?? '',
      content: _readContent(json, 'content') as String,
      timestamp: DateTime.parse(_readTimestamp(json, 'timestamp') as String),
    );

Map<String, dynamic> _$SocialCommentToJson(SocialComment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'post_id': instance.postId,
      'house_id': instance.houseId,
      'author_name': instance.authorName,
      'author_avt': instance.authorAvt,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
    };
