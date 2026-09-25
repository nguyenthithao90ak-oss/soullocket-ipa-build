import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, ValueNotifier, debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart';
import '../../../../../core/constants/app_config.dart';
import '../../../../../utils/services/storage/private_memory_lifecycle_policy.dart';
import '../../../../../utils/services/private_media_url_service.dart';
import '../utils/private_memory_link_policy.dart';
import '../../../../../core/sl_theme.dart';
import '../../../../../utils/services/map_pin_limit_service.dart';
import '../../../../../utils/services/activity_history_service.dart';
import '../../../../../utils/helpers/date_highlight_helper.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/services/notification_service.dart';
import '../../../../../utils/services/offline_cache_service.dart';
import '../../../../../utils/services/purchase_service.dart';
import '../../../../../utils/services/security_service.dart';
import '../../../../../utils/services/storage/storage_service.dart';
import '../utils/diary_memory_upload_commit.dart';
import 'diary_feed_controller.dart';
import 'diary_guard_controller.dart';
import '../../../../ui_prefs.dart';
import 'package:vision_gallery_saver/vision_gallery_saver.dart';
import '../../../../../utils/app_error_mapper.dart';

typedef DiaryMemoryFlattenedItem = ({
  bool isHeader,
  DateTime? date,
  String? dateString,
  int? totalPhotos,
  List<Map<String, dynamic>>? photosRow,
  List<Map<String, dynamic>>? groupPhotos,
  List<Map<String, String>> highlights,
});

class PreparedDiaryMemoryFeed {
  final List<Map<String, dynamic>> photos;
  final List<DiaryMemoryFlattenedItem> flattenedItems;
  final bool showingCache;
  final bool canLoadMore;

  const PreparedDiaryMemoryFeed({
    required this.photos,
    required this.flattenedItems,
    required this.showingCache,
    required this.canLoadMore,
  });
}

class DiaryMemoryController extends ChangeNotifier {
  DiaryMemoryController({
    DatabaseReference? dbRef,
    StorageService? storageService,
  }) : _dbRef = dbRef ?? FirebaseDatabase.instance.ref(),
       _storageService = storageService ?? StorageService() {
    _resetMemoriesPagination();
  }

  static const int _webMemoryCacheLimit = 120;
  static const int _appMemoryCacheLimit = 200;
  static const Duration _memoryDownloadCacheTtl = Duration(days: 7);
  static const String _pendingUploadPrefsKey = 'diary_memory_pending_upload_v1';

  final DatabaseReference _dbRef;
  final StorageService _storageService;
  final PrivateMediaUrlService _privateMediaUrlService =
      PrivateMediaUrlService();
  final MapPinLimitService _mapPinLimitService = MapPinLimitService();

  final ValueNotifier<int> selectionTickVN = ValueNotifier<int>(0);

  String? _currentHouseId;
  String? _cachedHouseIdForMemories;
  Query? _memoriesQuery;
  Stream<DatabaseEvent>? _memoriesStream;
  Future<dynamic>? _memoriesCacheFuture;
  String? _memoriesCacheHouseId;
  String? _lastMemoriesCacheSignature;
  bool _isSelectionMode = false;
  final Map<String, Map<String, dynamic>> _selectedMemories =
      <String, Map<String, dynamic>>{};
  int? _memoryVisibleLimit;
  bool _isLoadingMoreMemories = false;
  PreparedDiaryMemoryFeed? _preparedMemoryFeed;
  Object? _preparedMemorySource;
  String _preparedMemorySourceKind = '';
  int _preparedMemoryLimit = 0;
  String _preparedMemoryHighlightKey = '';
  Object? _lastCachedLiveMemoriesSource;
  List<String> _pendingUploadPaths = const <String>[];
  String? _pendingUploadMessage;
  final Map<String, XFile> _pendingFiles = {};
  final Map<String, Map<String, dynamic>> _stagedUploads = {};
  String? _pendingOwner;
  String? _pendingHouse;
  bool _preparingUpload = false;
  bool _isUploadingMemories = false;
  bool _isDisposed = false;
  final Map<String, Future<PrivateMediaUrlResult>> _pendingUrlResolves =
      <String, Future<PrivateMediaUrlResult>>{};
  int _mediaScopeGeneration = 0;

  bool get isSelectionMode => _isSelectionMode;
  int get selectedMemoriesCount => _selectedMemories.length;
  Map<String, Map<String, dynamic>> get selectedMemories => _selectedMemories;
  bool get isLoadingMoreMemories => _isLoadingMoreMemories;
  bool get isUploadingMemories => _isUploadingMemories;
  bool get hasPendingUploadRetry =>
      !_isUploadingMemories && _pendingUploadPaths.isNotEmpty;
  String get pendingUploadMessage =>
      _pendingUploadMessage ??
      L10nService().translate('home_lnuploadkn_c9bdf8');

  int get _memoryCacheLimit =>
      kIsWeb ? _webMemoryCacheLimit : _appMemoryCacheLimit;

  int get _memoryQueryLimit => _memoryVisibleLimit ?? _memoryCacheLimit;

  int get _memoryLoadMoreStep => AppConfig.albumPageSize;

  void _notifyIfActive() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  void _setPendingUploadState(
    List<String> paths, {
    String? message,
    bool notify = true,
  }) {
    _pendingUploadPaths = List<String>.unmodifiable(paths);
    _pendingUploadMessage = message;
    if (notify) {
      _notifyIfActive();
    }
  }

  Future<List<String>> _extractRecoverableImagePaths(List<XFile> images) async {
    final paths = <String>[];
    for (final image in images) {
      final path = image.path.trim();
      if (path.isEmpty) continue;
      _pendingFiles[path] = image;
      paths.add(path);
    }
    return paths;
  }

  Future<void> _savePendingUploadState({
    required String houseId,
    required List<String> paths,
    String? message,
  }) async {
    final normalizedPaths = <String>[
      for (final path in paths)
        if (path.trim().isNotEmpty) path.trim(),
    ];
    if (normalizedPaths.isEmpty) {
      await _clearPendingUploadState(notify: message != null);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _pendingUploadPrefsKey,
      jsonEncode(<String, dynamic>{
        'houseId': houseId.trim(),
        'uid': _pendingOwner,
        'staged': _stagedUploads,
        'paths': normalizedPaths,
      }),
    );
    if (!saved) throw StateError('Could not persist pending upload');
    _setPendingUploadState(normalizedPaths, message: message);
  }

  Future<void> _clearPendingUploadState({bool notify = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingUploadPrefsKey);
    _stagedUploads.clear();
    _pendingFiles.clear();
    if (_pendingUploadPaths.isEmpty && _pendingUploadMessage == null) {
      return;
    }
    _setPendingUploadState(const <String>[], message: null, notify: notify);
  }

  /// Public method to clear pending upload state (e.g., after user re-login).
  Future<void> clearPendingUploadState({bool notify = true}) async {
    await _clearPendingUploadState(notify: notify);
  }

  Future<void> _restorePendingUploadState() async {
    final houseId = _currentHouseId?.trim() ?? '';
    if (houseId.isEmpty) {
      if (_pendingUploadPaths.isNotEmpty || _pendingUploadMessage != null) {
        _setPendingUploadState(const <String>[], message: null);
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingUploadPrefsKey);
    if (raw == null || raw.isEmpty) {
      if (_pendingUploadPaths.isNotEmpty || _pendingUploadMessage != null) {
        _setPendingUploadState(const <String>[], message: null);
      }
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _clearPendingUploadState();
        return;
      }

      final savedHouseId = decoded['houseId']?.toString().trim() ?? '';
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (savedHouseId != houseId || decoded['uid'] != uid) {
        _stagedUploads.clear();
        _pendingFiles.clear();
        if (_pendingUploadPaths.isNotEmpty || _pendingUploadMessage != null) {
          _setPendingUploadState(const <String>[], message: null);
        }
        return;
      }

      if (_isDisposed || _currentHouseId != houseId) return;
      _pendingOwner = uid;
      _pendingHouse = houseId;
      final staged = decoded['staged'];
      if (staged is Map) {
        _stagedUploads.addAll({
          for (final entry in staged.entries)
            if (entry.value is Map)
              entry.key.toString(): Map<String, dynamic>.from(
                entry.value as Map,
              ),
        });
      }
      final rawPaths = decoded['paths'];
      if (rawPaths is! List) {
        await _clearPendingUploadState();
        return;
      }

      final recoverablePaths = <String>[];
      for (final value in rawPaths) {
        final path = value?.toString().trim() ?? '';
        if (path.isEmpty) {
          continue;
        }
        if (_stagedUploads.containsKey(path) ||
            _pendingFiles.containsKey(path)) {
          recoverablePaths.add(path);
          continue;
        }
        if (kIsWeb) continue;
        try {
          if (await XFile(path).length() > 0) {
            recoverablePaths.add(path);
          }
        } catch (_) {
          // skip unrecoverable files
        }
      }

      if (recoverablePaths.isEmpty) {
        await _clearPendingUploadState();
        return;
      }

      _setPendingUploadState(
        recoverablePaths,
        message: L10nService().translate('home_lnuploadkn_c9bdf8'),
      );
    } catch (_) {
      await _clearPendingUploadState();
    }
  }

