import 'dart:async';
import 'dart:collection';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../offline_cache_service.dart';
import 'house_list_d1_client.dart';

typedef HouseListValueStream = Stream<Object?> Function(String path);
typedef HouseListQueryStream = Stream<Object?> Function(String path, int limit);
typedef HouseListSignal = Future<void> Function(String path, int value);
typedef HouseListCacheLoad = Object? Function(String key);
typedef HouseListCacheSave = Future<void> Function(String key, Object data);

/// Nguồn dữ liệu của một danh sách trong nhà (Bucket list, Điều ước).
///
/// Cờ do server ghi ở `houses/{houseId}/settings/dataBackends/{kind}` quyết định nguồn:
/// - khác `d1`: nghe trực tiếp `houses/{houseId}/{kind}` trên RTDB như trước;
/// - `d1`: đọc qua Worker, RTDB chỉ còn leaf `metadata/last_updated_{kind}` báo máy kia tải
///   lại. Bản cache kèm phiên bản giúp mở lại màn hình không tốn lượt gọi Worker khi
///   chưa có gì thay đổi.
///
/// Mỗi controller gắn với đúng một nhà; đổi nhà thì tạo controller mới.
class HouseListController extends ChangeNotifier {
  HouseListController({
    required this.houseId,
    required this.kind,
    required this.rtdbLimit,
    this.rtdbCacheKey,
    this.client,
    HouseListValueStream? valueStream,
    HouseListQueryStream? queryStream,
    HouseListSignal? signal,
    String Function(String path)? newKey,
    HouseListCacheLoad? loadCache,
    HouseListCacheSave? saveCache,
  }) : assert(HouseListD1Client.kinds.contains(kind)),
       _valueStream = valueStream ?? _rtdbValue,
       _queryStream = queryStream ?? _rtdbQuery,
       _signal = signal ?? _rtdbSet,
       _newKey = newKey ?? _rtdbPushKey,
       _loadCache = loadCache ?? OfflineCacheService.loadCacheSync,
       _saveCache = saveCache ?? OfflineCacheService.saveCache;

  final String houseId;
  final String kind;
  final int rtdbLimit;

  /// Khóa cache cũ của màn hình ở chế độ RTDB (giữ để không mất bản đệm đã có).
  final String? rtdbCacheKey;

  /// Client Worker; chỉ cần khi nhà đã chuyển danh sách sang D1.
  final HouseListD1Client? client;
  final HouseListValueStream _valueStream;
  final HouseListQueryStream _queryStream;
  final HouseListSignal _signal;
  final String Function(String path) _newKey;
  final HouseListCacheLoad _loadCache;
  final HouseListCacheSave _saveCache;

  static Stream<Object?> _rtdbValue(String path) => FirebaseDatabase.instance
      .ref(path)
      .onValue
      .map((event) => event.snapshot.value);
  static Stream<Object?> _rtdbQuery(String path, int limit) => FirebaseDatabase
      .instance
      .ref(path)
      .limitToLast(limit)
      .onValue
      .map((event) => event.snapshot.value);
  static Future<void> _rtdbSet(String path, int value) =>
      FirebaseDatabase.instance.ref(path).set(value);
  static String _rtdbPushKey(String path) =>
      FirebaseDatabase.instance.ref(path).push().key!;

  StreamSubscription<Object?>? _flagSubscription;
  StreamSubscription<Object?>? _sourceSubscription;
  Map<String, Map<String, dynamic>> _items = {};
  bool _started = false, _disposed = false, _loading = true;
  // Dữ liệu đang hiển thị có đến từ D1 (cache có phiên bản hoặc Worker) hay không.
  bool _d1Data = false;
  bool? _useD1;
  Object? _error;
  int _version = 0, _readSerial = 0;

  bool get loading => _loading;
  Object? get error => _error;

  /// `true` khi nhà đang dùng D1 cho danh sách này; `false` trước khi đọc được cờ.
  bool get useD1 => _useD1 == true;
  Map<String, Map<String, dynamic>> get items => UnmodifiableMapView(_items);

  String get _listPath => 'houses/$houseId/$kind';
  String get _flagPath => 'houses/$houseId/settings/dataBackends/$kind';
  String get _metadataPath => 'houses/$houseId/metadata/last_updated_$kind';
  String get _d1CacheKey => 'house_list_d1_${kind}_$houseId';

  HouseListD1Client get _d1 {
    final d1 = client;
    if (d1 == null) throw StateError('House list D1 client is missing');
    return d1;
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    // Nhà từng chạy D1 có cache kèm phiên bản; ưu tiên bản đó để không nháy dữ liệu cũ.
    if (!_restoreD1Cache()) _restoreRtdbCache();
    _flagSubscription = _valueStream(_flagPath).listen(
      (value) => _selectSource(value == 'd1'),
      // Không đọc được cờ thì giữ nguồn RTDB như trước.
      onError: (Object _) => _selectSource(false),
    );
  }

