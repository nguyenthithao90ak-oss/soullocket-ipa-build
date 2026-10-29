import 'dart:typed_data';

import '../views/home/tabs/diary/utils/diary_memory_media.dart';
import '../views/home/tabs/diary/utils/private_memory_link_policy.dart';

/// Tham chiếu nội bộ ổn định, không phải URL tải ảnh và không chứa quyền truy cập.
typedef WidgetPrivateDiaryImage = ({String houseId, String mediaId});

bool _validId(String value) =>
    value.isNotEmpty &&
    value.length <= 128 &&
    !RegExp(r'[.#$\[\]/\\\s\x00-\x1f\x7f]').hasMatch(value);

WidgetPrivateDiaryImage? parseWidgetPrivateDiaryImage(String source) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      uri.scheme != 'soullocket-memory' ||
      uri.host != 'private' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.pathSegments.length != 2) {
    return null;
  }
  final houseId = uri.pathSegments[0];
  final mediaId = uri.pathSegments[1];
  return _validId(houseId) && _validId(mediaId)
      ? (houseId: houseId, mediaId: mediaId)
      : null;
}

/// Đọc cả schema ảnh cũ và ảnh riêng tư mới từ hai nhánh Nhật ký/Kỷ niệm.
/// Không dùng URL ký lưu kèm record private và không đưa video/thùng rác lên widget.
List<String> collectWidgetDiaryImageSources({
  required String houseId,
  required Iterable<Object?> snapshots,
  int limit = 12,
}) {
  if (!_validId(houseId) || limit <= 0) return const [];
  final items = <({int order, String source})>[];
  for (final raw in snapshots) {
    if (raw is! Map) continue;
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final data = <String, dynamic>{
        for (final field in (entry.value as Map).entries)
          field.key.toString(): field.value,
        'id': entry.key.toString(),
      };
      if (data['deleted'] == true ||
          data['isDeleted'] == true ||
          data['trashed'] == true ||
          data['deletedAt'] != null ||
          isDiaryMemoryVideo(data)) {
        continue;
      }
      String? source;
      if (PrivateMemoryLinkPolicy.isPrivate(data)) {
        if (!_validId(data['id'] as String)) continue;
        source = Uri(
          scheme: 'soullocket-memory',
          host: 'private',
          pathSegments: [houseId, data['id'] as String],
        ).toString();
      } else {
        // Trường url rỗng không được che mất imageUrl/photoUrl của bản ghi cũ.
        for (final key in const [
          'url',
          'imageUrl',
          'photoUrl',
          'thumbUrl',
          'thumbnailUrl',
          'downloadUrl',
          'mediaUrl',
        ]) {
          final value = data[key];
          if (value is! String || isDiaryMemoryVideoUrl(value)) continue;
          final uri = Uri.tryParse(value.trim());
          if (uri != null &&
              const {'https', 'http'}.contains(uri.scheme) &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty) {
            source = value.trim();
            break;
          }
        }
      }
      if (source == null) continue;
      final rawOrder =
          data['ts'] ?? data['timestamp'] ?? data['date'] ?? data['updatedAt'];
      final order = rawOrder is num
          ? rawOrder.toInt()
          : int.tryParse(rawOrder?.toString() ?? '') ?? 0;
      items.add((order: order, source: source));
    }
  }
  items.sort((a, b) => b.order.compareTo(a.order));
  final seen = <String>{};
  return items
      .map((item) => item.source)
      .where(seen.add)
      .take(limit)
      .toList(growable: false);
}

/// Dùng lại ảnh đã được phép lưu trong cache trước khi xin thumbnail mới.
/// Mọi bước async đều kiểm tra phiên; URL ký chỉ tồn tại trong lượt tải này.
Future<Uint8List?> loadWidgetPrivateDiaryImage({
  required WidgetPrivateDiaryImage image,
  required bool Function() isCurrent,
  required Future<Uint8List?> Function(WidgetPrivateDiaryImage image) readCache,
  required Future<String> Function(WidgetPrivateDiaryImage image)
  resolveThumbnail,
  required Future<Uint8List> Function(String url) download,
}) async {
  if (!isCurrent()) return null;
  final cached = await readCache(image);
  if (!isCurrent()) return null;
  if (cached != null && cached.isNotEmpty) return cached;
  final url = await resolveThumbnail(image);
  if (!isCurrent()) return null;
  final bytes = await download(url);
  return isCurrent() && bytes.isNotEmpty ? bytes : null;
}