  Future<void> _removePendingUploadedImages(List<XFile> uploadedImages) async {
    if (_pendingUploadPaths.isEmpty) {
      return;
    }
    final uploadedPaths = <String>{
      for (final image in uploadedImages)
        if (image.path.trim().isNotEmpty) image.path.trim(),
    };
    if (uploadedPaths.isEmpty) {
      return;
    }
    for (final path in uploadedPaths) {
      _stagedUploads.remove(path);
      _pendingFiles.remove(path);
    }
    final remaining = _pendingUploadPaths
        .where((path) => !uploadedPaths.contains(path))
        .toList();
    final houseId = _currentHouseId?.trim() ?? '';
    if (remaining.isEmpty || houseId.isEmpty) {
      await _clearPendingUploadState();
      return;
    }
    await _savePendingUploadState(
      houseId: houseId,
      paths: remaining,
      message: L10nService().format('home_memory_remaining_upload', {
        'count': remaining.length,
      }),
    );
  }

  Future<List<XFile>> _buildPendingUploadFiles() async {
    final files = <XFile>[];
    for (final path in _pendingUploadPaths) {
      final normalized = path.trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (_stagedUploads.containsKey(normalized) ||
          _pendingFiles.containsKey(normalized)) {
        files.add(_pendingFiles[normalized] ?? XFile(normalized));
        continue;
      }
      if (kIsWeb) continue;
      try {
        final file = XFile(normalized);
        if (await file.length() > 0) {
          files.add(file);
        }
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/home/tabs/diary/controllers/diary_memory_controller.dart: $error',
        );
      }
    }
    return files;
  }

  String? _normalizeHouseId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _notifySelectionChanged() {
    selectionTickVN.value++;
  }

  void syncHouseId(String? houseId) {
    final normalized = _normalizeHouseId(houseId);
    if (_currentHouseId == normalized && _memoriesStream != null) {
      return;
    }
    _currentHouseId = normalized;
    _mediaScopeGeneration++;
    _pendingUrlResolves.clear();
    _pendingFiles.clear();
    _stagedUploads.clear();
    _setPendingUploadState(const [], notify: false);
    _lastMemoriesCacheSignature = null;
    _resetMemoriesPagination();
    _resetMemoriesStreamCache();
    _exitSelectionMode(notify: false);
    _notifyIfActive();
    unawaited(_restorePendingUploadState());
  }

  void handleTabChanged(String tab) {
    if (tab == 'memory' || _selectedMemories.isEmpty) {
      return;
    }
    _exitSelectionMode(notify: true);
  }

  void toggleSelectionMode(Map<String, dynamic> photo) {
    final id = photo['id'] as String?;
    if (id == null || id.isEmpty) {
      return;
    }

    if (_isSelectionMode) {
      if (_selectedMemories.containsKey(id)) {
        _selectedMemories.remove(id);
        if (_selectedMemories.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMemories[id] = photo;
      }
    } else {
      _isSelectionMode = true;
      _selectedMemories[id] = photo;
    }

    _notifySelectionChanged();
    notifyListeners();
  }

  int selectAllVisibleMemories() {
    final photos =
        _preparedMemoryFeed?.photos ?? const <Map<String, dynamic>>[];
    if (photos.isEmpty) {
      return 0;
    }

    int validPhotoCount = 0;
    for (final photo in photos) {
      final id = photo['id'] as String?;
      if (id != null && id.isNotEmpty) {
        validPhotoCount++;
      }
    }

    if (validPhotoCount > 0 && _selectedMemories.length >= validPhotoCount) {
      // Đã chọn toàn bộ, ấn lần nữa thì hủy toàn bộ
      exitSelectionMode();
      return 0;
    }

    for (final photo in photos) {
      final id = photo['id'] as String?;
      if (id == null || id.isEmpty) {
        continue;
      }
      _selectedMemories[id] = photo;
    }

    if (_selectedMemories.isEmpty) {
      return 0;
    }

    _isSelectionMode = true;
    _notifySelectionChanged();
    notifyListeners();
    return _selectedMemories.length;
  }

  void exitSelectionMode() {
    _exitSelectionMode(notify: true);
  }

  void _exitSelectionMode({required bool notify}) {
    if (!_isSelectionMode && _selectedMemories.isEmpty) {
      return;
    }

    _isSelectionMode = false;
    _selectedMemories.clear();
    _notifySelectionChanged();
    if (notify) {
      notifyListeners();
    }
  }

  void _resetMemoriesPagination() {
    _memoryVisibleLimit = _memoryCacheLimit;
    _isLoadingMoreMemories = false;
  }

  void loadMoreMemories() {
    if (_isLoadingMoreMemories) {
      return;
    }
    _isLoadingMoreMemories = true;
    _memoryVisibleLimit = _memoryQueryLimit + _memoryLoadMoreStep;
    // ⚡ Không reset stream cache — giữ dữ liệu cũ làm fallback
    // trong khi chờ stream mới gửi về, tránh flash trắng
    _cachedHouseIdForMemories = null;
    _memoriesQuery = null;
    _memoriesStream = null;
    _memoriesCacheFuture = null;
    _memoriesCacheHouseId = null;
    // Giữ _preparedMemoryFeed để UI không bị mất dữ liệu tạm thời
    notifyListeners();
  }

  void finishLoadingMoreIfNeeded(
    bool waitingForLive, {
    required void Function(VoidCallback callback) schedulePostFrame,
  }) {
    if (!_isLoadingMoreMemories || waitingForLive) {
      return;
    }

    schedulePostFrame(() {
      if (!_isLoadingMoreMemories) {
        return;
      }
      _isLoadingMoreMemories = false;
      notifyListeners();
    });
  }

  void _resetMemoriesStreamCache() {
    _cachedHouseIdForMemories = null;
    _memoriesQuery = null;
    _memoriesStream = null;
    _memoriesCacheFuture = null;
    _memoriesCacheHouseId = null;
    _clearPreparedMemoryFeedCache();
  }

  void _clearPreparedMemoryFeedCache() {
    _preparedMemoryFeed = null;
    _preparedMemorySource = null;
    _preparedMemorySourceKind = '';
    _preparedMemoryLimit = 0;
    _preparedMemoryHighlightKey = '';
    _lastCachedLiveMemoriesSource = null;
  }

  Stream<DatabaseEvent>? getMemoriesStream(String? houseId) {
    final normalizedHouseId = _normalizeHouseId(houseId);
    if (normalizedHouseId == null) {
      return null;
    }
    if (_cachedHouseIdForMemories != normalizedHouseId ||
        _memoriesQuery == null ||
        _memoriesStream == null) {
      _cachedHouseIdForMemories = normalizedHouseId;
      unawaited(
        _storageService.cleanupExpiredMemoryTrashIfNeeded(normalizedHouseId),
      );
      _memoriesQuery = _dbRef
          .child('houses/$normalizedHouseId/memories')
          .orderByChild('ts')
          .limitToLast(_memoryQueryLimit);
      _memoriesStream = _memoriesQuery!.onValue;
    }
    return _memoriesStream;
  }

  Future<dynamic> getMemoriesCacheFuture(String? houseId) {
    final normalizedHouseId = _normalizeHouseId(houseId);
    if (normalizedHouseId == null) {
      return Future<dynamic>.value(null);
    }
    if (_memoriesCacheHouseId != normalizedHouseId ||
        _memoriesCacheFuture == null) {
      _memoriesCacheHouseId = normalizedHouseId;
      _memoriesCacheFuture = OfflineCacheService.loadCache(
        'memories_$normalizedHouseId',
      ).then(_extractMemoriesCacheList);
    }
    return _memoriesCacheFuture!;
  }

  dynamic getMemoriesCacheSync(String? houseId) {
    final normalizedHouseId = _normalizeHouseId(houseId);
    if (normalizedHouseId == null) {
      return null;
    }
    final raw = OfflineCacheService.loadCacheSync(
      'memories_$normalizedHouseId',
    );
    return _extractMemoriesCacheList(raw);
  }

  /// Giải nén và kiểm tra TTL của memories cache.
  /// Cache lưu dưới dạng {_cachedAt: ms, items: [...]}.
  /// Nếu quá _memoryDownloadCacheTtl (7 ngày) thì trả về null để app fetch lại.
  dynamic _extractMemoriesCacheList(dynamic raw) {
    if (raw == null) return null;
    // Format mới: {_cachedAt, items}
    if (raw is Map) {
      final cachedAt = (raw['_cachedAt'] as num?)?.toInt() ?? 0;
      final ttlMs = _memoryDownloadCacheTtl.inMilliseconds;
      if (DateTime.now().millisecondsSinceEpoch - cachedAt > ttlMs) {
        return null; // Cache hết hạn — app sẽ dùng live data
      }
      return _withoutCachedMemoryLinks(raw['items']);
    }
    // Format cũ: List thẳng (backward compat — không có TTL nên chấp nhận)
    if (raw is List) return _withoutCachedMemoryLinks(raw);
    return null;
  }

  List<Map<String, dynamic>>? _withoutCachedMemoryLinks(dynamic items) {
    if (items is! List) return null;
    return [
      for (final item in items)
        if (item is Map)
          PrivateMemoryLinkPolicy.offlineMetadata(
            Map<String, dynamic>.from(item),
          ),
    ];
  }

  int _readCacheTs(Map<String, dynamic> item) {
    final raw = item['ts'] ?? item['timestamp'] ?? item['date'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _buildCacheSignature(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return '0';
    }

    final first = items.first;
    final last = items.last;
    final firstId = first['id']?.toString() ?? '';
    final lastId = last['id']?.toString() ?? '';
    final firstTs = _readCacheTs(first);
    final lastTs = _readCacheTs(last);
    return '${items.length}|$firstId|$firstTs|$lastId|$lastTs';
  }

  Future<void> _cacheMemories(String houseId, Object? rawValue) async {
    if (rawValue == null || rawValue is! Map) {
      return;
    }

    final data = Map<dynamic, dynamic>.from(rawValue);
    final cacheList = <Map<String, dynamic>>[];
    data.forEach((key, value) {
      if (value is! Map) {
        return;
      }
      final item = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value));
      item['id'] = key;
      cacheList.add(PrivateMemoryLinkPolicy.offlineMetadata(item));
    });

    cacheList.sort((a, b) => _readCacheTs(b).compareTo(_readCacheTs(a)));
    final limited = cacheList.take(_memoryCacheLimit).toList(growable: false);
    final signature = _buildCacheSignature(limited);
    if (_lastMemoriesCacheSignature == signature) {
      return;
    }
    _lastMemoriesCacheSignature = signature;
    // Lưu kèm timestamp để hỗ trợ TTL khi đọc lại
    await OfflineCacheService.saveCache('memories_$houseId', {
      '_cachedAt': DateTime.now().millisecondsSinceEpoch,
      'items': limited,
    });
  }

  bool _isMemoryUrlExpired(Map<String, dynamic> item) {
    return PrivateMemoryLinkPolicy.isExpired(
      item,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> ensureMemoryPhotoUrl({
    required String houseId,
    required Map<String, dynamic> item,
  }) async {
    final existingUrl = item['url']?.toString().trim() ?? '';
    final memoryId = item['id']?.toString().trim() ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final generation = _mediaScopeGeneration;
    bool scopeIsCurrent() =>
        !_isDisposed &&
        generation == _mediaScopeGeneration &&
        _currentHouseId == houseId &&
        FirebaseAuth.instance.currentUser?.uid == uid;
    if (memoryId.isEmpty || uid == null || !scopeIsCurrent()) {
      return;
    }
    if (existingUrl.isNotEmpty && !_isMemoryUrlExpired(item)) {
      return;
    }

    final requestKey = '$uid/$houseId/$memoryId';
    final future = _pendingUrlResolves[requestKey] ??
        _privateMediaUrlService.resolve(
          houseId: houseId,
          mediaId: memoryId,
          kind: 'memory_image',
        );
    _pendingUrlResolves[requestKey] = future;
    try {
      final result = await future;
      if (!scopeIsCurrent()) return;
      // Mỗi caller cập nhật bản sao item của mình, dù dùng chung request mạng.
      item['url'] = result.url;
      item['urlExpiresAt'] = result.expiresAt;
      item['privateMedia'] = true;
      item['storageAccess'] = 'signed';
      // Chỉ giữ URL cấp quyền trong phiên đang mở, không ghi xuống offline cache.
    } catch (e) {
      final message = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('home_khngthtili_5b2994'),
      ).message;
      debugPrint('[DiaryMemory] signed url refresh failed: $message');
    } finally {
      if (identical(_pendingUrlResolves[requestKey], future)) {
        _pendingUrlResolves.remove(requestKey);
      }
    }
  }

  void _normalizeMemoryPhotoUrl(Map<String, dynamic> item) {
    if (PrivateMemoryLinkPolicy.isPrivate(item)) {
      PrivateMemoryLinkPolicy.normalizePrivate(
        item,
        DateTime.now().millisecondsSinceEpoch,
      );
      return;
    }
    final fallbackUrl =
        item['downloadUrl']?.toString().trim().isNotEmpty == true
        ? item['downloadUrl'].toString().trim()
        : item['previewUrl']?.toString().trim().isNotEmpty == true
        ? item['previewUrl'].toString().trim()
        : item['thumbUrl']?.toString().trim() ?? '';
    if (fallbackUrl.isEmpty) {
      return;
    }
    item['resolvedUrl'] = fallbackUrl;
    if ((item['url']?.toString().trim().isEmpty ?? true) ||
        !_isMemoryUrlExpired(item)) {
      item['url'] = fallbackUrl;
    }
  }

  List<Map<String, dynamic>> _memoryPhotosFromSource(
    Object? source, {
    required String? houseId,
    required bool useLiveSource,
    required int limit,
  }) {
    final photos = <Map<String, dynamic>>[];
    if (source == null) {
      return photos;
    }

    if (useLiveSource && source is Map) {
      final data = Map<dynamic, dynamic>.from(source);
      data.forEach((key, value) {
        if (value is! Map) {
          return;
        }
        final item = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(value),
        );
        item['id'] = key.toString();
        item['houseId'] = houseId;
        _normalizeMemoryPhotoUrl(item);
        photos.add(item);
      });
    } else if (!useLiveSource && source is List) {
      for (final item in source.take(limit)) {
        if (item is! Map) {
          continue;
        }
        final normalizedItem = Map<String, dynamic>.from(item);
        normalizedItem['houseId'] = houseId;
        _normalizeMemoryPhotoUrl(normalizedItem);
        photos.add(normalizedItem);
      }
    }

    photos.sort((a, b) => _readCacheTs(b).compareTo(_readCacheTs(a)));
    if (photos.length > limit) {
      return photos.sublist(0, limit);
    }
    return photos;
  }

  List<({DateTime date, List<Map<String, dynamic>> items})> _groupMemoryPhotos(
    List<Map<String, dynamic>> photos,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final photo in photos) {
      final ts = photo['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dateKey, () => <Map<String, dynamic>>[]).add(photo);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedDates
        .map(
          (dateKey) =>
              (date: DateTime.parse(dateKey), items: grouped[dateKey]!),
        )
        .toList(growable: false);
  }

  List<DiaryMemoryFlattenedItem> _buildMemoryFlattenedItems(
    List<Map<String, dynamic>> photos, {
    required DateTime? startDate,
    required String relationshipMode,
  }) {
    final groupedPhotos = _groupMemoryPhotos(photos);
    final flattenedItems = <DiaryMemoryFlattenedItem>[];

    for (final group in groupedPhotos) {
      final dateString = DateFormat('dd/MM/yyyy').format(group.date);
      final highlights = DateHighlightHelper.getDateHighlights(
        group.date.millisecondsSinceEpoch,
        anniversaryDate: startDate,
        includeSpecialDays: relationshipMode != 'single',
      );
      flattenedItems.add((
        isHeader: true,
        date: group.date,
        dateString: dateString,
        totalPhotos: group.items.length,
        photosRow: null,
        groupPhotos: List<Map<String, dynamic>>.from(group.items),
        highlights: highlights,
      ));

      final items = group.items;
      int i = 0;
      while (i < items.length) {
        final remaining = items.length - i;
        int take = 3;
        if (remaining == 4) {
          take = 2; // Split 4 vào 2 hàng (2 và 2) để đẹp hơn
        } else if (remaining < 3) {
          take = remaining;
        }

        flattenedItems.add((
          isHeader: false,
          date: null,
          dateString: null,
          totalPhotos: null,
          photosRow: items.sublist(i, i + take),
          groupPhotos: null,
          highlights: const <Map<String, String>>[],
        ));
        i += take;
      }
    }

    return flattenedItems;
  }

  PreparedDiaryMemoryFeed prepareMemoryFeed({
    required String? houseId,
    required DateTime? startDate,
    required String relationshipMode,
    required Object? liveSource,
    required Object? cacheSource,
    required bool useLiveSource,
    required bool isOffline,
    required bool waitingForLive,
  }) {
    final source = useLiveSource ? liveSource : cacheSource;
    final sourceKind = useLiveSource ? 'live' : 'cache';
    final limit = _memoryQueryLimit;
    final highlightKey =
        '${_normalizeHouseId(houseId)}|${startDate?.millisecondsSinceEpoch ?? 0}|$relationshipMode';

    if (_preparedMemoryFeed != null &&
        identical(_preparedMemorySource, source) &&
        _preparedMemorySourceKind == sourceKind &&
        _preparedMemoryLimit == limit &&
        _preparedMemoryHighlightKey == highlightKey) {
      return _preparedMemoryFeed!;
    }

    final photos = _memoryPhotosFromSource(
      source,
      houseId: _normalizeHouseId(houseId),
      useLiveSource: useLiveSource,
      limit: limit,
    );

    final normalizedHouseId = _normalizeHouseId(houseId);
    if (useLiveSource &&
        source is Map &&
        normalizedHouseId != null &&
        !identical(_lastCachedLiveMemoriesSource, source)) {
      _lastCachedLiveMemoriesSource = source;
      unawaited(_cacheMemories(normalizedHouseId, source));
    }

    final prepared = PreparedDiaryMemoryFeed(
      photos: photos,
      flattenedItems: _buildMemoryFlattenedItems(
        photos,
        startDate: startDate,
        relationshipMode: relationshipMode,
      ),
      showingCache:
          !useLiveSource &&
          cacheSource is List &&
          (isOffline || waitingForLive),
      canLoadMore:
          !isOffline && (photos.length >= limit || _isLoadingMoreMemories),
    );

    _preparedMemoryFeed = prepared;
    _preparedMemorySource = source;
    _preparedMemorySourceKind = sourceKind;
    _preparedMemoryLimit = limit;
    _preparedMemoryHighlightKey = highlightKey;
    return prepared;
  }

  Future<void> updateMemoryGroupDate({
    required String houseId,
    required DateTime selectedDate,
    required List<Map<String, dynamic>> photos,
  }) async {
    final normalizedHouseId = _normalizeHouseId(houseId);
    if (normalizedHouseId == null || photos.isEmpty) {
      return;
    }

    final updates = <String, dynamic>{};
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final editedAt = DateTime.now().millisecondsSinceEpoch;

    for (final photo in photos) {
      final memoryId = photo['id']?.toString().trim() ?? '';
      if (memoryId.isEmpty) {
        continue;
      }
      final oldTs = _readCacheTs(photo);
      final oldDate = oldTs > 0
          ? DateTime.fromMillisecondsSinceEpoch(oldTs)
          : DateTime.now();
      final nextDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        oldDate.hour,
        oldDate.minute,
        oldDate.second,
        oldDate.millisecond,
        oldDate.microsecond,
      );
      final nextTs = nextDate.millisecondsSinceEpoch;
      final path = 'houses/$normalizedHouseId/memories/$memoryId';
      updates['$path/ts'] = nextTs;
      updates['$path/timestamp'] = nextTs;
      updates['$path/date'] = nextTs;
      updates['$path/dateKey'] = dateKey;
      updates['$path/albumDateEditedAt'] = editedAt;

      photo['ts'] = nextTs;
      photo['timestamp'] = nextTs;
      photo['date'] = nextTs;
      photo['dateKey'] = dateKey;
    }

    if (updates.isEmpty) {
      return;
    }

    await _dbRef.update(updates);
    _clearPreparedMemoryFeedCache();
    await OfflineCacheService.saveCache('memories_$normalizedHouseId', null);
    notifyListeners();
  }

  Future<void> _logDeletedMemoriesToActivityHistory({
    required String houseId,
    required List<dynamic> deletedItems,
  }) async {
    if (deletedItems.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('il_role')?.trim() == 'user2'
        ? 'user2'
        : 'user1';

    for (final raw in deletedItems) {
      if (raw is! Map) {
        continue;
      }
      final item = Map<String, dynamic>.from(raw);
      final memoryId = item['memoryId']?.toString().trim() ?? '';
      if (memoryId.isEmpty) {
        continue;
      }
      final previewUrl =
          item['previewUrl']?.toString().trim() ??
          item['url']?.toString().trim() ??
          '';
      final title = item['title']?.toString().trim() ?? '';
      final purgeAt = (item['purgeAt'] as num?)?.toInt() ?? 0;
      final restorePayload = item['restorePayload'] is Map
          ? Map<String, dynamic>.from(item['restorePayload'] as Map)
          : <String, dynamic>{};

      await ActivityHistoryService.instance.add(
        L10nService().translate('home_xanhnhtkkn_97c2ce'),
        houseId: houseId,
        role: role,
        title: L10nService().translate('home_xanhknim_638af9'),
        subtitle: title,
        action: 'delete',
        module: 'diary_memory',
        entityType: 'memory_image',
        entityId: memoryId,
        sourceLabel: L10nService().translate('home_nhtkknim_23444a'),
        previewUrl: previewUrl,
        previewType: 'image',
        restorePath: 'houses/$houseId/memories_trash/$memoryId',
        restorePayload: restorePayload,
        restoreExpiresAt: purgeAt,
      );
    }
  }

  Future<void> deleteSelectedMemories({
    required BuildContext context,
    required String? houseId,
    required void Function(String message, {Color? backgroundColor})
    showSnackBar,
  }) async {
    if (_selectedMemories.isEmpty || houseId == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
        title: Text(
          L10nService().format('diary_delete_selected_title', {
            'count': _selectedMemories.length,
          }),
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: Text(
          L10nService().translate(
            L10nService().translate('home_bncchcmunx_09bf02'),
          ),
          style: SLTheme.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              L10nService().translate(
                L10nService().translate('home_hy_1e4050'),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              L10nService().translate(
                L10nService().translate('home_xa_4ed187'),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) {
      return;
    }

    showSnackBar('Đang xử lý...');

    try {
      final result = await _storageService.moveMemoryImagesToTrash(
        houseId: houseId,
        memoryIds: _selectedMemories.keys.toList(),
      );
      await _logDeletedMemoriesToActivityHistory(
        houseId: houseId,
        deletedItems: result['deletedItems'] is List
            ? List<dynamic>.from(result['deletedItems'] as List)
            : const <dynamic>[],
      );

      _exitSelectionMode(notify: false);
      if (!context.mounted) {
        return;
      }
      showSnackBar(
        L10nService().format('diary_deleted_memories', {
          'count': result['deletedCount'] ?? _selectedMemories.length,
        }),
      );
      notifyListeners();
    } catch (e) {
      final errorText = AppErrorMapper.resolve(e).message;
      final isNotFound =
          errorText.contains('firebase_functions/not-found') ||
          errorText.contains('not-found') ||
          errorText.contains('NOT_FOUND') ||
          errorText.contains(L10nService().translate('home_khngtmthyn_b3a1a6'));
      if (isNotFound &&
          PrivateMemoryLifecyclePolicy.allowsLegacyFallback(
            privateUploadEnabled: AppConfig.privateMemoryUploadEnabled,
            records: _selectedMemories.entries.map(
              (entry) => {...entry.value, 'id': entry.key},
            ),
          )) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final purgeAt = now + const Duration(days: 3).inMilliseconds;
        final updates = <String, dynamic>{};
        final deletedItems = <Map<String, dynamic>>[];
        for (final memoryId in _selectedMemories.keys) {
          final normalizedId = memoryId.trim();
          if (normalizedId.isEmpty) continue;
          final memoryRef = _dbRef.child(
            'houses/$houseId/memories/$normalizedId',
          );
          final snap = await memoryRef.get();
          if (!snap.exists || snap.value is! Map) continue;
          final payload = Map<String, dynamic>.from(snap.value as Map);
          payload['id'] = normalizedId;
          payload['deletedAt'] = now;
          payload['purgeAt'] = purgeAt;
          updates['houses/$houseId/memories_trash/$normalizedId'] = payload;
          updates['houses/$houseId/memories/$normalizedId'] = null;
          deletedItems.add({
            'memoryId': normalizedId,
            'url': payload['url'],
            'previewUrl': payload['thumbUrl'] ?? payload['url'],
            'title': payload['caption'] ?? payload['title'] ?? '',
            'purgeAt': purgeAt,
            'restorePayload': payload,
          });
        }
        if (updates.isNotEmpty) {
          updates['houses/$houseId/memoriesCount'] = ServerValue.increment(
            -deletedItems.length,
          );
          // Trừ dung lượng khỏi tổng kho
          var deletedImageBytes = 0;
          var deletedVideoBytes = 0;
          for (final item in deletedItems) {
            final restore = item['restorePayload'] as Map<String, dynamic>?;
            if (restore == null) continue;
            final size = (restore['fileSize'] as num?)?.toInt() ?? 0;
            deletedImageBytes +=
                (restore['thumbnailBytes'] as num?)?.toInt() ?? 0;
            if (size <= 0) continue;
            if (restore['type']?.toString().toLowerCase() == 'video') {
              deletedVideoBytes += size;
            } else {
              deletedImageBytes += size;
            }
          }
          if (deletedImageBytes > 0) {
            updates['houses/$houseId/memoryStorageBytes/image'] =
                ServerValue.increment(-deletedImageBytes);
          }
          if (deletedVideoBytes > 0) {
            updates['houses/$houseId/memoryStorageBytes/video'] =
                ServerValue.increment(-deletedVideoBytes);
          }
          await _dbRef.update(updates);
          await _logDeletedMemoriesToActivityHistory(
            houseId: houseId,
            deletedItems: deletedItems,
          );
          _exitSelectionMode(notify: false);
          if (!context.mounted) {
            return;
          }
          showSnackBar(
            L10nService().format('diary_deleted_memories', {
              'count': deletedItems.length,
            }),
          );
          notifyListeners();
          return;
        }
      }
      if (!context.mounted) {
        return;
      }
      showSnackBar(
        L10nService().format('diary_delete_photo_error', {
          'error': AppErrorMapper.resolve(e).message,
        }),
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<void> saveSelectedMemories({
    required BuildContext context,
    required DiaryGuardController guardController,
    required void Function(String message, {Color? backgroundColor})
    showSnackBar,
  }) async {
    if (_selectedMemories.isEmpty) {
      return;
    }

    showSnackBar('Đang xử lý...');

    try {
      final granted = await guardController.ensureGalleryPermission(context);
      if (!granted) {
        if (!context.mounted) {
          return;
        }
        showSnackBar(
          L10nService().translate('home_chacquynlu_10faf8'),
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      int savedCount = 0;
      int i = 0;
      final houseId = _currentHouseId;
      final generation = _mediaScopeGeneration;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      bool current() => !_isDisposed && context.mounted &&
          generation == _mediaScopeGeneration && _currentHouseId == houseId &&
          uid != null && FirebaseAuth.instance.currentUser?.uid == uid;
      if (houseId == null || !current()) return;
      for (final item in _selectedMemories.values.toList()) {
        final downloaded = await _storageService.downloadPrivateMemory(
          houseId: houseId, memoryId: item['id']?.toString() ?? '', scopeIsCurrent: current,
        );
        if (!current()) return;
        if (downloaded.bytes.isNotEmpty) {
          await _saveMemoryBytesToGallery(downloaded.bytes, url: downloaded.url, index: i);
          savedCount++;
        }
        i++;
      }

      if (!context.mounted) {
        return;
      }

      if (savedCount > 0) {
        _exitSelectionMode(notify: false);
        showSnackBar(
          L10nService().format('diary_saved_memories_to_album', {
            'count': savedCount,
          }),
        );
        notifyListeners();
      } else {
        showSnackBar(
          L10nService().translate('home_khngthtinh_98b32d'),
          backgroundColor: const Color(0xFFE53935),
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      showSnackBar(
        L10nService().format('diary_save_image_error', {
          'error': AppErrorMapper.resolve(e).message,
        }),
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<void> downloadSingleImage({
    required BuildContext context,
    required Map<String, dynamic> item,
    required DiaryGuardController guardController,
    required void Function(String message, {Color? backgroundColor})
    showSnackBar,
  }) async {
    showSnackBar('Đang xử lý...');
    try {
      final granted = await guardController.ensureGalleryPermission(context);
      if (!granted) {
        if (!context.mounted) {
          return;
        }
        showSnackBar(
          L10nService().translate('home_chacquynlu_10faf8'),
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      final houseId = _currentHouseId;
      final generation = _mediaScopeGeneration;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      bool current() => !_isDisposed && context.mounted &&
          generation == _mediaScopeGeneration && _currentHouseId == houseId &&
          uid != null && FirebaseAuth.instance.currentUser?.uid == uid;
      if (houseId == null || !current()) return;
      final downloaded = await _storageService.downloadPrivateMemory(
        houseId: houseId, memoryId: item['id']?.toString() ?? '', scopeIsCurrent: current,
      );
      if (!current()) return;
      if (downloaded.bytes.isNotEmpty) {
        await _saveMemoryBytesToGallery(downloaded.bytes, url: downloaded.url, index: 0);
        if (!context.mounted) {
          return;
        }
        showSnackBar(L10nService().translate('diary_saved_image_to_album'));
      } else {
        if (!context.mounted) {
          return;
        }
        showSnackBar(
          L10nService().translate('home_khngthtinh_98b32d'),
          backgroundColor: const Color(0xFFE53935),
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      showSnackBar(
        L10nService().format('diary_save_image_error', {
          'error': AppErrorMapper.resolve(e).message,
        }),
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<void> deleteMemory({
    required BuildContext context,
    required String? houseId,
    required Map<String, dynamic> item,
    required void Function(String message, {Color? backgroundColor})
    showSnackBar,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
        title: Text(
          L10nService().translate(
            L10nService().translate('home_xaknim_bdb86a'),
          ),
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: Text(
          L10nService().translate(
            L10nService().translate('home_bncchcmunc_c47262'),
          ),
          style: SLTheme.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10nService().translate('home_hy_1e4050')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              L10nService().translate(
                L10nService().translate('home_xa_4ed187'),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || houseId == null) {
      return;
    }

    final memoryId = item['id']?.toString().trim() ?? '';

    try {
      if (memoryId.isEmpty) {
        throw Exception(L10nService().translate('home_thiuidnhkn_bda329'));
      }

      final result = await _storageService.moveMemoryImagesToTrash(
        houseId: houseId,
        memoryIds: [memoryId],
      );
      await _logDeletedMemoriesToActivityHistory(
        houseId: houseId,
        deletedItems: result['deletedItems'] is List
            ? List<dynamic>.from(result['deletedItems'] as List)
            : const <dynamic>[],
      );
      showSnackBar(
        L10nService().translate(
          L10nService().translate('home_nhcchuynvo_37366f'),
        ),
      );
      notifyListeners();
    } catch (e) {
      final errorText = AppErrorMapper.resolve(e).message;
      final isNotFound =
          errorText.contains('firebase_functions/not-found') ||
          errorText.contains('not-found') ||
          errorText.contains('NOT_FOUND') ||
          errorText.contains(L10nService().translate('home_khngtmthyn_b3a1a6'));
      if (isNotFound && memoryId.isNotEmpty &&
          PrivateMemoryLifecyclePolicy.allowsLegacyFallback(
            privateUploadEnabled: AppConfig.privateMemoryUploadEnabled,
            records: [item],
          )) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final purgeAt = now + const Duration(days: 3).inMilliseconds;
        final memoryRef = _dbRef.child('houses/$houseId/memories/$memoryId');
        final snap = await memoryRef.get();
        if (snap.exists && snap.value is Map) {
          final payload = Map<String, dynamic>.from(snap.value as Map);
          payload['id'] = memoryId;
          payload['deletedAt'] = now;
          payload['purgeAt'] = purgeAt;
          final singleDeleteUpdates = <String, dynamic>{
            'houses/$houseId/memories_trash/$memoryId': payload,
            'houses/$houseId/memories/$memoryId': null,
            'houses/$houseId/memoriesCount': ServerValue.increment(-1),
          };
          // Trừ dung lượng khỏi tổng kho
          final delFileSize = (payload['fileSize'] as num?)?.toInt() ?? 0;
          if (delFileSize > 0) {
            final typeKey = payload['type']?.toString().toLowerCase() == 'video'
                ? 'video'
                : 'image';
            singleDeleteUpdates['houses/$houseId/memoryStorageBytes/$typeKey'] =
                ServerValue.increment(-delFileSize);
          }
          final thumbnailBytes =
              (payload['thumbnailBytes'] as num?)?.toInt() ?? 0;
          if (thumbnailBytes > 0) {
            final imageBytes = payload['type'] == 'video' ? 0 : delFileSize;
            singleDeleteUpdates['houses/$houseId/memoryStorageBytes/image'] =
                ServerValue.increment(-imageBytes - thumbnailBytes);
          }
          await _dbRef.update(singleDeleteUpdates);
          await _logDeletedMemoriesToActivityHistory(
            houseId: houseId,
            deletedItems: [
              {
                'memoryId': memoryId,
                'url': payload['url'],
                'previewUrl': payload['thumbUrl'] ?? payload['url'],
                'title': payload['caption'] ?? payload['title'] ?? '',
                'purgeAt': purgeAt,
                'restorePayload': payload,
              },
            ],
          );
          showSnackBar(
            L10nService().translate(
              L10nService().translate('home_nhcchuynvo_37366f'),
            ),
          );
          notifyListeners();
          return;
        }
      }
      showSnackBar(
        L10nService().format('diary_delete_photo_error', {
          'error': AppErrorMapper.resolve(e).message,
        }),
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  /// Upload R2 only — trả về payload để batch-write Firebase sau
  Future<({String? error, Map<String, dynamic>? payload, int uploadedBytes})>
  _uploadSingleMemoryPhoto({
    required String houseId,
    required XFile image,
    required String authorName,
    required String authorEmail,
    required String authorRole,
    required int uploadQuality,
    required String uid,
    required Future<void> Function(int bytes, bool isVideo) beforeUpload,
    Position? position,
  }) async {
    try {
      final originalName = (image.name.isNotEmpty ? image.name : image.path)
          .toLowerCase();
      final ext = p.extension(originalName).toLowerCase();
      final isVideoFile = const {
        '.mp4',
        '.mov',
        '.webm',
        '.3gp',
        '.m4v',
        '.avi',
        '.mkv',
      }.contains(ext);
      if (isVideoFile && !AppConfig.isVideoUploadEnabled) {
        return (
          error: L10nService().translate('memory_video_upload_unavailable'),
          payload: null,
          uploadedBytes: 0,
        );
      }

      final upload = await _storageService.uploadMemoryImage(
        houseId,
        image,
        quality: uploadQuality,
        beforeUpload: (bytes) => beforeUpload(bytes, isVideoFile),
      );
      final imageUrl = upload?.downloadUrl.trim() ?? '';
      if (upload == null || imageUrl.isEmpty) {
        return (
          error: L10nService().translate('home_khngthtoph_b49958'),
          payload: null,
          uploadedBytes: 0,
        );
      }

      // ── Tạo thumbnail cho video ──────────────────────────
      String? thumbnailUrl;
      String? thumbnailStoragePath;
      var thumbnailSize = 0;
      if (isVideoFile && !kIsWeb) {
        try {
          final thumbnailBytes = await VideoCompress.getByteThumbnail(
            image.path,
            quality: 50,
            position: -1,
          );
          if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
            final thumbXFile = XFile.fromData(
              thumbnailBytes,
              name:
                  'memory_video_thumbnail_${DateTime.now().microsecondsSinceEpoch}.jpg',
              mimeType: 'image/jpeg',
            );
            final thumbUpload = await _storageService.uploadMemoryImage(
              houseId,
              thumbXFile,
              quality: 60,
              beforeUpload: (bytes) => beforeUpload(bytes, false),
            );
            thumbnailUrl = thumbUpload?.downloadUrl.trim();
            thumbnailStoragePath = thumbUpload?.storagePath;
            thumbnailSize = thumbUpload?.uploadedBytes ?? 0;
          }
        } catch (e) {
          debugPrint(
            'Tạo thumbnail video thất bại: ${AppErrorMapper.resolve(e).message}',
          );
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final payload = <String, dynamic>{
        'url': imageUrl,
        'ts': nowMs,
        'date': nowMs,
        'author': authorName.trim(),
        'authorId': uid,
        'authorName': authorName.trim(),
        'storagePath': upload.storagePath,
        'authorEmail': authorEmail.trim(),
        'authorRole': authorRole.trim(),
        'type': isVideoFile ? 'video' : 'image',
        'fileSize': upload.uploadedBytes ?? 0,
        if (thumbnailSize > 0) 'thumbnailBytes': thumbnailSize,
        'thumbnailStoragePath': ?thumbnailStoragePath,
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          'thumbnailUrl': thumbnailUrl,
        if (position != null) 'lat': position.latitude,
        if (position != null) 'lng': position.longitude,
      };
      return (
        error: null,
        payload: payload,
        uploadedBytes: upload.uploadedBytes ?? 0,
      );
    } catch (e) {
      debugPrint('Lỗi tải ảnh kỷ niệm: ${AppErrorMapper.resolve(e).message}');
      return (
        error: e is DiaryMemoryQuotaExceeded
            ? L10nService().translate('memory_upload_quota_exceeded')
            : AppErrorMapper.resolve(e).message,
        payload: null,
        uploadedBytes: 0,
      );
    }
  }

  /// Đọc tổng dung lượng ảnh + video đã lưu trong kho (bytes).
  Future<Map<String, int>> _getTotalStorageBytes(String houseId) async {
    try {
      final snap = await _dbRef
          .child('houses/$houseId/memoryStorageBytes')
          .get();
      if (snap.exists && snap.value is Map) {
        final map = Map<String, dynamic>.from(snap.value as Map);
        return {
          'image': (map['image'] as num?)?.toInt() ?? 0,
          'video': (map['video'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (e) {
      // Không coi lỗi đọc hạn mức là kho rỗng.
      rethrow;
    }
    return {'image': 0, 'video': 0};
  }

  Future<void> retryPendingUpload({
    required BuildContext context,
    required DiaryGuardController guardController,
    required DiaryFeedController feedController,
    required void Function(String message, {Color? backgroundColor})
    showSnackBar,
  }) async {
    final images = await _buildPendingUploadFiles();
    if (images.isEmpty) {
      await _clearPendingUploadState();
      showSnackBar(
        L10nService().translate('home_khngcnnhkn_155889'),
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    await uploadMemoryPhotos(
      context: context,
      guardController: guardController,
      feedController: feedController,
      showSnackBar: showSnackBar,
      presetImages: images,
    );
  }

  Future<void> uploadMemoryPhotos({
    required BuildContext context,
    required DiaryGuardController guardController,
    required DiaryFeedController feedController,
    required void Function(String message, {Color? backgroundColor})
    showSnackBar,
    List<XFile>? presetImages,
  }) async {
    if (_preparingUpload || _isUploadingMemories || _isDisposed) return;
    _preparingUpload = true;
    try {
      if (!await SecurityService().guardAction(
        context,
        'diary_upload_photos',
      )) {
        return;
      }

      final houseId = await feedController.resolveHouseId();
      if (houseId == null) {
        showSnackBar(
          L10nService().translate('diary_memory_house_missing'),
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      bool scopeIsCurrent() =>
          !_isDisposed &&
          _currentHouseId == houseId &&
          FirebaseAuth.instance.currentUser?.uid == uid;
      if (!scopeIsCurrent()) return;
      final isRetry = presetImages != null || _stagedUploads.isNotEmpty;
      // Chạy song song để giảm thời gian chờ trước khi hiện picker
      final preCheckResults = await Future.wait([
        PurchaseService().getVipAccessInfo(),
        _getTotalStorageBytes(houseId),
      ]);

      final vipAccess = preCheckResults[0] as VipAccessInfo;
      final totalStorageMap = preCheckResults[1] as Map<String, int>;
      final totalImageBytes = totalStorageMap['image'] ?? 0;
      final totalVideoBytes = totalStorageMap['video'] ?? 0;

      // ── Kiểm tra tổng kho (tất cả thời gian) ──
      final imageStorageCap = vipAccess.totalMemoryStorageCapMb * 1024 * 1024;
      final videoStorageCap = vipAccess.totalMemoryVideoCapMb * 1024 * 1024;

      if (!isRetry &&
          totalImageBytes >= imageStorageCap &&
          totalVideoBytes >= videoStorageCap) {
        final imgCapMb = vipAccess.totalMemoryStorageCapMb;
        final vidCapMb = vipAccess.totalMemoryVideoCapMb;
        showSnackBar(
          'Kho lưu trữ đã đầy (ảnh ${imgCapMb}MB, video ${vidCapMb}MB). Vui lòng xóa bớt kỷ niệm cũ để tải thêm mới.'
          '${!vipAccess.isVip && AppConfig.isPurchaseEnabled ? ' Hoặc nâng cấp VIP để mở rộng kho!' : ''}',
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // ── Đọc dung lượng ảnh + video đã upload hôm nay (bytes sau nén) ──
      final uploadBytesRef = _dbRef.child(
        'houses/$houseId/memoryUploadBytes/$todayStr/$uid',
      );
      final bytesSnap = await uploadBytesRef.get();
      final bytesMap = bytesSnap.value is Map
          ? Map<String, dynamic>.from(bytesSnap.value as Map)
          : <String, dynamic>{};
      final imageUploadedToday = (bytesMap['image'] as num?)?.toInt() ?? 0;
      final videoUploadedToday = (bytesMap['video'] as num?)?.toInt() ?? 0;

      final imageLimitBytes = vipAccess.dailyImageUploadLimitBytes;
      final videoLimitBytes = vipAccess.dailyVideoUploadLimitBytes;

      // Kiểm tra giới hạn dung lượng hàng ngày
      if (!isRetry &&
          imageUploadedToday >= imageLimitBytes &&
          videoUploadedToday >= videoLimitBytes) {
        final imageLimitMb = (imageLimitBytes / (1024 * 1024)).toStringAsFixed(
          0,
        );
        final videoLimitMb = (videoLimitBytes / (1024 * 1024)).toStringAsFixed(
          0,
        );
        showSnackBar(
          vipAccess.isVip
              ? 'Bạn đã dùng hết dung lượng tải lên hôm nay (ảnh ${imageLimitMb}MB, video ${videoLimitMb}MB). Vui lòng thử lại ngày mai.'
              : AppConfig.isPurchaseEnabled
              ? 'Tài khoản thường chỉ được tải lên ${imageLimitMb}MB ảnh và ${videoLimitMb}MB video mỗi ngày. Nâng cấp VIP để tải lên nhiều hơn!'
              : 'Bạn đã dùng hết dung lượng tải lên hôm nay. Vui lòng thử lại ngày mai.',
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      // Cho chọn ảnh/video thoải mái — giới hạn bằng dung lượng, không giới hạn số lượng
      final limitToPick = StorageService.clampImagePickLimit(99);

      final selected =
          presetImages ?? await _storageService.pickMedia(limit: limitToPick);
      if (selected.isEmpty || !scopeIsCurrent()) return;
      final pending = await _buildPendingUploadFiles();
      final images = <String, XFile>{
        for (final file in pending) file.path: file,
        for (final file in selected) file.path: file,
      }.values.toList();
      if (images.isEmpty || !context.mounted || !scopeIsCurrent()) {
        return;
      }

      if (_pendingOwner != uid || _pendingHouse != houseId) {
        _stagedUploads.clear();
        _pendingFiles.clear();
      }
      _pendingOwner = uid;
      _pendingHouse = houseId;
      _isUploadingMemories = true;
      notifyListeners();

      try {
        final recoverablePaths = await _extractRecoverableImagePaths(images);
        if (recoverablePaths.isNotEmpty) {
          await _savePendingUploadState(
            houseId: houseId,
            paths: {..._pendingUploadPaths, ...recoverablePaths}.toList(),
            message: presetImages == null
                ? L10nService().translate('home_nuappbttgi_9e97ec')
                : L10nService().translate('home_angthlinhk_871c53'),
          );
        } else if (presetImages != null) {
          await _clearPendingUploadState();
        }

        // Sau khi user chọn ảnh: resolve user + location song song
        Future<Position?> locationFuture = Future.value(null);
        if (!kIsWeb) {
          locationFuture = Geolocator.isLocationServiceEnabled()
              .then((enabled) async {
                if (!enabled) return null;
                final permission = await Geolocator.checkPermission();
                if (permission != LocationPermission.always &&
                    permission != LocationPermission.whileInUse) {
                  return null;
                }
                return Geolocator.getCurrentPosition(
                  locationSettings: const LocationSettings(
                    accuracy: LocationAccuracy.low,
                  ),
                ).timeout(const Duration(seconds: 1));
              })
              .catchError((_) => null as Position?);
        }

        final postPickResults = await Future.wait([
          guardController.resolveCurrentUser(),
          locationFuture,
        ]);

        final user = postPickResults[0] as User?;
        if (user == null) {
          showSnackBar(
            L10nService().translate(
              L10nService().translate('home_phinngnhpc_f6ac90'),
            ),
            backgroundColor: const Color(0xFFE53935),
          );
          return;
        }

        final authorName = await feedController.resolveCurrentAuthorName(user);

        final authorEmail = user.email?.trim().toLowerCase() ?? '';
        final authorRole = feedController.currentAuthorRole;

        Position? position = postPickResults[1] as Position?;
        bool skippedMapPinBecauseLimit = false;

        if (position != null) {
          final pinSnapshot = await _mapPinLimitService.getSnapshot(houseId);
          final alreadyPinned = pinSnapshot.containsLocation(
            position.latitude,
            position.longitude,
          );
          if (pinSnapshot.isFull && !alreadyPinned) {
            // Giữ nguyên upload ảnh nhưng bỏ ghim vị trí mới để không vượt mốc 30 điểm.
            position = null;
            skippedMapPinBecauseLimit = true;
          }
        }

        // Ensure Auth is ready and has a fresh token before starting batch upload
        try {
          final user = await guardController.resolveCurrentUser();
          if (user != null) {
            await user.getIdToken(true);
          }
        } catch (e) {
          debugPrint(
            'Auth warm-up failed: ${AppErrorMapper.resolve(e).message}',
          );
        }

        final memoryUploadQuality = vipAccess.isVip ? 82 : 78;

        var uploadedCount = 0;
        final errorMessages = <String>[];
        var sessionImageBytes = 0;
        var sessionVideoBytes = 0;
        var sessionDailyImageBytes = 0;
        var sessionDailyVideoBytes = 0;

        for (final image in images) {
          if (!scopeIsCurrent()) break;
          final path = image.path.trim();
          try {
            var staged = _stagedUploads[path];
            if (AppConfig.privateMemoryUploadEnabled) {
              // Journal cũ không chứng minh ownership; không tự chuyển URL cũ
              // thành session mới hoặc ghi đè bản đang chờ xác nhận.
              if (staged != null && staged['privateRequestId'] is! String) {
                throw StateError('Legacy upload requires reconciliation');
              }
              if (staged == null) {
                final random = Random.secure();
                final requestId = List.generate(16,
                  (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
                staged = {'privateRequestId': requestId};
                _stagedUploads[path] = staged;
              }
              // Bắt buộc durable ID trước cả create session và PUT. Retry kể cả
              // sau restart dùng lại ID này, không lưu bearer URL vào journal.
              await _savePendingUploadState(houseId: houseId, paths: _pendingUploadPaths);
              if (!scopeIsCurrent()) break;
              await _storageService.uploadPrivateMemory(
                houseId: houseId,
                requestId: staged['privateRequestId'] as String,
                file: image,
                authorName: authorName,
                quality: memoryUploadQuality,
                scopeIsCurrent: scopeIsCurrent,
                latitude: position?.latitude,
                longitude: position?.longitude,
              );
              if (!scopeIsCurrent()) break;
              uploadedCount++;
              await _removePendingUploadedImages([image]);
              continue;
            }
            if (staged?['privateRequestId'] != null) {
              throw StateError('Private upload cannot use legacy commit');
            }
            if (staged == null) {
              final result = await _uploadSingleMemoryPhoto(
                houseId: houseId,
                image: image,
                uid: uid,
                authorName: authorName,
                authorEmail: authorEmail,
                authorRole: authorRole,
                uploadQuality: memoryUploadQuality,
                position: position,
                beforeUpload: (bytes, isVideo) async {
                  if (!scopeIsCurrent()) {
                    throw StateError('Upload scope changed');
                  }
                  final daily = isVideo
                      ? videoUploadedToday
                      : imageUploadedToday;
                  final session = isVideo
                      ? sessionVideoBytes
                      : sessionImageBytes;
                  final dailySession = isVideo
                      ? sessionDailyVideoBytes
                      : sessionDailyImageBytes;
                  final total = isVideo ? totalVideoBytes : totalImageBytes;
                  final dailyCap = isVideo ? videoLimitBytes : imageLimitBytes;
                  final totalCap = isVideo ? videoStorageCap : imageStorageCap;
                  if (daily + dailySession + bytes > dailyCap ||
                      total + session + bytes > totalCap) {
                    throw const DiaryMemoryQuotaExceeded();
                  }
                },
              );
              if (result.payload == null) {
                errorMessages.add(
                  result.error ??
                      L10nService().translate('home_cannot_save_memory'),
                );
                continue;
              }
              if (!scopeIsCurrent()) return;
              staged = {
                'id': _dbRef.child('houses/$houseId/memories').push().key!,
                'payload': result.payload!,
                'day': todayStr,
              };
              _stagedUploads[path] = staged;
            }
            // Lưu URL và ID trước khi ghi database để retry không upload lại.
            if (!scopeIsCurrent()) break;
            await _savePendingUploadState(
              houseId: houseId,
              paths: _pendingUploadPaths,
            );
            if (!scopeIsCurrent()) break;
            final payload = Map<String, dynamic>.from(staged['payload'] as Map);
            final committed = await DiaryMemoryUploadCommit.commit(
              houseId: houseId,
              uid: uid,
              day: staged['day'] as String,
              memoryId: staged['id'] as String,
              payload: payload,
              exists: (path) async => (await _dbRef.child(path).get()).exists,
              update: (values) async {
                if (!scopeIsCurrent()) throw StateError('Upload scope changed');
                await _dbRef.update(values);
              },
              increment: ServerValue.increment,
            );
            if (!scopeIsCurrent()) break;
            if (committed) {
              final bytes = (payload['fileSize'] as num?)?.toInt() ?? 0;
              if (payload['type'] == 'video') {
                sessionVideoBytes += bytes;
                if (staged['day'] == todayStr) sessionDailyVideoBytes += bytes;
              } else {
                sessionImageBytes += bytes;
                if (staged['day'] == todayStr) sessionDailyImageBytes += bytes;
              }
              final thumbBytes =
                  (payload['thumbnailBytes'] as num?)?.toInt() ?? 0;
              sessionImageBytes += thumbBytes;
              if (staged['day'] == todayStr) {
                sessionDailyImageBytes += thumbBytes;
              }
            }
            uploadedCount++;
            await _removePendingUploadedImages([image]);
          } catch (error) {
            errorMessages.add(
              L10nService().translate('home_cannot_save_memory'),
            );
            // Dừng lượt tải khi ghi lỗi; giữ journal và các file còn lại để thử lại.
            break;
          }
        }

        if (!scopeIsCurrent()) return;
        if (uploadedCount > 0) {
          await NotificationService().sendPartnerNotification(
            houseId: houseId,
            title: L10nService().translate(
              L10nService().translate('home_knimmi_e43fdc'),
            ),
            body: L10nService().format('diary_partner_new_memory', {
              'author': authorName,
              'count': uploadedCount,
            }),
            data: {'screen': 'diary', 'type': 'new_memory'},
          );
        }

        final failedCount = images.length - uploadedCount;

        if (_pendingUploadPaths.isNotEmpty) {
          final houseId = _currentHouseId?.trim() ?? '';
          if (houseId.isNotEmpty && _pendingUploadPaths.isNotEmpty) {
            await _savePendingUploadState(
              houseId: houseId,
              paths: _pendingUploadPaths,
              message: L10nService().format('home_memory_remaining_upload', {
                'count': _pendingUploadPaths.length,
              }),
            );
          }
        }

        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: failedCount > 0 ? 5 : 3),
            content: Text(
              failedCount == 0
                  ? skippedMapPinBecauseLimit
                        ? 'Đã thêm $uploadedCount kỷ niệm. Ảnh vẫn được lưu nhưng không ghim vị trí mới vì bản đồ đã đủ ${MapPinLimitService.maxPins} điểm.'
                        : L10nService().format('diary_added_new_memories', {
                            'count': uploadedCount,
                          })
                  : uploadedCount == 0 && errorMessages.isNotEmpty
                  ? errorMessages.first
                  : skippedMapPinBecauseLimit
                  ? L10nService().translate('home_memory_added_skip_location')
                  : L10nService().translate('home_memory_added_with_errors'),
            ),
          ),
        );
      } catch (e) {
        if (context.mounted) {
          await _restorePendingUploadState();
          if (!context.mounted) {
            return;
          }
          final resolved = AppErrorMapper.resolve(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resolved.message),
              backgroundColor: const Color(0xFFE53935),
            ),
          );
        }
      } finally {
        _isUploadingMemories = false;
        _notifyIfActive();
      }
    } catch (error) {
      if (context.mounted && !_isDisposed) {
        showSnackBar(
          AppErrorMapper.resolve(error).message,
          backgroundColor: const Color(0xFFE53935),
        );
      }
    } finally {
      _preparingUpload = false;
    }
  }

  Future<void> _saveMemoryBytesToGallery(
    Uint8List bytes, {
    required int index,
    required String url,
  }) async {
    final baseName = p.basenameWithoutExtension(url.split('?').first);
    final safeBaseName = baseName.trim().isEmpty
        ? 'memory_${DateTime.now().millisecondsSinceEpoch}_$index'
        : baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    UiPrefs.setCaptureMode(true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final result = await VisionGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: 'soullocket_$safeBaseName',
      );

      final isSuccess =
          result['isSuccess'] == true ||
          (result['filePath']?.toString().isNotEmpty ?? false);
      if (!isSuccess) {
        final message = result['errorMessage']?.toString();
        throw Exception(
          message?.isNotEmpty == true
              ? message
              : L10nService().translate('diary_cannot_save_image'),
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      UiPrefs.setCaptureMode(false);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    selectionTickVN.dispose();
    super.dispose();
  }
}