  bool _restoreD1Cache() {
    try {
      final cached = _loadCache(_d1CacheKey);
      if (cached is! Map || cached['items'] is! Map) return false;
      _items = _mapItems(cached['items'] as Map);
      _version = (cached['v'] as num?)?.toInt() ?? 0;
      _loading = false;
      _d1Data = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _restoreRtdbCache() {
    final key = rtdbCacheKey;
    if (key == null) return;
    try {
      final cached = _loadCache(key);
      if (cached is Map) {
        _items = _mapItems(cached);
        _loading = false;
      }
    } catch (_) {
      /* Cache không thay thế kết quả đọc có xác thực. */
    }
  }

  void _selectSource(bool useD1) {
    if (_disposed || _useD1 == useD1) return;
    final switching = _useD1 != null;
    _useD1 = useD1;
    _readSerial++;
    unawaited(_sourceSubscription?.cancel());
    if (switching) {
      // Đổi nguồn khi màn đang mở: bỏ dữ liệu của nguồn cũ, tải lại từ nguồn mới.
      _items = {};
      _version = 0;
      _d1Data = false;
      _loading = true;
      _error = null;
      _notify();
    }
    if (useD1) {
      _sourceSubscription = _valueStream(_metadataPath).listen((value) {
        final version = int.tryParse(value?.toString() ?? '') ?? 0;
        if (!_d1Data ||
            version != _version ||
            _loading ||
            _items.isEmpty ||
            _error != null) {
          unawaited(_fetch(version));
        }
      }, onError: _fail);
    } else {
      _sourceSubscription = _queryStream(_listPath, rtdbLimit).listen((value) {
        if (_disposed) return;
        _items = value is Map ? _mapItems(value) : {};
        _d1Data = false;
        _loading = false;
        _error = null;
        final key = rtdbCacheKey;
        if (key != null && value is Map) unawaited(_safeSave(key, value));
        _notify();
      }, onError: _fail);
    }
  }

  void _fail(Object error) {
    if (_disposed) return;
    _loading = false;
    _error = error;
    _notify();
  }

  Future<void> _fetch(int version) async {
    final serial = ++_readSerial;
    try {
      final next = await _d1.list(houseId, kind);
      if (_disposed || serial != _readSerial) return;
      _items = next;
      _version = version;
      _d1Data = true;
      _loading = false;
      _error = null;
      _cacheD1();
      _notify();
    } catch (error) {
      if (_disposed || serial != _readSerial) return;
      _fail(error);
    }
  }

  /// Thử tải lại sau lỗi (nút "Thử lại").
  void retry() {
    if (_disposed) return;
    _loading = true;
    _error = null;
    _notify();
    if (useD1) {
      unawaited(_fetch(_version));
    } else {
      final current = _useD1;
      _useD1 = null;
      _selectSource(current ?? false);
    }
  }

  /// Mã mục mới (push key RTDB, tạo cục bộ) dùng chung cho cả hai nguồn.
  String newItemId() => _newKey(_listPath);

  int revisionOf(String id) => (_items[id]?['rev'] as num?)?.toInt() ?? 0;

  Future<HouseListWriteResult> create(String id, Map<String, Object?> data) =>
      _commit(
        () => _d1.save(
          houseId: houseId,
          kind: kind,
          itemId: id,
          expectedRevision: 0,
          data: data,
        ),
      );

  /// Đổi nhanh các trường cho phép (ví dụ `done`) với revision đang thấy.
  Future<HouseListWriteResult> patch(String id, Map<String, Object?> set) =>
      _commit(
        () => _d1.patch(
          houseId: houseId,
          kind: kind,
          itemId: id,
          expectedRevision: revisionOf(id),
          set: set,
        ),
      );

  /// Xóa mềm trên D1 (khôi phục được trong 3 ngày).
  Future<HouseListWriteResult> remove(String id) => _commit(
    () => _d1.delete(
      houseId: houseId,
      kind: kind,
      itemId: id,
      expectedRevision: revisionOf(id),
    ),
    removed: true,
  );

  Future<HouseListWriteResult> _commit(
    Future<HouseListWriteResult> Function() write, {
    bool removed = false,
  }) async {
    if (!useD1) throw StateError('House list is not on D1');
    try {
      final result = await write();
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!_disposed) {
        _readSerial++;
        if (removed) {
          _items.remove(result.id);
        } else {
          _items[result.id] = result.record;
        }
        _loading = false;
        _error = null;
        _notify();
        if (_d1Data) {
          _version = now;
          _cacheD1();
        } else {
          // Danh sách còn là bản đệm RTDB cũ: lấy toàn bộ bản D1 thay vì trộn hai nguồn.
          unawaited(_fetch(now));
        }
      }
      await _signalChanged(now);
      return result;
    } on HouseListConflictException {
      // Người kia vừa đổi mục này: tải bản mới để người dùng xem lại.
      if (!_disposed) unawaited(_fetch(_version));
      rethrow;
    }
  }

  /// Leaf nhỏ báo máy kia tải lại; lỗi ở đây không làm hỏng lần ghi đã thành công trên D1.
  Future<void> _signalChanged(int now) async {
    try {
      await _signal(_metadataPath, now);
    } catch (_) {
      /* Máy kia sẽ thấy thay đổi ở lần tải sau. */
    }
  }

  void _cacheD1() {
    unawaited(_safeSave(_d1CacheKey, {'v': _version, 'items': _items}));
  }

  Future<void> _safeSave(String key, Object data) async {
    try {
      await _saveCache(key, data);
    } catch (_) {
      /* Giữ dữ liệu server ngay cả khi cache local không ghi được. */
    }
  }

  static Map<String, Map<String, dynamic>> _mapItems(Map raw) => {
    for (final entry in raw.entries)
      if (entry.value is Map)
        entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _readSerial++;
    unawaited(_flagSubscription?.cancel());
    unawaited(_sourceSubscription?.cancel());
    super.dispose();
  }
}
