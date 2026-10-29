import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../app_error_mapper.dart';
import '../../views/home/tabs/diary/utils/diary_memory_media.dart';
import '../../views/home/tabs/diary/utils/private_memory_link_policy.dart';
import 'games/soul_block_memory_service.dart';
import 'l10n_service.dart';
import 'storage/private_image_disk_cache.dart';

/// Ảnh riêng tư chỉ giữ ID; URL cấp quyền không đi vào sự kiện chạm tim.
class SoulMergeMemory {
  const SoulMergeMemory({
    required this.id,
    required this.houseId,
    this.memoryId = '',
    this.privateMedia = false,
    this.imageUrl = '',
    this.text = '',
    this.mood = '💖',
    this.timestamp = 0,
  });

  final String id;
  final String houseId;
  final String memoryId;
  final bool privateMedia;
  final String imageUrl;
  final String text;
  final String mood;
  final int timestamp;

  bool get hasPhoto => privateMedia ? memoryId.isNotEmpty : imageUrl.isNotEmpty;
  String? get interactiveUrl => privateMedia || !hasPhoto ? null : imageUrl;
  String get dateStr {
    if (timestamp <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  static SoulMergeMemory? fromDiary(
    String houseId,
    Map<String, dynamic> data, {
    bool legacy = false,
  }) {
    if (data['deletedAt'] != null ||
        data['isDeleted'] == true ||
        isDiaryMemoryVideo(data)) {
      return null;
    }
    final memoryId = data['id']?.toString() ?? '';
    final privateMedia = PrivateMemoryLinkPolicy.isPrivate(data);
    if (privateMedia && memoryId.isEmpty) return null;
    final rawUrl =
        resolveDiaryMemoryMediaUrl(data) ??
        data['imageUrl']?.toString() ??
        data['photoUrl']?.toString() ??
        data['thumbUrl']?.toString() ??
        '';
    final uri = Uri.tryParse(rawUrl.trim());
    final photoUrl =
        !privateMedia &&
            uri != null &&
            const ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty &&
            !isDiaryMemoryVideoUrl(rawUrl)
        ? rawUrl.trim()
        : '';
    final text = (data['content'] ?? data['text'] ?? data['caption'] ?? '')
        .toString()
        .trim();
    if (!privateMedia && photoUrl.isEmpty && text.isEmpty) return null;
    final rawTime = data['timestamp'] ?? data['ts'] ?? data['createdAt'];
    final timestamp = rawTime is Timestamp
        ? rawTime.millisecondsSinceEpoch
        : rawTime is num
        ? rawTime.toInt()
        : 0;
    return SoulMergeMemory(
      id: '${legacy ? 'legacy' : 'diary'}:$memoryId',
      houseId: houseId,
      memoryId: legacy && !privateMedia ? '' : memoryId,
      privateMedia: privateMedia,
      imageUrl: photoUrl,
      text: text,
      mood: data['mood']?.toString() ?? '💖',
      timestamp: timestamp,
    );
  }
}

typedef SoulMergeDiaryLoader =
    Future<List<Map<String, dynamic>>> Function(String houseId);
typedef SoulMergeLegacyLoader =
    Future<List<SoulMergeMemory>> Function(String houseId);
typedef SoulMergeCacheLookup =
    Future<Set<String>> Function(
      String uid,
      String houseId,
      List<SoulMergeMemory> memories,
    );

/// Dùng chung catalog Nhật ký đã giới hạn/cache với các màn ảnh kỷ niệm.
/// Chỉ tra chỉ mục cache ở đây; tối đa ba thẻ đang hiện mới được tải ảnh.
class SoulMergeMemories {
  SoulMergeMemories({
    String? Function()? currentUid,
    this.loadDiary,
    this.loadLegacy,
    this.cachedIds,
  }) : _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final String? Function() _currentUid;
  final SoulMergeDiaryLoader? loadDiary;
  final SoulMergeLegacyLoader? loadLegacy;
  final SoulMergeCacheLookup? cachedIds;
  SoulBlockMemoryService? _catalog;
  bool _disposed = false;

  Future<List<SoulMergeMemory>> load({
    required String uid,
    required String houseId,
  }) async {
    bool current() => !_disposed && _currentUid() == uid;
    if (!current() || houseId.trim().isEmpty) return const [];
    final diary = await _safe(() async {
      final raw =
          await (loadDiary?.call(houseId) ??
              (_catalog ??= SoulBlockMemoryService()).candidates(
                houseId,
                limit: 40,
                rankForPlay: false,
              ));
      return [
        for (final data in raw.take(40))
          ?SoulMergeMemory.fromDiary(houseId, data),
      ];
    });
    if (!current()) return const [];
    // Có ảnh Nhật ký hiện tại thì dùng ngay, không chờ/đọc hai collection cũ.
    final legacy = diary.any((item) => item.hasPhoto)
        ? <SoulMergeMemory>[]
        : await _safe(() => (loadLegacy ?? _legacy)(houseId));
    if (!current()) return const [];
    final sources = [diary, legacy];
    final seen = <String>{};
    final memories = <SoulMergeMemory>[];
    for (final memory in sources.expand((source) => source)) {
      if (memory.houseId != houseId) continue;
      final key = memory.privateMedia
          ? 'private:${memory.memoryId}'
          : memory.hasPhoto
          ? memory.imageUrl
          : 'text:${memory.timestamp}:${memory.text}';
      if (seen.add(key)) memories.add(memory);
    }
    Set<String> cached = const {};
    try {
      cached = await (cachedIds ?? _lookupCache)(uid, houseId, memories);
    } catch (_) {
      // Không có chỉ mục cache vẫn hiện ảnh theo ngày, không chặn kết nối.
    }
    if (!current()) return const [];
    memories.sort((a, b) {
      int rank(SoulMergeMemory item) =>
          item.hasPhoto ? (cached.contains(item.id) ? 0 : 1) : 2;
      final order = rank(a).compareTo(rank(b));
      return order != 0 ? order : b.timestamp.compareTo(a.timestamp);
    });
    if (memories.isNotEmpty) return memories;
    return [
      for (final entry in [('one', '💖'), ('two', '🥰')])
        SoulMergeMemory(
          id: 'fallback:${entry.$1}',
          houseId: houseId,
          mood: entry.$2,
          text: L10nService().translate('p4_soul_memory_fallback_${entry.$1}'),
        ),
    ];
  }

  Future<List<SoulMergeMemory>> _safe(
    Future<List<SoulMergeMemory>> Function() load,
  ) async {
    try {
      return await load();
    } catch (error) {
      // Không in URL hoặc nội dung Nhật ký riêng tư vào log.
      if (kDebugMode) {
        debugPrint(
          '[SoulMergeMemories] source unavailable: ${AppErrorMapper.resolve(error).kind.name}',
        );
      }
      return const [];
    }
  }

  Future<List<SoulMergeMemory>> _legacy(String houseId) async {
    final sources = await Future.wait([
      for (final collection in ['album', 'diaries'])
        _safe(() async {
          final snapshot = await FirebaseFirestore.instance
              .collection('houses')
              .doc(houseId)
              .collection(collection)
              .orderBy('ts', descending: true)
              .limit(15)
              .get()
              .timeout(const Duration(seconds: 8));
          return [
            for (final doc in snapshot.docs)
              ?SoulMergeMemory.fromDiary(houseId, {
                ...doc.data(),
                'id': doc.id,
              }, legacy: true),
          ];
        }),
    ]);
    return sources.expand((items) => items).toList();
  }

  Future<Set<String>> _lookupCache(
    String uid,
    String houseId,
    List<SoulMergeMemory> memories,
  ) async {
    final cached = <String>{};
    if (!kIsWeb) {
      final ids = await PrivateImageDiskCache.instance.cachedMemoryIds(
        uid,
        houseId,
        memories
            .where((item) => item.memoryId.isNotEmpty)
            .map((item) => item.memoryId),
        [640, 1600, 1024, 768, 720, null],
        anySize: true,
      );
      cached.addAll(
        memories
            .where((item) => ids.contains(item.memoryId))
            .map((item) => item.id),
      );
    }
    await Future.wait(
      memories.where((item) => item.hasPhoto && !item.privateMedia).map((
        item,
      ) async {
        try {
          final provider = CachedNetworkImageProvider(item.imageUrl);
          final status = await provider.obtainCacheStatus(
            configuration: const ImageConfiguration(),
          );
          if (status?.keepAlive == true || status?.live == true) {
            cached.add(item.id);
            return;
          }
          if (!kIsWeb) {
            final file = await DefaultCacheManager().getFileFromCache(
              item.imageUrl,
            );
            if (file != null && file.validTill.isAfter(DateTime.now())) {
              cached.add(item.id);
            }
          }
        } catch (_) {
          // Cache không khả dụng thì giữ thứ tự ảnh mới nhất; không tải để dò cache.
        }
      }),
    );
    return cached;
  }

  void dispose() {
    _disposed = true;
    _catalog?.dispose();
  }
}
