// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../utils/services/games/soul_block_image_cache.dart';
import '../../../utils/services/games/soul_block_memory_service.dart';
import '../../../utils/services/offline_cache_service.dart';
import '../../../utils/services/storage/private_image_disk_cache.dart';
import '../../home/tabs/diary/utils/diary_memory_media.dart';
import '../../home/tabs/diary/utils/private_memory_link_policy.dart';
import 'memory_puzzle_photo.dart';

typedef PuzzleImageLoader =
    Future<ui.Image?> Function(
      String id,
      Map<String, dynamic>? metadata,
      bool cacheOnly,
    );

/// Phiên cục bộ theo UID/House, không tạo một kho ảnh hoặc URL ký thứ hai.
/// Mỗi màn chỉ lấy một bitmap; tất cả mảnh ghép dùng chung bitmap đó.
class MemoryPuzzleSession {
  MemoryPuzzleSession({
    required this.isCurrent,
    required this.fetchCandidates,
    required this.cachedIds,
    required this.loadImage,
    required this.readState,
    required this.writeState,
    required this.isOnline,
    this.onAccessDenied,
    this.onDispose,
    Random? random,
    DateTime Function()? now,
  }) : _random = random ?? Random(),
       _now = now ?? DateTime.now;

  factory MemoryPuzzleSession.forHouse({
    required String uid,
    required String houseId,
    required bool Function() isCurrent,
    required void Function() onAccessDenied,
    int diaryWidth = 640,
  }) {
    final memories = SoulBlockMemoryService();
    final cache = SoulBlockImageCache.instance;
    // Prefix này được luồng đăng xuất/dọn cache hiện hữu xóa cùng cache khác.
    final key = 'memory_puzzle_v1:${jsonEncode([uid, houseId])}';
    return MemoryPuzzleSession(
      isCurrent: isCurrent,
      onAccessDenied: onAccessDenied,
      onDispose: memories.dispose,
      fetchCandidates: ({preferredId}) => memories.candidates(
        houseId,
        preferredId: preferredId,
        diaryWidth: diaryWidth,
        rankForPlay: false,
      ),
      cachedIds: (ids) => cache.cachedIds(
        uid: uid,
        houseId: houseId,
        ids: ids,
        diaryWidth: diaryWidth,
      ),
      loadImage: (id, metadata, cacheOnly) => cache.load(
        uid: uid,
        houseId: houseId,
        id: id,
        diaryWidth: diaryWidth,
        resolveUrl: () async {
          if (cacheOnly || metadata == null || !isCurrent()) return null;
          return (await memories.resolve(houseId, metadata))?.url;
        },
      ),
      readState: () async {
        Map<String, dynamic> state = {};
        try {
          final raw = await OfflineCacheService.loadCache(key);
          if (raw is Map) state = Map<String, dynamic>.from(raw);
        } catch (_) {
          // Snapshot hỏng không được chặn một ván mới.
        }
        if (!isCurrent()) return {};
        if (state['ids'] == null) {
          // Lần đầu vào game offline vẫn dùng được ảnh Nhật ký đã xem.
          final diary = await OfflineCacheService.loadCache(
            'memories_$houseId',
          );
          if (!isCurrent()) return {};
          if (diary is Map && diary['items'] is List) {
            state['catalogAt'] = diary['_cachedAt'];
            state['ids'] = [
              for (final item in diary['items'] as List)
                if (item is Map &&
                    item['id'] is String &&
                    !isDiaryMemoryVideo(Map<Object?, Object?>.from(item)) &&
                    item['deletedAt'] == null &&
                    item['isDeleted'] != true)
                  item['id'],
            ].take(80).toList();
          }
        }
        return state;
      },
      writeState: (state) async {
        if (!isCurrent()) return;
        await OfflineCacheService.saveCache(key, state);
      },
      isOnline: () async {
        try {
          final connections = await Connectivity().checkConnectivity();
          return connections.any((value) => value != ConnectivityResult.none);
        } catch (_) {
          return true; // Lỗi plugin không đồng nghĩa chắc chắn mất mạng.
        }
      },
    );
  }

  final bool Function() isCurrent;
  final Future<List<Map<String, dynamic>>> Function({String? preferredId})
  fetchCandidates;
  final Future<Set<String>> Function(Iterable<String>) cachedIds;
  final PuzzleImageLoader loadImage;
  final Future<Map<String, dynamic>> Function() readState;
  final Future<void> Function(Map<String, dynamic>) writeState;
  final Future<bool> Function() isOnline;
  final void Function()? onAccessDenied;
  final void Function()? onDispose;
  final Random _random;
  final DateTime Function() _now;
  Map<String, dynamic> _state = {};
  List<Map<String, dynamic>>? _catalog;
  DateTime? _catalogAt;
  Future<void>? _initializing;
  Future<void> _writes = Future<void>.value();
  bool _disposed = false;
  bool _denied = false;
  bool get _current => !_disposed && !_denied && isCurrent();

  static List<Map<String, dynamic>> photoCandidates(Object? raw) {
    if (raw is! Map) return [];
    return [
          for (final entry in raw.entries)
            if (entry.value is Map)
              Map<String, dynamic>.from(entry.value as Map)
                ..['id'] = entry.key.toString(),
        ]
        .where((item) {
          if (item['deletedAt'] != null ||
              item['isDeleted'] == true ||
              isDiaryMemoryVideo(Map<Object?, Object?>.from(item)))
            return false;
          if (PrivateMemoryLinkPolicy.isPrivate(item)) return true;
          final uri = Uri.tryParse(
            resolveDiaryMemoryMediaUrl(Map<Object?, Object?>.from(item)) ??
                item['imageUrl']?.toString() ??
                item['photoUrl']?.toString() ??
                '',
          );
          return uri != null &&
              const ['https', 'http'].contains(uri.scheme) &&
              uri.host.isNotEmpty;
        })
        .take(80)
        .toList();
  }

