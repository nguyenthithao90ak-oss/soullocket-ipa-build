import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../utils/private_media_load_queue.dart';
import '../../../../../utils/screen_activity_mixin.dart';
import '../../../../../utils/services/private_media_url_service.dart';
import '../../../../../utils/services/media_data_preferences.dart';
import '../../../../../utils/services/storage/private_image_disk_cache.dart';

class _DiaryVideoThumbnailEntry {
  _DiaryVideoThumbnailEntry(this.bytes, this.createdAt, this.expiresAt);

  final Uint8List bytes;
  final int createdAt;
  final int expiresAt;
  final age = Stopwatch()..start();

  bool get valid {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now >= createdAt &&
        now < expiresAt &&
        age.elapsedMilliseconds < expiresAt - createdAt;
  }

  Duration get remaining {
    final wall = expiresAt - DateTime.now().millisecondsSinceEpoch;
    final monotonic = expiresAt - createdAt - age.elapsedMilliseconds;
    return Duration(milliseconds: wall < monotonic ? wall : monotonic);
  }
}

/// Chỉ một bộ trích frame native cùng lúc; lớp này là JPEG trong RAM.
/// Video riêng tư còn lưu JPEG vào cache đĩa mã hóa của ảnh Nhật ký
/// ([PrivateImageDiskCache]); không lưu URL ký hoặc ghi ra cache đĩa công khai.
class DiaryVideoThumbnailCache {
  DiaryVideoThumbnailCache({
    this.maximumBytes = 8 * 1024 * 1024,
    this.maximumEntries = 40,
  }) : assert(maximumBytes > 0),
       assert(maximumEntries > 0);
  final int maximumBytes;
  final int maximumEntries;
  final _entries = <Object, _DiaryVideoThumbnailEntry>{};
  final _queue = PrivateMediaLoadQueue(maxConcurrent: 1);
  int _bytes = 0;
  int _generation = 0;
  int get byteCount => _bytes;
  int get entryCount => _entries.length;
  void clear() {
    _generation++;
    _entries.clear();
    _bytes = 0;
  }

  void remove(Object key) {
    final entry = _entries.remove(key);
    if (entry != null) _bytes -= entry.bytes.length;
  }

  /// Viewer chỉ dùng ảnh còn hạn đã trích ở album, không khởi chạy I/O mới.
  Uint8List? peek(Object key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (!entry.valid) {
      _bytes -= entry.bytes.length;
      return null;
    }
    _entries[key] = entry;
    return entry.bytes;
  }

  Duration? remaining(Object key) {
    final entry = _entries[key];
    return entry != null && entry.valid ? entry.remaining : null;
  }

  /// Đưa JPEG đã có (ví dụ đọc từ cache đĩa mã hóa) vào RAM, cùng trần byte/mục
  /// với lượt trích. Trả null khi ảnh rỗng, quá trần hoặc đã hết hạn.
  Uint8List? put(Object key, Uint8List bytes, {int? expiresAt}) {
    if (bytes.isEmpty || bytes.length > maximumBytes) return null;
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final maximumExpiry =
        createdAt + const Duration(minutes: 45).inMilliseconds;
    final validUntil = expiresAt == null || expiresAt > maximumExpiry
        ? maximumExpiry
        : expiresAt;
    if (validUntil <= createdAt) return null;
    remove(key);
    while (_entries.isNotEmpty &&
        (_bytes + bytes.length > maximumBytes ||
            _entries.length >= maximumEntries)) {
      _bytes -= _entries.remove(_entries.keys.first)!.bytes.length;
    }
    _entries[key] = _DiaryVideoThumbnailEntry(bytes, createdAt, validUntil);
    _bytes += bytes.length;
    return bytes;
  }

  Future<Uint8List?> load(
    Object key, {
    required bool Function() isCurrent,
    required Future<Uint8List> Function() extract,
    int? expiresAt,
  }) async {
    final generation = _generation;
    bool current() => generation == _generation && isCurrent();
    return _queue.run<Uint8List?>(
      isCurrent: current,
      action: () async {
        final cached = peek(key);
        if (cached != null) return cached;
        final bytes = await extract();
        if (!current()) return null;
        if (bytes.isEmpty || bytes.length > maximumBytes) {
          throw StateError('thumbnail-too-large');
        }
        return put(key, bytes, expiresAt: expiresAt);
      },
    );
  }
}

