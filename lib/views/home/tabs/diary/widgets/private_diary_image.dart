import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../utils/private_media_load_queue.dart';
import '../../../../../utils/network_reachability.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/services/private_media_url_service.dart';
import '../../../../../utils/services/storage/private_image_disk_cache.dart';
import '../../../../../utils/services/storage/private_image_download.dart';
import 'private_diary_image_scope.dart';
import 'diary_image_loading.dart';

/// Ảnh House dùng cache đĩa riêng theo tài khoản/nhà/kỷ niệm.
/// Không dùng URL ký làm khóa nên có thể mở lại khi mất mạng trong 14 ngày.
class PrivateDiaryImage extends StatefulWidget {
  const PrivateDiaryImage({
    super.key,
    required this.houseId,
    required this.memoryId,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.retainCacheWidth,
    this.placeholderCacheWidth,
    this.highPriority = false,
    this.resolve,
    this.authChanges,
    this.currentUid,
    this.imageProviderFactory,
    this.loadQueue,
    this.diskCache,
    this.isOnline,
    this.onlineChanges,
  });

  final String houseId;
  final String memoryId;
  final BoxFit fit;
  final int? cacheWidth;

  /// Giữ thêm bản bytes gốc đã nhận được ở cache đĩa mã hóa để viewer không
  /// phải tải lại cùng ảnh khi người dùng mở từ lưới.
  final int? retainCacheWidth;

  /// Cỡ ảnh nhỏ đã lưu (ví dụ ảnh ở lưới album). Khi bản [cacheWidth] chưa có,
  /// hiện tạm ảnh nhỏ này trong lúc tải thay vì màn chờ.
  final int? placeholderCacheWidth;

  /// Số ô được xin link cùng lúc: hai lượt gộp đủ 12 ảnh (giới hạn mỗi lượt của máy chủ).
  static const int urlResolveConcurrency = 24;

  /// Ảnh đang xem toàn màn hình: xin link và tải chen lên đầu hàng đợi chung với lưới album.
  final bool highPriority;
  final Future<PrivateMediaUrlResult> Function()? resolve;
  final Stream<String?>? authChanges;
  final String? Function()? currentUid;
  final ImageProvider<Object> Function(String)? imageProviderFactory;
  final PrivateMediaLoadQueue? loadQueue;
  final PrivateImageDiskCache? diskCache;

  /// Trạng thái mạng hiện tại / thay đổi mạng. Mặc định dùng [NetworkReachability] ở luồng thật
  /// (không có `resolve` tiêm vào); khi offline, ảnh chưa có trong cache báo lỗi ngay thay vì chờ
  /// hết 25 giây xin link, và tự tải lại khi có mạng trở lại.
  final bool Function()? isOnline;
  final Stream<bool>? onlineChanges;

  @override
  State<PrivateDiaryImage> createState() => _PrivateDiaryImageState();
}