  Future<void> _initialize() => _initializing ??= () async {
    final state = await readState();
    if (_current) _state = state;
  }();

  List<String> _strings(String key) => (_state[key] is List)
      ? (_state[key] as List)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .take(80)
            .toList()
      : <String>[];

  Future<Map<String, dynamic>?> loadProgress() async {
    await _initialize();
    final progress = _state['progress'];
    return _current && progress is Map
        ? Map<String, dynamic>.from(progress)
        : null;
  }

  Future<void> saveProgress(Map<String, dynamic> progress) async {
    await _initialize();
    if (!_current) return;
    // Không lưu ảnh hay URL trong snapshot tiến độ.
    _state['progress'] = Map<String, dynamic>.from(progress);
    await _persist();
  }

  Future<void> _persist() {
    final snapshot = Map<String, dynamic>.from(_state);
    final write = _writes.then((_) async {
      if (_current) await writeState(snapshot);
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }

  bool _isAccessError(Object error) =>
      error is FirebaseException &&
      const {
        'permission-denied',
        'unauthenticated',
        'unauthorized',
      }.contains(error.code);

  Future<MemoryPuzzlePhoto?> loadPhoto({
    String? excludePhotoId,
    String? preferredPhotoId,
  }) async {
    await _initialize();
    if (!_current) return null;
    var online = await isOnline();
    if (!_current) return null;
    if (online &&
        (_catalog == null ||
            _now().difference(_catalogAt!) >= const Duration(minutes: 10) ||
            (preferredPhotoId != null &&
                !_catalog!.any((item) => item['id'] == preferredPhotoId)))) {
      try {
        final candidates = await fetchCandidates(preferredId: preferredPhotoId);
        if (!_current) return null;
        _catalog = candidates;
        _catalogAt = _now();
        _state['ids'] = candidates.map((item) => item['id'] as String).toList();
        _state['catalogAt'] = _now().millisecondsSinceEpoch;
        try {
          await _persist();
        } catch (_) {
          // Lỗi ghi local không biến kết nối đang hoạt động thành offline.
        }
      } catch (error) {
        if (!_current) return null;
        if (_isAccessError(error)) {
          _denied = true;
          onAccessDenied?.call();
          return null;
        }
        online = false;
      }
    }
    final savedAt = (_state['catalogAt'] as num?)?.toInt() ?? 0;
    final age = _now().millisecondsSinceEpoch - savedAt;
    final validOfflineIds =
        age >= 0 && age < PrivateImageDiskCache.ttl.inMilliseconds;
    final candidates = <String, Map<String, dynamic>?>{
      if (!online && validOfflineIds)
        for (final id in _strings('ids')) id: null,
      if (online && _catalog != null)
        for (final item in _catalog!) item['id'] as String: item,
    };
    // Khôi phục chỉ được phép dùng đúng ảnh cũ; không đặt mảnh cũ lên ảnh mới.
    if (preferredPhotoId != null && !candidates.containsKey(preferredPhotoId)) {
      if (!online && validOfflineIds)
        candidates[preferredPhotoId] = null;
      else
        return null;
    }
    final cached = await cachedIds([
      ?preferredPhotoId,
      ...candidates.keys.where((id) => id != preferredPhotoId),
    ]);
    if (!_current) return null;
    final recent = _strings('recent');
    final ids = candidates.keys.toList()..shuffle(_random);
    final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    int rank(String id) {
      if (id == preferredPhotoId) return -1000;
      if (id == excludePhotoId) return 1000;
      final index = recent.indexOf(id);
      return index < 0 ? 0 : recent.length - index;
    }

    ids.sort((a, b) {
      final comparison = rank(a).compareTo(rank(b));
      return comparison != 0 ? comparison : order[a]!.compareTo(order[b]!);
    });
    final eligible = preferredPhotoId == null ? ids : [preferredPhotoId];
    // Ảnh chưa chơi nhưng cần tải được chọn khi có mạng; offline chỉ xét cache.
    // Tối đa 2 lần thử tải; không prefetch cả album và không có GET theo từng mảnh.
    var downloads = 0;
    for (final id in eligible) {
      if (!_current) return null;
      ui.Image? image;
      var fromCache = false;
      try {
        if (cached.contains(id)) {
          image = await loadImage(id, candidates[id], true);
          fromCache = image != null;
        }
        if (image == null &&
            online &&
            candidates[id] != null &&
            downloads < 2) {
          downloads++;
          image = await loadImage(id, candidates[id], false);
        }
        if (!_current) {
          image?.dispose();
          return null;
        }
        if (image == null) continue;
        _state['recent'] = [
          id,
          ...recent.where((entry) => entry != id),
        ].take(80).toList();
        try {
          await _persist();
        } catch (_) {
          /* Ảnh vẫn chơi được khi ổ đĩa đầy. */
        }
        if (!_current) {
          image.dispose();
          return null;
        }
        return MemoryPuzzlePhoto(
          id: id,
          image: image,
          fromCache: fromCache,
          offline: !online,
          availablePhotos: online ? candidates.length : cached.length,
        );
      } catch (error) {
        image?.dispose();
        if (_isAccessError(error)) {
          _denied = true;
          onAccessDenied?.call();
          return null;
        }
      }
    }
    return null;
  }

  void dispose() {
    _disposed = true;
    _catalog = null;
    onDispose?.call();
  }
}
