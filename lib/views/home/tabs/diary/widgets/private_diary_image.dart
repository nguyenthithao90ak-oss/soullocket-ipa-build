import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../utils/private_media_load_queue.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/services/private_media_url_service.dart';
import 'private_diary_image_scope.dart';

/// Ảnh House dùng cache đĩa riêng theo tài khoản/nhà/kỷ niệm.
/// Không dùng URL ký làm khóa nên có thể mở lại khi mất mạng trong 7 ngày.
class PrivateDiaryImage extends StatefulWidget {
  const PrivateDiaryImage({
    super.key,
    required this.houseId,
    required this.memoryId,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.resolve,
    this.authChanges,
    this.currentUid,
    this.imageProviderFactory,
    this.loadQueue,
  });

  final String houseId;
  final String memoryId;
  final BoxFit fit;
  final int? cacheWidth;
  final Future<PrivateMediaUrlResult> Function()? resolve;
  final Stream<String?>? authChanges;
  final String? Function()? currentUid;
  final ImageProvider<Object> Function(String)? imageProviderFactory;
  final PrivateMediaLoadQueue? loadQueue;

  @override
  State<PrivateDiaryImage> createState() => _PrivateDiaryImageState();
}

class _PrivateDiaryImageState extends State<PrivateDiaryImage>
    with WidgetsBindingObserver {
  static final _loadQueue = PrivateMediaLoadQueue();
  late final _urlService = PrivateMediaUrlService(
    currentUid: widget.currentUid,
    authChanges: widget.authChanges == null ? null : () => widget.authChanges!,
  );
  ImageProvider<Object>? _provider;
  PrivateDiaryImageCache? _cache;
  PrivateDiaryImageCacheEntry? _entry;
  StreamSubscription<String?>? _auth;
  Timer? _expiry;
  Timer? _loadingDeadline;
  int _generation = 0;
  bool _failed = false;
  bool _appVisible = true;
  bool _tabVisible = false;

  bool get _visible => _appVisible && _tabVisible;
  String? _uid;

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
                  unawaited(PrivateDiaryDiskCache.clear());
                  _clear();
                  // Không tải lại ảnh của House cũ bằng phiên đăng nhập mới.
                  if (mounted) setState(() => _failed = true);
                }
              },
              onError: (Object _) {
                _urlService.clear();
                _cache?.clear();
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
    if (mounted) setState(() => _failed = false);
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
      final diskKey = PrivateDiaryDiskCache.key(
        uid: uid,
        houseId: widget.houseId,
        memoryId: widget.memoryId,
        width: widget.cacheWidth,
      );
      if (widget.imageProviderFactory == null &&
          await PrivateDiaryDiskCache.hasFresh(diskKey)) {
        final entry = PrivateDiaryImageCacheEntry(
          CachedNetworkImageProvider(
            'https://private-cache.invalid/$diskKey',
            cacheKey: diskKey,
            cacheManager: PrivateDiaryDiskCache.manager,
            maxWidth: widget.cacheWidth,
          ),
          DateTime.now().millisecondsSinceEpoch +
              PrivateDiaryDiskCache.ttl.inMilliseconds,
        );
        _cache?.put(key, entry);
        _show(entry);
        if (kDebugMode) debugPrint('[PrivateDiaryImage] disk cache hit');
        return;
      }
      final result = await (widget.loadQueue ?? _loadQueue)
          .run<PrivateMediaUrlResult>(
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
      final provider =
          widget.imageProviderFactory?.call(result.url) ??
          CachedNetworkImageProvider(
            result.url,
            cacheKey: diskKey,
            cacheManager: PrivateDiaryDiskCache.manager,
            maxWidth: widget.cacheWidth,
          );
      final entry = PrivateDiaryImageCacheEntry(
        provider,
        DateTime.now().millisecondsSinceEpoch + lifetime - 5000,
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
      _cache?.clearMemory();
      _clear();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _clear();
    _urlService.dispose();
    unawaited(_auth?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _retry() => Center(
    child: IconButton(
      tooltip: L10nService().translate('core_retry'),
      onPressed: () => unawaited(_load(refresh: true)),
      icon: const Icon(Icons.refresh_rounded),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_failed) return _retry();
    final provider = _provider;
    if (provider == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Image(
      image: provider,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: false,
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