class _PrivateDiaryImageState extends State<PrivateDiaryImage>
    with WidgetsBindingObserver {
  // Xin link: máy chủ nhận tối đa 12 ảnh mỗi lượt gộp. Với 6 ô chạy cùng lúc mỗi lượt chỉ
  // chở 6 ảnh nên lưới 200 ảnh cần ~34 lượt nối đuôi (~40 giây); 24 ô cho 2 lượt đủ 12 ảnh
  // chạy song song. Tải tệp vẫn giới hạn 6 để không nghẽn mạng.
  static final _loadQueue = PrivateMediaLoadQueue(
    maxConcurrent: PrivateDiaryImage.urlResolveConcurrency,
  );
  static final _downloadQueue = PrivateMediaLoadQueue();
  late final _urlService = PrivateMediaUrlService(
    currentUid: widget.currentUid,
    authChanges: widget.authChanges == null ? null : () => widget.authChanges!,
  );
  ImageProvider<Object>? _provider;
  ImageProvider<Object>? _placeholder;
  bool _ownsPlaceholder = false;
  PrivateDiaryImageCache? _cache;
  PrivateDiaryImageCacheEntry? _entry;
  StreamSubscription<String?>? _auth;
  Timer? _expiry;
  Timer? _loadingDeadline;
  StreamSubscription<bool>? _onlineSub;
  int _generation = 0;
  bool _failed = false;
  // Lỗi do đang offline (khác lỗi đổi tài khoản): chỉ loại này mới tự tải lại khi có mạng.
  bool _failedOffline = false;
  bool _appVisible = true;
  bool _tabVisible = false;

  bool get _visible => _appVisible && _tabVisible;
  String? _uid;

  bool Function()? get _onlineCheck =>
      widget.isOnline ??
      (widget.resolve == null ? () => NetworkReachability.isOnline : null);

  Stream<bool>? get _onlineStream =>
      widget.onlineChanges ??
      (widget.resolve == null ? NetworkReachability.changes : null);

  String? get currentUid =>
      widget.currentUid?.call() ??
      (widget.currentUid == null
          ? FirebaseAuth.instance.currentUser?.uid
          : null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appVisible =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive;
    _uid = currentUid;
    _onlineSub = _onlineStream?.listen((online) {
      // ConnectivityService phát `true` cả ở trạng thái "đang kết nối lại" (mỗi 5 giây khi vẫn mất
      // mạng); chỉ tải lại khi trạng thái hiện tại thật sự đã online.
      final stillOffline = !(_onlineCheck?.call() ?? true);
      if (online && !stillOffline && _failedOffline && _visible && mounted) {
        unawaited(_load());
      }
    });
    _auth =
        (widget.authChanges ??
                FirebaseAuth.instance.authStateChanges().map(
                  (user) => user?.uid,
                ))
            .listen(
              (uid) {
                if (uid != _uid) {
                  _uid = uid;
                  _urlService.clear();
                  _cache?.clear();
                  unawaited(
                    widget.diskCache?.clear() ??
                        PrivateImageDiskCache.clearIfInitialized(),
                  );
                  _clear();
                  // Không tải lại ảnh của House cũ bằng phiên đăng nhập mới.
                  if (mounted) setState(() => _failed = true);
                }
              },
              onError: (Object _) {
                _urlService.clear();
                _cache?.clear();
                unawaited(
                  widget.diskCache?.clear() ??
                      PrivateImageDiskCache.clearIfInitialized(),
                );
                _clear();
                if (mounted) setState(() => _failed = true);
              },
            );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cache = PrivateDiaryImageScope.maybeOf(context, widget.houseId);
    final cacheChanged = cache != _cache;
    _cache = cache;
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _tabVisible && !cacheChanged) return;
    _tabVisible = visible;
    // Tab được giữ sống vẫn nhận timer khi ẩn. Dừng cấp URL ở tab ẩn và
    // xin quyền mới khi mở lại, kể cả lần tải trước đã thất bại.
    if (_visible) {
      unawaited(_load());
    } else {
      _clear();
    }
  }

  void _clear() {
    ++_generation;
    _expiry?.cancel();
    _loadingDeadline?.cancel();
    final provider = _provider;
    final retained = _entry != null && (_cache?.contains(_entry!) ?? false);
    _provider = null;
    _entry = null;
    if (provider != null && !retained) unawaited(provider.evict());
    final placeholder = _placeholder;
    _placeholder = null;
    // Ảnh tạm lấy từ cache RAM dùng chung thì không thu hồi.
    if (placeholder != null && _ownsPlaceholder) {
      unawaited(placeholder.evict());
    }
    _ownsPlaceholder = false;
  }

  Future<void> _load({bool refresh = false}) async {
    final previous = _entry;
    if (refresh && previous != null) _cache?.remove(previous);
    _clear();
    if (!_visible || !mounted) return;
    final started = Stopwatch()..start();
    final generation = _generation;
    final uid = currentUid;
    bool current() =>
        mounted &&
        _visible &&
        generation == _generation &&
        uid != null &&
        uid == currentUid;
    if (mounted) {
      setState(() {
        _failed = false;
        _failedOffline = false;
      });
    }
    try {
      if (uid == null) throw StateError('Authentication required');
      _cache?.bindSession(
        uid,
        widget.authChanges ??
            FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
      );
      final key = (
        uid: uid,
        houseId: widget.houseId,
        memoryId: widget.memoryId,
        width: widget.cacheWidth,
      );
      final cached = refresh ? null : _cache?.get(key);
      if (cached != null) {
        _show(cached);
        if (kDebugMode) debugPrint('[PrivateDiaryImage] RAM cache hit');
        return;
      }
      final diskKey = PrivateImageDiskCache.key(
        uid,
        widget.houseId,
        widget.memoryId,
        widget.cacheWidth,
      );
      final diskCache =
          widget.diskCache ??
          (widget.imageProviderFactory == null && !kIsWeb
              ? PrivateImageDiskCache.instance
              : null);
      if (widget.imageProviderFactory == null) {
        final bytes = await diskCache?.read(uid, diskKey);
        if (!current()) return;
        if (bytes != null) {
          final entry = PrivateDiaryImageCacheEntry(
            _providerFromBytes(bytes),
            DateTime.now().millisecondsSinceEpoch +
                PrivateImageDiskCache.ttl.inMilliseconds,
          );
          _cache?.put(key, entry);
          _show(entry);
          if (kDebugMode) {
            debugPrint('[PrivateDiaryImage] encrypted disk cache hit');
          }
          return;
        }
      }
      // Bản lớn chưa có: hiện tạm ảnh nhỏ đã lưu (RAM hoặc cache đĩa mã hóa)
      // trong lúc xin quyền và tải, để mở ảnh không phải nhìn màn chờ.
      final placeholderWidth = widget.placeholderCacheWidth;
      if (placeholderWidth != null && placeholderWidth != widget.cacheWidth) {
        final ramHit = _cache?.get((
          uid: uid,
          houseId: widget.houseId,
          memoryId: widget.memoryId,
          width: placeholderWidth,
        ));
        Uint8List? bytes;
        if (ramHit == null && widget.imageProviderFactory == null) {
          bytes = await diskCache?.read(
            uid,
            PrivateImageDiskCache.key(
              uid,
              widget.houseId,
              widget.memoryId,
              placeholderWidth,
            ),
          );
          if (!current()) return;
        }
        final placeholder =
            ramHit?.provider ?? (bytes == null ? null : MemoryImage(bytes));
        if (placeholder != null && _provider == null) {
          setState(() {
            _placeholder = placeholder;
            _ownsPlaceholder = ramHit == null;
          });
        }
      }
      if (widget.highPriority &&
          _placeholder == null &&
          widget.imageProviderFactory == null) {
        final bytes = await diskCache?.readPreview(
          uid,
          widget.houseId,
          widget.memoryId,
        );
        if (!current()) return;
        if (bytes != null) {
          setState(() {
            _placeholder = MemoryImage(bytes);
            _ownsPlaceholder = true;
          });
        }
      }
      final isOnline = _onlineCheck;
      if (isOnline != null && !isOnline()) {
        // Offline và ảnh chưa có trong cache: báo ngay (giữ ảnh nhỏ nếu có), tải lại khi có mạng.
        if (current()) {
          setState(() {
            _failed = true;
            _failedOffline = true;
          });
        }
        return;
      }
      final result = await (widget.loadQueue ?? _loadQueue)
          .run<PrivateMediaUrlResult>(
            priority: widget.highPriority,
            isCurrent: current,
            action: () {
              _loadingDeadline = Timer(const Duration(seconds: 25), () {
                if (!current()) return;
                ++_generation;
                if (kDebugMode) {
                  debugPrint('[PrivateDiaryImage] authorization deadline');
                }
                setState(() => _failed = true);
              });
              return (widget.resolve?.call() ??
                      (_cache?.urlService ?? _urlService).resolve(
                        houseId: widget.houseId,
                        mediaId: widget.memoryId,
                        kind: 'memory_image',
                        forceRefresh: refresh,
                      ))
                  .timeout(const Duration(seconds: 25));
            },
          );
      if (!current() || result == null) return;
      _loadingDeadline?.cancel();
      if (kDebugMode) {
        debugPrint(
          '[PrivateDiaryImage] authorized after ${started.elapsedMilliseconds}ms',
        );
      }
      final lifetime =
          (result.expiresAt - DateTime.now().millisecondsSinceEpoch).clamp(
            0,
            120000,
          );
      if (lifetime <= 5000) throw StateError('Expired media authorization');
      ImageProvider<Object>? provider = widget.imageProviderFactory?.call(
        result.url,
      );
      if (provider == null) {
        final bytes = await _downloadQueue.run<Uint8List>(
          priority: widget.highPriority,
          isCurrent: current,
            action: () => downloadPrivateImage(
              result.url,
              width: widget.cacheWidth,
              isCurrent: current,
              onDownloadedOriginalBytes: (originalBytes) {
                final retainedWidth = widget.retainCacheWidth;
                if (diskCache == null ||
                    retainedWidth == null ||
                    retainedWidth == widget.cacheWidth ||
                    !current()) {
                  return;
                }
                unawaited(
                  diskCache.write(
                    uid,
                    PrivateImageDiskCache.key(
                      uid,
                      widget.houseId,
                      widget.memoryId,
                      retainedWidth,
                    ),
                    originalBytes,
                    current,
                    memoryTag: PrivateImageDiskCache.memoryTag(
                      uid,
                      widget.houseId,
                      widget.memoryId,
                    ),
                  ),
                );
              },
            ),
        );
        if (!current() || bytes == null) return;
        final cacheWrite = diskCache?.write(
          uid,
          diskKey,
          bytes,
          current,
          memoryTag: PrivateImageDiskCache.memoryTag(
            uid,
            widget.houseId,
            widget.memoryId,
          ),
        );
        if (cacheWrite != null) unawaited(cacheWrite);
        if (!current()) return;
        provider = _providerFromBytes(bytes);
      }
      if (!current()) return;
      final entry = PrivateDiaryImageCacheEntry(
        provider,
        widget.imageProviderFactory == null
            ? DateTime.now().millisecondsSinceEpoch + 115000
            : DateTime.now().millisecondsSinceEpoch + lifetime - 5000,
      );
      _cache?.put(key, entry);
      _show(entry);
    } catch (error) {
      // Chỉ ghi loại lỗi/thời gian, không ghi URL ký, tài khoản hay nội dung ảnh.
      if (kDebugMode) {
        final code = error is FirebaseException
            ? error.code
            : error.runtimeType;
        debugPrint(
          '[PrivateDiaryImage] authorization failed: $code after ${started.elapsedMilliseconds}ms',
        );
      }
      if (mounted && generation == _generation) {
        _loadingDeadline?.cancel();
        setState(() => _failed = true);
      }
    }
  }

  ImageProvider<Object> _providerFromBytes(Uint8List bytes) {
    final provider = MemoryImage(bytes);
    final width = widget.cacheWidth;
    return width == null
        ? provider
        : ResizeImage(provider, width: width, allowUpscaling: false);
  }

  void _show(PrivateDiaryImageCacheEntry entry) {
    _entry = entry;
    setState(() => _provider = entry.provider);
    _expiry = Timer(entry.remaining, () => unawaited(_load(refresh: true)));
  }

  @override
  void didUpdateWidget(covariant PrivateDiaryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId ||
        oldWidget.memoryId != widget.memoryId ||
        oldWidget.cacheWidth != widget.cacheWidth) {
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive chỉ mất tiêu điểm (giả lập, hộp thoại hệ thống), màn hình vẫn
    // hiển thị. Chỉ thu hồi pixels/request khi app thật sự bị ẩn hoặc vào nền.
    final visible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (visible == _appVisible) return;
    _appVisible = visible;
    if (_visible) {
      unawaited(_load());
    } else {
      _urlService.clear();
      _cache?.clear();
      _clear();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _clear();
    _urlService.dispose();
    unawaited(_onlineSub?.cancel());
    unawaited(_auth?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _placeholderImage() => Image(
    image: _placeholder!,
    fit: widget.fit,
    width: double.infinity,
    height: double.infinity,
    filterQuality: FilterQuality.high,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const DiaryImageLoading(),
  );

  Widget _retry() => Center(
    child: IconButton(
      tooltip: L10nService().translate('core_retry'),
      onPressed: () async {
        final uid = currentUid;
        if (uid != null && widget.imageProviderFactory == null && !kIsWeb) {
          await PrivateImageDiskCache.instance.remove(
            uid,
            PrivateImageDiskCache.key(
              uid,
              widget.houseId,
              widget.memoryId,
              widget.cacheWidth,
            ),
          );
        }
        if (mounted) unawaited(_load(refresh: true));
      },
      icon: const Icon(Icons.refresh_rounded),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final placeholder = _placeholder;
    // Đang có ảnh tạm thì giữ ảnh tạm, kể cả khi bản lớn lỗi (vẫn cho thử lại sau).
    if (_failed) return placeholder == null ? _retry() : _placeholderImage();
    final provider = _provider;
    if (provider == null) {
      return placeholder == null
          ? const DiaryImageLoading()
          : _placeholderImage();
    }
    return Image(
      image: provider,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      gaplessPlayback: false,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null
          ? child
          : placeholder == null
          ? const DiaryImageLoading()
          : _placeholderImage(),
      errorBuilder: (_, error, stack) {
        if (kDebugMode) {
          final code = error is NetworkImageLoadException
              ? error.statusCode
              : error.runtimeType;
          debugPrint('[PrivateDiaryImage] image failed: $code');
        }
        return _retry();
      },
    );
  }
}
