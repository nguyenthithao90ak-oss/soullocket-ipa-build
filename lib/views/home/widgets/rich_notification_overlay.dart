import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:soullocket_app/core/sl_theme.dart';

/// Loại thông báo rich
enum RichNotifType {
  message,   // Tin nhắn mới → notification_msg_anim.json
  distance,  // Khoảng cách thay đổi → notification_distance_anim.json
  missYou,   // Nhớ nhau → missyou.pag (lottie fallback)
  like,      // Tim/like → like.pag
  generic,   // Mặc định → star_flash.json
}

/// Data của một thông báo rich
class RichNotifData {
  final RichNotifType type;
  final String title;
  final String body;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const RichNotifData({
    required this.type,
    required this.title,
    required this.body,
    this.avatarUrl,
    this.onTap,
  });
}

/// Controller toàn cục để trigger rich notification từ bất kỳ đâu
class RichNotifController {
  static final RichNotifController _instance = RichNotifController._();
  static RichNotifController get instance => _instance;
  RichNotifController._();

  final StreamController<RichNotifData> _stream =
      StreamController<RichNotifData>.broadcast();

  Stream<RichNotifData> get stream => _stream.stream;

  void show(RichNotifData data) => _stream.add(data);

  void showMessage({required String name, required String body, String? avatarUrl, VoidCallback? onTap}) =>
      show(RichNotifData(type: RichNotifType.message, title: name, body: body, avatarUrl: avatarUrl, onTap: onTap));

  void showMissYou({required String name, String? avatarUrl, VoidCallback? onTap}) =>
      show(RichNotifData(type: RichNotifType.missYou, title: name, body: 'đang nhớ bạn 💕', avatarUrl: avatarUrl, onTap: onTap));

  void showLike({required String name, String? avatarUrl, VoidCallback? onTap}) =>
      show(RichNotifData(type: RichNotifType.like, title: name, body: 'đã gửi tim cho bạn ❤️', avatarUrl: avatarUrl, onTap: onTap));

  void showDistance({required String name, required String distance, VoidCallback? onTap}) =>
      show(RichNotifData(type: RichNotifType.distance, title: name, body: 'cách bạn $distance', onTap: onTap));

  void dispose() => _stream.close();
}

/// Widget overlay hiển thị rich notification từ trên xuống
/// Đặt trong Stack ở màn hình chính
class RichNotificationOverlay extends StatefulWidget {
  const RichNotificationOverlay({super.key});

  @override
  State<RichNotificationOverlay> createState() => _RichNotificationOverlayState();
}

class _RichNotificationOverlayState extends State<RichNotificationOverlay>
    with SingleTickerProviderStateMixin {

  StreamSubscription<RichNotifData>? _sub;
  RichNotifData? _current;
  bool _visible = false;
  Timer? _hideTimer;
  late final AnimationController _anim;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);

    _sub = RichNotifController.instance.stream.listen(_onNotif);
  }

  void _onNotif(RichNotifData data) async {
    // Nếu đang hiện cái khác → ẩn trước
    if (_visible) {
      await _hideAnim();
    }
    if (!mounted) return;
    setState(() {
      _current = data;
      _visible = true;
    });
    _anim.forward(from: 0);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  Future<void> _hideAnim() async {
    _hideTimer?.cancel();
    await _anim.reverse();
    if (mounted) setState(() => _visible = false);
  }

  void _dismiss() => _hideAnim();

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  String _animAsset(RichNotifType type) {
    switch (type) {
      case RichNotifType.message:
        return 'assets/animations/notification_msg_anim.json';
      case RichNotifType.distance:
        return 'assets/animations/notification_distance_anim.json';
      case RichNotifType.missYou:
        return 'assets/animations/notification_our_distance_anim.json';
      case RichNotifType.like:
        return 'assets/animations/star_flash.json';
      case RichNotifType.generic:
        return 'assets/animations/loading_heart.json';
    }
  }

  Color _accentColor(RichNotifType type) {
    switch (type) {
      case RichNotifType.message:
        return const Color(0xFF7B61FF);
      case RichNotifType.distance:
        return const Color(0xFF4FC3F7);
      case RichNotifType.missYou:
        return const Color(0xFFFF6B9D);
      case RichNotifType.like:
        return const Color(0xFFFF4081);
      case RichNotifType.generic:
        return const Color(0xFFFFB74D);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _current == null) return const SizedBox.shrink();
    final data = _current!;
    final topPad = MediaQuery.paddingOf(context).top;
    final accent = _accentColor(data.type);

    return Positioned(
      top: topPad + 8,
      left: 12,
      right: 12,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: GestureDetector(
            onTap: () {
              data.onTap?.call();
              _dismiss();
            },
            onVerticalDragUpdate: (d) {
              if (d.delta.dy < -5) _dismiss();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    // Animation bên trái
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Lottie.asset(
                        _animAsset(data.type),
                        repeat: true,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.favorite_rounded,
                          color: accent,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Avatar bạn đời (nếu có)
                    if (data.avatarUrl != null && data.avatarUrl!.isNotEmpty) ...[
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(data.avatarUrl!),
                        backgroundColor: accent.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data.title,
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.body,
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Dismiss button
                    GestureDetector(
                      onTap: _dismiss,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.close_rounded, size: 16, color: Colors.black26),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
