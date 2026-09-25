import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../../utils/services/l10n_service.dart';
import '../../../../../utils/services/private_media_url_service.dart';

/// Ảnh House không đi qua disk cache chung hoặc nhận URL từ bản ghi client.
/// Provider chỉ sống trong widget; đổi phiên, vào nền hoặc hết hạn phải cấp lại.
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
  });

  final String houseId;
  final String memoryId;
  final BoxFit fit;
  final int? cacheWidth;
  final Future<PrivateMediaUrlResult> Function()? resolve;
  final Stream<String?>? authChanges;
  final String? Function()? currentUid;
  final ImageProvider<Object> Function(String)? imageProviderFactory;

  @override
  State<PrivateDiaryImage> createState() => _PrivateDiaryImageState();
}

class _PrivateDiaryImageState extends State<PrivateDiaryImage>
    with WidgetsBindingObserver {
  ImageProvider<Object>? _provider;
  StreamSubscription<String?>? _auth;
  Timer? _expiry;
  Timer? _loadingDeadline;
  int _generation = 0;
  bool _failed = false;
  bool _visible = true;
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
    _visible =
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
                  _clear();
                  // Không tải lại ảnh của House cũ bằng phiên đăng nhập mới.
                  if (mounted) setState(() => _failed = true);
                }
              },
              onError: (Object _) {
                _clear();
                if (mounted) setState(() => _failed = true);
              },
            );
    if (_visible) unawaited(_load());
  }

  void _clear() {
    ++_generation;
    _expiry?.cancel();
    _loadingDeadline?.cancel();
    final provider = _provider;
    _provider = null;
    if (provider != null) unawaited(provider.evict());
  }

  Future<void> _load() async {
    _clear();
    if (!_visible || !mounted) return;
    final generation = _generation;
    final uid = currentUid;
    bool current() =>
        mounted &&
        _visible &&
        generation == _generation &&
        uid != null &&
        uid == currentUid;
    if (mounted) setState(() => _failed = false);
    // Bao gồm cả thời gian SDK chờ Auth/App Check trước khi gửi callable.
    _loadingDeadline = Timer(const Duration(seconds: 25), () {
      if (!current()) return;
      ++_generation;
      setState(() => _failed = true);
    });
    try {
      if (uid == null) throw StateError('Authentication required');
      final result =
          await (widget.resolve?.call() ??
              PrivateMediaUrlService().resolve(
                houseId: widget.houseId,
                mediaId: widget.memoryId,
                kind: 'memory_image',
              ));
      if (!current()) return;
      _loadingDeadline?.cancel();
      final lifetime = result.expiresAt - DateTime.now().millisecondsSinceEpoch;
      if (lifetime <= 5000) throw StateError('Expired media authorization');
      // NetworkImage không ghi disk; ResizeImage giữ giới hạn giải mã thumbnail.
      final provider = ResizeImage.resizeIfNeeded(
        widget.cacheWidth,
        null,
        widget.imageProviderFactory?.call(result.url) ??
            NetworkImage(result.url),
      );
      setState(() => _provider = provider);
      _expiry = Timer(
        Duration(milliseconds: lifetime - 5000),
        () => unawaited(_load()),
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        _loadingDeadline?.cancel();
        setState(() => _failed = true);
      }
    }
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
    if (visible == _visible) return;
    _visible = visible;
    if (_visible) {
      unawaited(_load());
    } else {
      _clear();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _clear();
    unawaited(_auth?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _retry() => Center(
    child: IconButton(
      tooltip: L10nService().translate('core_retry'),
      onPressed: () => unawaited(_load()),
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
      errorBuilder: (_, error, stack) => _retry(),
    );
  }
}