class DiaryVideoThumbnail extends StatefulWidget {
  const DiaryVideoThumbnail({
    super.key,
    required this.url,
    this.houseId,
    this.memoryId,
    this.private = false,
    this.cacheWidth = 512,
    this.resolve,
    this.extract,
    this.currentUid,
    this.authChanges,
    this.cache,
    this.urlService,
    this.diskCache,
    this.cacheOnly = false,
    this.showPlayOverlay = true,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.dataPreferences,
    this.checkConnectivity,
    this.connectivityChanges,
  });
  final String url;
  final String? houseId;
  final String? memoryId;
  final bool private;
  final int cacheWidth;

  /// Dùng sau khi player đã xác minh quyền mới; chỉ đọc JPEG trong RAM/cache
  /// đĩa mã hóa, không resolve hoặc trích video.
  final bool cacheOnly;

  /// Cache đĩa mã hóa của ảnh Nhật ký; mặc định dùng bản chung của app.
  final PrivateImageDiskCache? diskCache;
  final bool showPlayOverlay;
  final BoxFit fit;
  final Widget? placeholder;
  final Future<PrivateMediaUrlResult> Function()? resolve;
  final Future<Uint8List> Function(String)? extract;
  final String? Function()? currentUid;
  final Stream<String?>? authChanges;
  final DiaryVideoThumbnailCache? cache;
  final PrivateMediaUrlService? urlService;
  final MediaDataPreferences? dataPreferences;
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;
  final Stream<List<ConnectivityResult>>? connectivityChanges;
  @override
  State<DiaryVideoThumbnail> createState() => _DiaryVideoThumbnailState();
}

