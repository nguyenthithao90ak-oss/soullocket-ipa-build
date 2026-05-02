import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, ValueNotifier, debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/services/private_media_url_service.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/services/map_pin_limit_service.dart';
import 'package:soullocket_app/utils/services/activity_history_service.dart';
import 'package:soullocket_app/utils/services/album_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/purchase_service.dart';
import 'package:soullocket_app/utils/services/security_service.dart';
import 'package:soullocket_app/utils/services/storage_service.dart';
import 'package:soullocket_app/views/home/tabs/diary/controllers/diary_feed_controller.dart';
import 'package:soullocket_app/views/home/tabs/diary/controllers/diary_guard_controller.dart';
import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:soullocket_app/widgets/cute_loading_indicator.dart';
import 'package:vision_gallery_saver/vision_gallery_saver.dart';

typedef DiaryMemoryFlattenedItem = ({
  bool isHeader,
  DateTime? date,
  String? dateString,
  int? totalPhotos,
  List<Map<String, dynamic>>? photosRow,
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
  })  : _dbRef = dbRef ?? FirebaseDatabase.instance.ref(),
        _storageService = storageService ?? StorageService() {
    _resetMemoriesPagination();
  }

  static const int _webMemoryCacheLimit = 80;
  static const int _appMemoryCacheLimit = 160;
  static const int _memoryUploadConcurrency = 3;
  static const Duration _memoryDownloadCacheTtl = Duration(hours: 18);
  static const Color _diaryPinkDeep = Color(0xFFD81B60);
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
  bool _isUploadingMemories = false;

  bool get isSelectionMode => _isSelectionMode;
  int get selectedMemoriesCount => _selectedMemories.length;
  Map<String, Map<String, dynamic>> get selectedMemories => _selectedMemories;
  bool get isLoadingMoreMemories => _isLoadingMoreMemories;
  bool get isUploadingMemories => _isUploadingMemories;
  bool get hasPendingUploadRetry =>
      !_isUploadingMemories && _pendingUploadPaths.isNotEmpty;
  String get pendingUploadMessage =>
      _pendingUploadMessage ??
      'Lần upload Kỷ niệm trước đã bị gián đoạn. Bạn có thể thử lại.';

  int get _memoryCacheLimit =>
      kIsWeb ? _webMemoryCacheLimit : _appMemoryCacheLimit;

  int get _memoryQueryLimit => _memoryVisibleLimit ?? _memoryCacheLimit;

  int get _memoryLoadMoreStep => AppConfig.albumPageSize;

  void _setPendingUploadState(
    List<String> paths, {
    String? message,
    bool notify = true,
  }) {
    _pendingUploadPaths = List<String>.unmodifiable(paths);
    _pendingUploadMessage = message;
    if (notify) {
      notifyListeners();
    }
  }

  Future<List<String>> _extractRecoverableImagePaths(List<XFile> images) async {
    if (kIsWeb) {
      return const <String>[];
    }
    final paths = <String>[];
    for (final image in images) {
      final path = image.path.trim();
      if (path.isEmpty) {
        continue;
      }
      try {
        if (await XFile(path).length() > 0) {
          paths.add(path);
        }
      } catch (_) {}
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
    await prefs.setString(
      _pendingUploadPrefsKey,
      jsonEncode(<String, dynamic>{
        'houseId': houseId.trim(),
        'paths': normalizedPaths,
      }),
    );
    _setPendingUploadState(normalizedPaths, message: message);
  }

  Future<void> _clearPendingUploadState({bool notify = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingUploadPrefsKey);
    if (_pendingUploadPaths.isEmpty && _pendingUploadMessage == null) {
      return;
    }
    _setPendingUploadState(const <String>[], message: null, notify: notify);
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
      if (savedHouseId != houseId) {
        if (_pendingUploadPaths.isNotEmpty || _pendingUploadMessage != null) {
          _setPendingUploadState(const <String>[], message: null);
        }
        return;
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
        try {
          if (await XFile(path).length() > 0) {
            recoverablePaths.add(path);
          }
        } catch (_) {}
      }

      if (recoverablePaths.isEmpty) {
        await _clearPendingUploadState();
        return;
      }

      _setPendingUploadState(
        recoverablePaths,
        message:
            'Lần upload Kỷ niệm trước đã bị gián đoạn. Bạn có thể thử lại.',
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
      message:
          'Còn ${remaining.length} ảnh Kỷ niệm chưa tải xong. Bạn có thể thử lại.',
    );
  }

  Future<List<XFile>> _buildPendingUploadFiles() async {
    final files = <XFile>[];
    for (final path in _pendingUploadPaths) {
      final normalized = path.trim();
      if (normalized.isEmpty) {
        continue;
      }
      try {
        final file = XFile(normalized);
        if (await file.length() > 0) {
          files.add(file);
        }
      } catch (_) {}
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
    if (_currentHouseId == normalized) {
      return;
    }
    _currentHouseId = normalized;
    _lastMemoriesCacheSignature = null;
    _resetMemoriesPagination();
    _resetMemoriesStreamCache();
    _exitSelectionMode(notify: false);
    notifyListeners();
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
    _resetMemoriesStreamCache();
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
      unawaited(_storageService.cleanupExpiredMemoryTrashIfNeeded(normalizedHouseId));
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
      _memoriesCacheFuture =
          OfflineCacheService.loadCache('memories_$normalizedHouseId');
    }
    return _memoriesCacheFuture!;
  }

  dynamic getMemoriesCacheSync(String? houseId) {
    final normalizedHouseId = _normalizeHouseId(houseId);
    if (normalizedHouseId == null) {
      return null;
    }
    return OfflineCacheService.loadCacheSync('memories_$normalizedHouseId');
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
      cacheList.add(item);
    });

    cacheList.sort((a, b) => _readCacheTs(b).compareTo(_readCacheTs(a)));
    final limited = cacheList.take(_memoryCacheLimit).toList(growable: false);
    final signature = _buildCacheSignature(limited);
    if (_lastMemoriesCacheSignature == signature) {
      return;
    }
    _lastMemoriesCacheSignature = signature;
    await OfflineCacheService.saveCache('memories_$houseId', limited);
  }

  bool _isMemoryUrlExpired(Map<String, dynamic> item) {
    if (item['privateMedia'] != true && item['storageAccess'] != 'signed') {
      return false;
    }
    final expiresAt = (item['urlExpiresAt'] as num?)?.toInt() ?? 0;
    return expiresAt <= DateTime.now().millisecondsSinceEpoch + 60000;
  }

  Future<void> ensureMemoryPhotoUrl({
    required String houseId,
    required Map<String, dynamic> item,
  }) async {
    final existingUrl = item['url']?.toString().trim() ?? '';
    final memoryId = item['id']?.toString().trim() ?? '';
    final hasStoragePath =
        (item['storagePath']?.toString().trim().isNotEmpty ?? false) ||
            (item['storageKey']?.toString().trim().isNotEmpty ?? false);
    if (memoryId.isEmpty || !hasStoragePath) {
      return;
    }
    if (existingUrl.isNotEmpty && !_isMemoryUrlExpired(item)) {
      return;
    }
    final result = await _privateMediaUrlService.resolve(
      houseId: houseId,
      mediaId: memoryId,
      kind: 'memory_image',
    );
    item['url'] = result.url;
    item['urlExpiresAt'] = result.expiresAt;
  }

  List<Map<String, dynamic>> _memoryPhotosFromSource(
    Object? source, {
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
        final item =
            Map<String, dynamic>.from(Map<dynamic, dynamic>.from(value));
        item['id'] = key.toString();
        photos.add(item);
      });
    } else if (!useLiveSource && source is List) {
      for (final item in source.take(limit)) {
        if (item is! Map) {
          continue;
        }
        photos.add(Map<String, dynamic>.from(item));
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
          (dateKey) => (
            date: DateTime.parse(dateKey),
            items: grouped[dateKey]!,
          ),
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
      final highlights = AlbumService().getDateHighlights(
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
        highlights: highlights,
      ));

      for (int i = 0; i < group.items.length; i += 3) {
        final end = (i + 3 < group.items.length) ? i + 3 : group.items.length;
        flattenedItems.add((
          isHeader: false,
          date: null,
          dateString: null,
          totalPhotos: null,
          photosRow: group.items.sublist(i, end),
          highlights: const <Map<String, String>>[],
        ));
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
        '${startDate?.millisecondsSinceEpoch ?? 0}|$relationshipMode';

    if (_preparedMemoryFeed != null &&
        identical(_preparedMemorySource, source) &&
        _preparedMemorySourceKind == sourceKind &&
        _preparedMemoryLimit == limit &&
        _preparedMemoryHighlightKey == highlightKey) {
      return _preparedMemoryFeed!;
    }

    final photos = _memoryPhotosFromSource(
      source,
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
      showingCache: !useLiveSource &&
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

  Future<void> _logDeletedMemoriesToActivityHistory({
    required String houseId,
    required List<dynamic> deletedItems,
  }) async {
    if (deletedItems.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('il_role')?.trim() == 'user2' ? 'user2' : 'user1';

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
          item['previewUrl']?.toString().trim() ?? item['url']?.toString().trim() ?? '';
      final title = item['title']?.toString().trim() ?? '';
      final purgeAt = (item['purgeAt'] as num?)?.toInt() ?? 0;
      final restorePayload = item['restorePayload'] is Map
          ? Map<String, dynamic>.from(item['restorePayload'] as Map)
          : <String, dynamic>{};

      await ActivityHistoryService.instance.add(
        'đã xóa ảnh nhật ký kỷ niệm',
        houseId: houseId,
        role: role,
        title: 'Đã xóa ảnh kỷ niệm',
        subtitle: title,
        action: 'delete',
        module: 'diary_memory',
        entityType: 'memory_image',
        entityId: memoryId,
        sourceLabel: 'Nhật ký kỷ niệm',
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
          L10nService().translate('Bạn có chắc muốn xóa những ảnh đã chọn?'),
          style: SLTheme.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10nService().translate('Hủy')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(L10nService().translate('Xóa')),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CuteLoadingIndicator(color: _diaryPinkDeep),
      ),
    );

    try {
      final updatesCount = _selectedMemories.length;
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
      Navigator.of(context).pop();
      showSnackBar(
        L10nService().format('diary_deleted_memories', {
          'count': updatesCount,
        }),
      );
      notifyListeners();
    } catch (e) {
      final errorText = e.toString();
      final isNotFound = errorText.contains('firebase_functions/not-found') ||
          errorText.contains('not-found') ||
          errorText.contains('NOT_FOUND') ||
          errorText.contains('Không tìm thấy ảnh Kỷ niệm cần xóa');
      if (isNotFound) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final purgeAt = now + const Duration(days: 3).inMilliseconds;
        final updates = <String, dynamic>{};
        final deletedItems = <Map<String, dynamic>>[];
        for (final memoryId in _selectedMemories.keys) {
          final normalizedId = memoryId.trim();
          if (normalizedId.isEmpty) continue;
          final memoryRef = _dbRef.child('houses/$houseId/memories/$normalizedId');
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
          updates['houses/$houseId/memoriesCount'] =
              ServerValue.increment(-deletedItems.length);
          await _dbRef.update(updates);
          await _logDeletedMemoriesToActivityHistory(
            houseId: houseId,
            deletedItems: deletedItems,
          );
          _exitSelectionMode(notify: false);
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pop();
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
      Navigator.of(context).pop();
      showSnackBar(
        L10nService().format('diary_delete_photo_error', {'error': e}),
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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CuteLoadingIndicator(color: _diaryPinkDeep),
      ),
    );

    try {
      final granted = await guardController.ensureGalleryPermission(context);
      if (!granted) {
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pop();
        showSnackBar(
          'Chưa có quyền lưu ảnh vào album.',
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      int savedCount = 0;
      int i = 0;
      for (final item in _selectedMemories.values) {
        final url = item['url']?.toString().trim() ?? '';
        if (url.isEmpty) {
          i++;
          continue;
        }
        final bytes = await _storageService.downloadBytesWithCache(
          url,
          namespace: 'diary_memory_gallery',
          cacheKey: item['id']?.toString() ?? 'memory_$i',
          ttl: _memoryDownloadCacheTtl,
        );
        if (bytes != null && bytes.isNotEmpty) {
          await _saveMemoryBytesToGallery(
            bytes,
            url: url,
            index: i,
          );
          savedCount++;
        }
        i++;
      }

      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();

      if (savedCount > 0) {
        _exitSelectionMode(notify: false);
        showSnackBar(L10nService().format(
          'diary_saved_memories_to_album',
          {'count': savedCount},
        ));
        notifyListeners();
      } else {
        showSnackBar(
          'Không thể tải ảnh.',
          backgroundColor: const Color(0xFFE53935),
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
      showSnackBar(
        L10nService().format('diary_save_image_error', {'error': e}),
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<void> downloadSingleImage({
    required BuildContext context,
    required String url,
    required DiaryGuardController guardController,
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CuteLoadingIndicator(color: Colors.white),
      ),
    );
    try {
      final granted = await guardController.ensureGalleryPermission(context);
      if (!granted) {
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pop();
        showSnackBar(
          'Chưa có quyền lưu ảnh vào album.',
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }

      final bytes = await _storageService.downloadBytesWithCache(
        url,
        namespace: 'diary_memory_gallery',
        cacheKey: 'single_${p.basenameWithoutExtension(url.split('?').first)}',
        ttl: _memoryDownloadCacheTtl,
      );
      if (bytes != null && bytes.isNotEmpty) {
        await _saveMemoryBytesToGallery(
          bytes,
          url: url,
          index: 0,
        );
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pop();
        showSnackBar(L10nService().translate('diary_saved_image_to_album'));
      } else {
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pop();
        showSnackBar(
          'Không thể tải ảnh.',
          backgroundColor: const Color(0xFFE53935),
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
      showSnackBar(
        L10nService().format('diary_save_image_error', {'error': e}),
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
          L10nService().translate('Xóa kỷ niệm?'),
          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
        ),
        content: Text(
          L10nService()
              .translate('Bạn có chắc muốn chuyển ảnh này vào thùng rác?'),
          style: SLTheme.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(L10nService().translate('Xóa')),
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
        throw Exception('Thiếu id ảnh Kỷ niệm.');
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
    } catch (e) {
      final errorText = e.toString();
      final isNotFound = errorText.contains('firebase_functions/not-found') ||
          errorText.contains('not-found') ||
          errorText.contains('NOT_FOUND') ||
          errorText.contains('Không tìm thấy ảnh Kỷ niệm cần xóa');
      if (isNotFound && memoryId.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final purgeAt = now + const Duration(days: 3).inMilliseconds;
        final memoryRef = _dbRef.child('houses/$houseId/memories/$memoryId');
        final snap = await memoryRef.get();
        if (snap.exists && snap.value is Map) {
          final payload = Map<String, dynamic>.from(snap.value as Map);
          payload['id'] = memoryId;
          payload['deletedAt'] = now;
          payload['purgeAt'] = purgeAt;
          await _dbRef.update({
            'houses/$houseId/memories_trash/$memoryId': payload,
            'houses/$houseId/memories/$memoryId': null,
            'houses/$houseId/memoriesCount': ServerValue.increment(-1),
          });
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
          return;
        }
      }
      showSnackBar(
        L10nService().format('diary_delete_photo_error', {'error': e}),
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<String?> _uploadSingleMemoryPhoto({
    required String houseId,
    required XFile image,
    required String authorName,
    required String authorEmail,
    required String authorRole,
    Position? position,
  }) async {
    try {
      final upload = await _storageService.uploadMemoryImage(houseId, image);
      final sessionId = upload?.sessionId?.trim() ?? '';
      if (upload == null || sessionId.isEmpty) {
        return 'Không thể tạo phiên tải ảnh.';
      }

      Map<String, dynamic>? finalized;
      Object? lastError;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          finalized = await _storageService.finalizeMemoryImageUpload(
            houseId: houseId,
            sessionId: sessionId,
            authorName: authorName,
            authorEmail: authorEmail,
            authorRole: authorRole,
            lat: position?.latitude,
            lng: position?.longitude,
          );
          break;
        } catch (error) {
          lastError = error;
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 450));
            continue;
          }
        }
      }

      final isOk = finalized?['ok'] == true;
      final memoryId = finalized?['memoryId']?.toString().trim() ?? '';
      if (isOk && memoryId.isNotEmpty) {
        return null; // Success
      }

      if (lastError != null) {
        debugPrint('Lỗi finalize ảnh kỷ niệm: $lastError');
        return lastError.toString();
      }
      return 'Không nhận được phản hồi hợp lệ từ máy chủ.';
    } catch (e) {
      debugPrint('Lỗi tải ảnh kỷ niệm: $e');
      return e.toString();
    }
  }

  Future<int> _getTotalMemoriesCount(String houseId) async {
    try {
      final countSnap =
          await _dbRef.child('houses/$houseId/memoriesCount').get();
      if (countSnap.exists && countSnap.value != null) {
        return (countSnap.value as num).toInt();
      }
    } catch (e) {
      debugPrint('Failed to read memoriesCount: $e');
    }

    try {
      final memoriesSnap = await _dbRef.child('houses/$houseId/memories').get();
      return memoriesSnap.exists && memoriesSnap.value is Map
          ? (memoriesSnap.value as Map).length
          : 0;
    } catch (e) {
      debugPrint('Failed to read memories list for count: $e');
      return 0;
    }
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
        'Không còn ảnh Kỷ niệm tạm để thử lại.',
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
    if (!await SecurityService().guardAction(context, 'diary_upload_photos')) {
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

    // Chạy song song để giảm thời gian chờ trước khi hiện picker
    final preCheckResults = await Future.wait([
      PurchaseService().getVipAccessInfo(),
      _getTotalMemoriesCount(houseId),
      SharedPreferences.getInstance(),
    ]);

    final vipAccess = preCheckResults[0] as VipAccessInfo;
    final totalMemories = preCheckResults[1] as int;
    final prefs = preCheckResults[2] as SharedPreferences;

    final maxMemories = (vipAccess.memoryVaultLimit ?? 365).toDouble();

    if (totalMemories >= maxMemories) {
      showSnackBar(
        L10nService().format('diary_memory_vault_full', {
          'current': totalMemories,
          'limit': maxMemories.toInt(),
        }),
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    final dailyLimit = vipAccess.dailyMemoryUploadLimit;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayKey = 'il_memories_upload_count_$todayStr';
    final uploadedToday = prefs.getInt(todayKey) ?? 0;

    if (uploadedToday >= dailyLimit) {
      showSnackBar(
        L10nService().translate(
          vipAccess.isVip
              ? 'Bạn đã đạt giới hạn đăng 30 ảnh kỷ niệm hôm nay. Hãy quay lại vào ngày mai nhé!'
              : 'Tài khoản thường chỉ đăng được 10 ảnh/ngày. Hãy nâng cấp PRO hoặc thử lại vào ngày mai!',
        ),
        backgroundColor: const Color(0xFFE53935),
      );
      return;
    }

    var slotsLeft = dailyLimit - uploadedToday;
    final slotsUntilFull = maxMemories.toInt() - totalMemories;
    if (slotsLeft > slotsUntilFull) {
      slotsLeft = slotsUntilFull;
    }

    final limitToPick = StorageService.clampImagePickLimit(slotsLeft);

    final images =
        presetImages ?? await _storageService.pickImages(limit: limitToPick);
    if (images.isEmpty || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (images.length > slotsLeft) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(L10nService().format('diary_slots_left', {
            'count': slotsLeft,
          })),
        ),
      );
      return;
    }

    _isUploadingMemories = true;
    notifyListeners();

    try {
      final recoverablePaths = await _extractRecoverableImagePaths(images);
      if (recoverablePaths.isNotEmpty) {
        await _savePendingUploadState(
          houseId: houseId,
          paths: recoverablePaths,
          message: presetImages == null
              ? 'Nếu app bị tắt giữa chừng, bạn có thể thử lại upload Kỷ niệm.'
              : 'Đang thử lại ảnh Kỷ niệm chưa tải xong.',
        );
      } else if (presetImages != null) {
        await _clearPendingUploadState();
      }

      // Sau khi user chọn ảnh: resolve user + location song song
      Future<Position?> locationFuture = Future.value(null);
      if (!kIsWeb) {
        locationFuture =
            Geolocator.isLocationServiceEnabled().then((enabled) async {
          if (!enabled) return null;
          final permission = await Geolocator.checkPermission();
          if (permission != LocationPermission.always &&
              permission != LocationPermission.whileInUse) {
            return null;
          }
          return Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(const Duration(seconds: 1));
        }).catchError((_) => null as Position?);
      }

      final postPickResults = await Future.wait([
        guardController.resolveCurrentUser(),
        locationFuture,
      ]);

      final user = postPickResults[0] as User?;
      if (user == null) {
        showSnackBar(
          L10nService()
              .translate('Phiên đăng nhập chưa sẵn sàng. Vui lòng thử lại.'),
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
        final alreadyPinned =
            pinSnapshot.containsLocation(position.latitude, position.longitude);
        if (pinSnapshot.isFull && !alreadyPinned) {
          // Giữ nguyên upload ảnh nhưng bỏ ghim vị trí mới để không vượt mốc 30 điểm.
          position = null;
          skippedMapPinBecauseLimit = true;
        }
      }

      var uploadedCount = 0;
      final errorMessages = <String>[];

      for (var start = 0;
          start < images.length;
          start += _memoryUploadConcurrency) {
        final end = (start + _memoryUploadConcurrency).clamp(0, images.length);
        final batch = images.sublist(start, end);
        final batchResults = await Future.wait(
          [
            for (final image in batch)
              _uploadSingleMemoryPhoto(
                houseId: houseId,
                image: image,
                authorName: authorName,
                authorEmail: authorEmail,
                authorRole: authorRole,
                position: position,
              ),
          ],
        );

        final completedImages = <XFile>[];
        for (var index = 0; index < batchResults.length; index++) {
          final err = batchResults[index];
          if (err == null) {
            uploadedCount++;
            completedImages.add(batch[index]);
          } else {
            errorMessages.add(err);
          }
        }
        if (completedImages.isNotEmpty) {
          await _removePendingUploadedImages(completedImages);
        }
      }

      await prefs.setInt(todayKey, uploadedToday + uploadedCount);

      if (uploadedCount > 0) {
        await NotificationService().sendPartnerNotification(
          houseId: houseId,
          title: L10nService().translate('📸 Kỷ niệm mới!'),
          body: L10nService().format('diary_partner_new_memory', {
            'author': authorName,
            'count': uploadedCount,
          }),
          data: {'screen': 'diary', 'type': 'new_memory'},
        );
      }

      final failedCount = images.length - uploadedCount;
      final errorMessageStr =
          errorMessages.isNotEmpty ? '\nLỗi: ${errorMessages.first}' : '';

      if (failedCount <= 0) {
        await _clearPendingUploadState(notify: false);
      } else {
        final houseId = _currentHouseId?.trim() ?? '';
        if (houseId.isNotEmpty && _pendingUploadPaths.isNotEmpty) {
          await _savePendingUploadState(
            houseId: houseId,
            paths: _pendingUploadPaths,
            message:
                'Còn $failedCount ảnh Kỷ niệm chưa tải xong. Bạn có thể thử lại.',
          );
        }
      }

      messenger.showSnackBar(
        SnackBar(
          duration: Duration(seconds: failedCount > 0 ? 5 : 3),
          content: Text(
            failedCount == 0
                ? skippedMapPinBecauseLimit
                    ? 'Đã thêm $uploadedCount kỷ niệm. Ảnh vẫn được lưu nhưng không ghim vị trí mới vì bản đồ đã đủ ${MapPinLimitService.maxPins} điểm.'
                    : L10nService().format('diary_added_new_memories', {
                        'count': uploadedCount,
                      })
                : skippedMapPinBecauseLimit
                    ? 'Đã thêm $uploadedCount/${images.length} kỷ niệm. Một phần ảnh không ghim vị trí mới.$errorMessageStr'
                    : 'Đã thêm $uploadedCount/${images.length} kỷ niệm. $failedCount ảnh lỗi.$errorMessageStr',
          ),
        ),
      );
      }
    } catch (e) {
      if (context.mounted) {
        await _restorePendingUploadState();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              L10nService().format('diary_memory_upload_error', {'error': e}),
            ),
          ),
        );
      }
    } finally {
      _isUploadingMemories = false;
      notifyListeners();
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
        androidRelativePath: 'Pictures/SoulLocket/KyNiem',
      );

      final isSuccess = result['isSuccess'] == true ||
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
    selectionTickVN.dispose();
    super.dispose();
  }
}
