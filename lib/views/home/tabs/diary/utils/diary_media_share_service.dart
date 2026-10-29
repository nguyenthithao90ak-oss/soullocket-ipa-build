import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../utils/services/infrastructure/storage_service.dart';
import 'diary_memory_media.dart';

typedef DiaryMemoryShareDownload =
    Future<({Uint8List bytes, String url})> Function({
      required String houseId,
      required String memoryId,
      required bool Function() scopeIsCurrent,
    });

/// Xuất file do người dùng chọn, không đưa URL riêng tư vào nội dung chia sẻ.
class DiaryMediaShareService {
  DiaryMediaShareService({
    DiaryMemoryShareDownload? download,
    Future<ShareResult> Function(ShareParams)? share,
    String? Function()? currentUid,
    Stream<String?> Function()? authChanges,
    this.maxTotalBytes = 100 * 1024 * 1024,
  }) : _download = download ?? _downloadMemory,
       _share = share ?? SharePlus.instance.share,
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _authChanges =
           authChanges ??
           (() => FirebaseAuth.instance.authStateChanges().map(
             (user) => user?.uid,
           ));

  final DiaryMemoryShareDownload _download;
  final Future<ShareResult> Function(ShareParams) _share;
  final String? Function() _currentUid;
  final Stream<String?> Function() _authChanges;
  final int maxTotalBytes;
  bool _sharing = false;

  static Future<({Uint8List bytes, String url})> _downloadMemory({
    required String houseId,
    required String memoryId,
    required bool Function() scopeIsCurrent,
  }) => StorageService().downloadPrivateMemory(
    houseId: houseId,
    memoryId: memoryId,
    scopeIsCurrent: scopeIsCurrent,
  );

  Future<ShareResult> share({
    required String houseId,
    required List<Map<String, dynamic>> memories,
    required bool Function() scopeIsCurrent,
    required Rect sharePositionOrigin,
  }) async {
    if (_sharing) throw StateError('Share already in progress');
    final uid = _currentUid();
    if (uid == null || houseId.isEmpty || memories.isEmpty) {
      throw StateError('Missing share scope');
    }
    _sharing = true;
    var changedSession = false;
    final auth = _authChanges().listen((next) {
      if (next != uid) changedSession = true;
    }, onError: (Object _) => changedSession = true);
    bool current() =>
        !changedSession && _currentUid() == uid && scopeIsCurrent();
    void guard() {
      if (!current()) throw StateError('Share scope changed');
    }

    try {
      final files = <XFile>[];
      final names = <String>[];
      var totalBytes = 0;
      for (final memory in memories) {
        guard();
        final id = memory['id']?.toString().trim() ?? '';
        if (id.isEmpty) throw StateError('Missing memory ID');
        final downloaded = await _download(
          houseId: houseId,
          memoryId: id,
          scopeIsCurrent: current,
        );
        guard();
        totalBytes += downloaded.bytes.length;
        if (downloaded.bytes.isEmpty || totalBytes > maxTotalBytes) {
          throw StateError('Share size limit exceeded');
        }
        final format = _format(memory, downloaded.url, downloaded.bytes);
        files.add(XFile.fromData(downloaded.bytes, mimeType: format.mime));
        names.add('SoulLocket_${files.length}.${format.extension}');
      }
      guard();
      return await _share(
        ShareParams(
          files: files,
          fileNameOverrides: names,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } finally {
      await auth.cancel();
      _sharing = false;
    }
  }

  static ({String extension, String mime}) _format(
    Map<String, dynamic> memory,
    String url,
    Uint8List bytes,
  ) {
    final video = isDiaryMemoryVideo(memory) || isDiaryMemoryVideoUrl(url);
    // Ưu tiên chữ ký ảnh để tên file vẫn đúng khi endpoint không có phần mở rộng.
    if (!video) {
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47) {
        return (extension: 'png', mime: 'image/png');
      }
      if (bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff) {
        return (extension: 'jpg', mime: 'image/jpeg');
      }
      if (bytes.length >= 6 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46) {
        return (extension: 'gif', mime: 'image/gif');
      }
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return (extension: 'webp', mime: 'image/webp');
      }
    }
    const formats = <String, String>{
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'avif': 'image/avif',
      'mp4': 'video/mp4',
      'm4v': 'video/x-m4v',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
      '3gp': 'video/3gpp',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
    };
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    final extension = path.split('.').last;
    final mime = formats[extension];
    if (mime != null && mime.startsWith(video ? 'video/' : 'image/')) {
      return (extension: extension, mime: mime);
    }
    final contentType = (memory['contentType'] ?? memory['mimeType'])
        ?.toString();
    for (final entry in formats.entries) {
      if (entry.value == contentType &&
          entry.value.startsWith(video ? 'video/' : 'image/')) {
        return (extension: entry.key, mime: entry.value);
      }
    }
    return video
        ? (extension: 'mp4', mime: 'video/mp4')
        : (extension: 'jpg', mime: 'image/jpeg');
  }
}