class _DiaryVideoThumbnailState extends State<DiaryVideoThumbnail>
    with ScreenActivityMixin, WidgetsBindingObserver {
  static final _cache = DiaryVideoThumbnailCache();
  static const _channel = MethodChannel('soullocket/memory_video_encoder');
  PrivateMediaUrlService? _ownedUrls;
  PrivateMediaUrlService get _urls =>
      widget.urlService ??
      (_ownedUrls ??= PrivateMediaUrlService(
        currentUid: widget.currentUid,
        authChanges: widget.authChanges == null
            ? null
            : () => widget.authChanges!,
      ));
  StreamSubscription<String?>? _auth;
  StreamSubscription<List<ConnectivityResult>>? _network;
  bool _networkBlocked = false;
  MediaDataPreferences get _dataPreferences =>
      widget.dataPreferences ?? MediaDataPreferences.instance;
  Uint8List? _bytes;
  String? _nativeRequestId;
  int _generation = 0;
  bool _loading = false;
  bool _failed = false;
  String? _uid;
  String? get currentUid => widget.currentUid != null
      ? widget.currentUid!()
      : FirebaseAuth.instance.currentUser?.uid;
  DiaryVideoThumbnailCache get cache => widget.cache ?? _cache;
  Object _cacheKey(String? uid) => (
    widget.private,
    widget.private ? uid : null,
    widget.houseId,
    widget.memoryId,
    widget.private ? null : widget.url.trim(),
  );

  /// Ảnh xem trước video riêng tư dùng chung cache đĩa mã hóa với ảnh Nhật ký
  /// (cùng TTL/dọn khi xóa kỷ niệm, đổi tài khoản hoặc xóa cache trong Cài đặt).
  PrivateImageDiskCache? get _disk {
    if (!widget.private ||
        kIsWeb ||
        (widget.houseId?.isEmpty ?? true) ||
        (widget.memoryId?.isEmpty ?? true)) {
      return null;
    }
    final injected = widget.diskCache;
    if (injected != null) return injected;
    try {
      return PrivateImageDiskCache.instance;
    } catch (_) {
      // Firebase chưa khởi tạo (test/preview): chỉ dùng cache RAM.
      return null;
    }
  }

  String _diskKey(String uid) => PrivateImageDiskCache.key(
    uid,
    widget.houseId!,
    widget.memoryId!,
    512,
    variant: 'video_poster',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dataPreferences.addListener(_dataPreferencesChanged);
    if (widget.private) {
      _uid = currentUid;
      _auth =
          (widget.authChanges ??
                  FirebaseAuth.instance.authStateChanges().map(
                    (user) => user?.uid,
                  ))
              .listen(
                (uid) {
                  if (uid == _uid) return;
                  _uid = uid;
                  cache.clear();
                  _invalidate();
                  if (isScreenActive) unawaited(_load());
                },
                onError: (Object _) {
                  cache.clear();
                  _invalidate();
                },
              );
    }
  }

  void _dataPreferencesChanged() {
    if (widget.cacheOnly) return;
    _invalidate();
    if (isScreenActive) unawaited(_load());
  }

  void _watchNetwork(bool wifiOnly) {
    if (!wifiOnly || widget.cacheOnly) {
      unawaited(_network?.cancel());
      _network = null;
      _networkBlocked = false;
      return;
    }
    _network ??=
        (widget.connectivityChanges ?? Connectivity().onConnectivityChanged).listen(
          (connections) {
            final blocked = !connections.contains(ConnectivityResult.wifi);
            final wasBlocked = _networkBlocked;
            _networkBlocked = blocked;
            if (blocked) {
              // Dừng phần video đang tải; JPEG đã có vẫn được dùng trên mạng di động.
              _generation++;
              unawaited(_cancelNativeThumbnail());
              _loading = false;
              if (mounted) setState(() {});
            } else if (wasBlocked && isScreenActive) {
              unawaited(_load());
            }
          },
          onError: (Object _) {
            _networkBlocked = true;
            _generation++;
            unawaited(_cancelNativeThumbnail());
            _loading = false;
            if (mounted) setState(() {});
          },
        );
  }

  Future<void> _checkVideoDataPolicy(bool Function() current) async {
    final settings = await _dataPreferences.read();
    if (!current()) throw StateError('stale-thumbnail');
    _watchNetwork(settings.wifiOnlyVideos);
    if (settings.wifiOnlyVideos) {
      final allowed = await _dataPreferences.canStartVideo(
        checkConnectivity: widget.checkConnectivity,
      );
      if (!current()) throw StateError('stale-thumbnail');
      _networkBlocked = !allowed;
      if (!allowed) throw StateError('thumbnail-wifi-required');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Route album có thể đã ẩn trước khi app xuống nền, nên không chỉ dựa
    // vào thay đổi active của route để dọn JPEG riêng tư. Inactive chỉ là mất
    // tiêu điểm tạm thời (kéo thanh thông báo, hộp thoại hệ thống) nên giữ ảnh.
    if (widget.private &&
        state != AppLifecycleState.resumed &&
        state != AppLifecycleState.inactive) {
      cache.clear();
      _invalidate();
    }
  }

  /// Giữ JPEG khi app chỉ inactive hoặc route album đang bị màn xem video che
  /// (app vẫn mở): đóng màn xem/kéo xuống không phải chờ ảnh tải lại.
  bool get _retainPixelsWhileInactive {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive) {
      return true;
    }
    return isScreenForeground && ModalRoute.of(context)?.isCurrent == false;
  }

  void _invalidate() {
    _generation++;
    unawaited(_cancelNativeThumbnail());
    _bytes = null;
    _loading = false;
    _failed = false;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DiaryVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataPreferences != oldWidget.dataPreferences) {
      (oldWidget.dataPreferences ?? MediaDataPreferences.instance)
          .removeListener(_dataPreferencesChanged);
      _dataPreferences.addListener(_dataPreferencesChanged);
    }
    if (widget.cacheOnly ||
        widget.connectivityChanges != oldWidget.connectivityChanges ||
        widget.dataPreferences != oldWidget.dataPreferences) {
      unawaited(_network?.cancel());
      _network = null;
      _networkBlocked = false;
    }
    if (widget.private != oldWidget.private ||
        widget.currentUid != oldWidget.currentUid ||
        widget.authChanges != oldWidget.authChanges) {
      cache.clear();
      unawaited(_auth?.cancel());
      _auth = null;
      _ownedUrls?.dispose();
      _ownedUrls = null;
      _uid = widget.private ? currentUid : null;
      if (widget.private) {
        _auth =
            (widget.authChanges ??
                    FirebaseAuth.instance.authStateChanges().map(
                      (user) => user?.uid,
                    ))
                .listen(
                  (uid) {
                    if (uid == _uid) return;
                    _uid = uid;
                    cache.clear();
                    _invalidate();
                    if (isScreenActive) unawaited(_load());
                  },
                  onError: (Object _) {
                    cache.clear();
                    _invalidate();
                  },
                );
      }
    }
    if (widget.url != oldWidget.url ||
        widget.houseId != oldWidget.houseId ||
        widget.memoryId != oldWidget.memoryId ||
        widget.cacheOnly != oldWidget.cacheOnly ||
        widget.cache != oldWidget.cache ||
        widget.urlService != oldWidget.urlService ||
        widget.private != oldWidget.private ||
        widget.currentUid != oldWidget.currentUid ||
        widget.authChanges != oldWidget.authChanges ||
        widget.dataPreferences != oldWidget.dataPreferences) {
      _invalidate();
      if (isScreenActive) unawaited(_load());
    }
  }

  @override
  void onScreenActivityChanged(bool active) {
    if (!active) {
      _generation++;
      unawaited(_cancelNativeThumbnail());
      _loading = false;
      if (widget.private && !_retainPixelsWhileInactive) {
        _bytes = null;
        // Đổi tab giữ JPEG trong RAM. Chạy nền xóa cả cache RAM.
        if (!isScreenForeground) cache.clear();
        // Lifecycle đổi không tự dựng lại widget; bỏ Image khỏi cây ngay để
        // frame riêng tư không còn giữ pixels khi app/tab đã bị ẩn.
        if (mounted) setState(() {});
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && isScreenActive) unawaited(_load());
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Future<void> _load() async {
    if (_loading || _bytes != null || !isScreenActive) return;
    final generation = ++_generation;
    final uid = _uid;
    bool current() =>
        mounted &&
        isScreenActive &&
        generation == _generation &&
        (!widget.private || (uid != null && uid == _uid && uid == currentUid));
    final key = _cacheKey(uid);
    void show(Uint8List bytes) => setState(() {
      _bytes = bytes;
      _loading = false;
      _failed = false;
    });
    // JPEG đã trích còn trong RAM/cache đĩa mã hóa: hiện ngay như ảnh riêng
    // tư của Nhật ký, không xin quyền hay mở lại video. Danh sách kỷ niệm vẫn
    // do rules RTDB kiểm soát nên mất quyền thì ô video cũng không còn được dựng.
    final inMemory = cache.peek(key);
    if (inMemory != null) {
      if (current()) show(inMemory);
      return;
    }
    _loading = true;
    final disk = _disk;
    if (disk != null && uid != null) {
      final stored = await disk.read(uid, _diskKey(uid));
      if (!current()) return;
      if (stored != null) {
        show(cache.put(key, stored) ?? stored);
        return;
      }
    }
    if (widget.cacheOnly) {
      if (!current()) return;
      setState(() {
        _bytes = null;
        _loading = false;
        _failed = true;
      });
      return;
    }
    if (!current()) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    var grantReady = !widget.private;
    try {
      // Chưa có JPEG trên máy: xin quyền mới rồi mới trích frame từ video.
      var url = widget.url;
      if (widget.private) {
        final grant =
            await (widget.resolve?.call() ??
                    _urls.resolve(
                      houseId: widget.houseId ?? '',
                      mediaId: widget.memoryId ?? '',
                      kind: 'memory_image',
                      forceRefresh: true,
                    ))
                .timeout(const Duration(seconds: 25));
        url = grant.url;
        grantReady = true;
      }
      if (!current()) return;
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw StateError('invalid-thumbnail-url');
      }
      final bytes = await cache.load(
        key,
        isCurrent: current,
        extract: () async {
          if (!current()) throw StateError('stale-thumbnail');
          await _checkVideoDataPolicy(current);
          if (!current()) throw StateError('stale-thumbnail');
          return widget.extract?.call(url) ?? _nativeThumbnail(url, generation);
        },
      );
      if (!current()) return;
      if (bytes == null) throw StateError('expired-thumbnail');
      if (disk != null && uid != null) {
        // Lưu cả khi người dùng vừa rời màn: JPEG vẫn đúng tài khoản/kỷ niệm,
        // lần mở sau không phải tải lại video. Cache tự chặn khi đổi tài khoản.
        unawaited(
          disk.write(
            uid,
            _diskKey(uid),
            bytes,
            () => uid == currentUid,
            memoryTag: PrivateImageDiskCache.memoryTag(
              uid,
              widget.houseId!,
              widget.memoryId!,
            ),
          ),
        );
      }
      show(bytes);
    } catch (_) {
      if (widget.private && !grantReady && current()) cache.remove(key);
      if (current()) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _cancelNativeThumbnail() async {
    final requestId = _nativeRequestId;
    if (requestId == null) return;
    _nativeRequestId = null;
    try {
      await _channel
          .invokeMethod<void>('cancelThumbnail', {'requestId': requestId})
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<Uint8List> _nativeThumbnail(String url, int generation) async {
    const deadline = Duration(seconds: 25);
    final requestId =
        'thumbnail_${DateTime.now().microsecondsSinceEpoch}_$generation';
    final elapsed = Stopwatch()..start();
    _nativeRequestId = requestId;
    try {
      while (true) {
        try {
          final bytes = await _channel
              .invokeMethod<Uint8List>('thumbnail', {
                'url': url,
                'requestId': requestId,
                'maximumSize': 1024 * 1024,
              })
              .timeout(deadline - elapsed.elapsed);
          if (bytes == null || bytes.isEmpty || bytes.length > 1024 * 1024) {
            throw StateError('invalid-thumbnail');
          }
          return bytes;
        } on PlatformException catch (error) {
          // Lượt trước vừa bị hủy nhưng I/O native chưa dừng hẳn: chờ worker
          // rảnh rồi thử lại, không đánh dấu lỗi vĩnh viễn cho ô video này.
          if (error.code != 'thumbnail_busy' ||
              generation != _generation ||
              elapsed.elapsed >= deadline - const Duration(seconds: 1)) {
            rethrow;
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (generation != _generation) throw StateError('stale-thumbnail');
        }
      }
    } on TimeoutException {
      await _cancelNativeThumbnail();
      rethrow;
    } finally {
      if (_nativeRequestId == requestId) _nativeRequestId = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_cancelNativeThumbnail());
    WidgetsBinding.instance.removeObserver(this);
    _dataPreferences.removeListener(_dataPreferencesChanged);
    unawaited(_network?.cancel());
    unawaited(_auth?.cancel());
    _ownedUrls?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_bytes != null)
        Image.memory(
          _bytes!,
          cacheWidth: widget.cacheWidth.clamp(1, 512),
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              widget.placeholder ??
              const Center(child: Icon(Icons.movie_creation_outlined)),
        )
      else if (widget.placeholder != null)
        widget.placeholder!
      else if (widget.cacheOnly)
        // Poster của màn xem nằm trên nền đen: chưa có ảnh thì để trống,
        // không chèn khối xanh nhạt lóe lên trước khung hình video.
        const SizedBox.expand()
      else
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFECF4FF), Color(0xFFDCE8FB)],
            ),
          ),
          child: Center(
            child: _loading && !_failed
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.movie_creation_outlined,
                    color: Color(0xFF6E88B0),
                    size: 38,
                  ),
          ),
        ),
      if (widget.showPlayOverlay)
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x6B000000),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
    ],
  );
}
