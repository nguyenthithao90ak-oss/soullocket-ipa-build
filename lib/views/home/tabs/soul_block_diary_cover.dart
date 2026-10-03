import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/services/games/soul_block_memory_service.dart';
import '../../../utils/services/house_service.dart';

/// Ảnh bìa dùng cùng nguồn Nhật ký với game, không thay lịch sử chọn ảnh.
class SoulBlockDiaryCover extends StatefulWidget {
  const SoulBlockDiaryCover({super.key, this.revision = 0});

  final int revision;

  @override
  State<SoulBlockDiaryCover> createState() => _SoulBlockDiaryCoverState();
}

class _SoulBlockDiaryCoverState extends State<SoulBlockDiaryCover>
    with WidgetsBindingObserver {
  final _memories = SoulBlockMemoryService();
  final _houses = HouseService();
  StreamSubscription<User?>? _authSubscription;
  ui.Image? _photo;
  String? _uid;
  String? _houseId;
  int _request = 0;
  bool _active = false;
  DateTime? _lastLoad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == _uid) return;
      _uid = user?.uid;
      _houseId = null;
      _lastLoad = null;
      _request++;
      _replacePhoto(null);
      if (_active) unawaited(_loadPhoto());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    final becameActive = active && !_active;
    _active = active;
    // Tab được giữ trong bộ nhớ: chỉ tải khi hiện ra, không tải lại mỗi build.
    if (becameActive &&
        (_lastLoad == null ||
            DateTime.now().difference(_lastLoad!) >
                const Duration(minutes: 1))) {
      unawaited(_loadPhoto());
    }
  }

  @override
  void didUpdateWidget(covariant SoulBlockDiaryCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) unawaited(_loadPhoto());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active) {
      unawaited(_loadPhoto());
    }
  }

  void _replacePhoto(ui.Image? next) {
    final previous = _photo;
    setState(() => _photo = next);
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
  }

  Future<void> _loadPhoto() async {
    final request = ++_request;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final media = MediaQuery.of(context);
    final diaryWidth = (((media.size.width - 64) / 3) * media.devicePixelRatio)
        .ceil()
        .clamp(240, 768);
    _lastLoad = DateTime.now();
    bool current() =>
        mounted &&
        request == _request &&
        FirebaseAuth.instance.currentUser?.uid == uid;
    if (uid == null) return;
    try {
      final houseId = await _houses.getCurrentHouseId();
      if (!current()) return;
      if (_houseId != houseId) _replacePhoto(null);
      _houseId = houseId;
      if (houseId == null || houseId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      String? preferredId;
      // Đọc ảnh của ván đang lưu để bìa gợi đúng bức ảnh sắp ghép.
      // Không ghi URL đã ký hoặc đánh dấu một ảnh đã chơi chỉ vì xem bìa.
      try {
        final raw = prefs.getString('block_blast_saved_run_v1');
        final saved = raw == null ? null : jsonDecode(raw);
        if (saved is Map && saved['photoHouseId'] == houseId) {
          preferredId = saved['photoId'] as String?;
        }
      } catch (_) {
        // Snapshot cũ hỏng không cản ảnh bìa chọn một Nhật ký khác.
      }
      final candidates = await _memories.candidates(
        houseId,
        preferredId: preferredId,
        diaryWidth: diaryWidth,
      );
      final budget = Stopwatch()..start();
      for (final candidate in candidates.take(4)) {
        if (!current() || budget.elapsed > const Duration(seconds: 18)) return;
        try {
          final memory = await _memories.loadPhoto(
            houseId,
            candidate,
            diaryWidth: diaryWidth,
          );
          if (!current()) {
            memory?.image.dispose();
            return;
          }
          if (memory == null) continue;
          final image = memory.image;
          if (!current()) {
            image.dispose();
            return;
          }
          _replacePhoto(image);
          return;
        } catch (_) {
          if (!current()) return;
        }
      }
      if (current()) _replacePhoto(null);
    } catch (_) {
      // Mạng yếu vẫn giữ ảnh mẫu hoặc ảnh đã giải mã của cùng tài khoản.
    }
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    _memories.dispose();
    _photo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SoulBlockPhotoArtwork(image: _photo);
}

Future<ui.Image> _decodeCoverImage(ImageProvider source) async {
  final provider = ResizeImage(
    source,
    width: 640,
    height: 640,
    policy: ResizeImagePolicy.fit,
  );
  final stream = provider.resolve(const ImageConfiguration());
  final result = Completer<ui.Image>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!result.isCompleted) result.complete(info.image.clone());
      info.dispose();
    },
    onError: (Object error, StackTrace? stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  try {
    return await result.future.timeout(const Duration(seconds: 8));
  } finally {
    stream.removeListener(listener);
    await provider.evict();
  }
}

/// Phần trình bày có ảnh mẫu offline, độc lập với Firebase và trạng thái tải game.
class SoulBlockPhotoArtwork extends StatefulWidget {
  const SoulBlockPhotoArtwork({super.key, this.image});

  final ui.Image? image;

  @override
  State<SoulBlockPhotoArtwork> createState() => _SoulBlockPhotoArtworkState();
}

class _SoulBlockPhotoArtworkState extends State<SoulBlockPhotoArtwork> {
  ui.Image? _sample;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSample());
  }

  Future<void> _loadSample() async {
    try {
      final sample = await _decodeCoverImage(
        const AssetImage('assets/images/default_home_bg.jpg'),
      );
      if (!mounted) {
        sample.dispose();
        return;
      }
      setState(() => _sample = sample);
    } catch (_) {
      // Giữ khung ảnh trung tính nếu tài nguyên đang được nạp.
    }
  }

  @override
  void dispose() {
    _sample?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image ?? _sample;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(image),
          tween: Tween(begin: reduced ? 1 : 0, end: 1),
          duration: Duration(milliseconds: reduced ? 0 : 650),
          curve: Curves.easeOutCubic,
          builder: (context, reveal, _) => CustomPaint(
            painter: _DiaryFragmentsPainter(
              image: image,
              sample: widget.image == null,
              dark: dark,
              reveal: reveal,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _DiaryFragmentsPainter extends CustomPainter {
  const _DiaryFragmentsPainter({
    required this.image,
    required this.sample,
    required this.dark,
    required this.reveal,
  });

  final ui.Image? image;
  final bool sample, dark;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final side = math.min(size.height * .64, size.width * .48);
    final cell = side / 4;
    final board = Rect.fromCenter(
      center: Offset.zero,
      width: side,
      height: side,
    );
    final glow = Rect.fromCenter(
      center: center,
      width: side * 2.2,
      height: side * 1.55,
    );
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            (dark ? const Color(0xFFCFBFD9) : Colors.white).withValues(
              alpha: dark ? .13 : .78,
            ),
            Colors.transparent,
          ],
        ).createShader(glow),
    );

    // Năm mảnh phủ kín cùng một ảnh 4×4; mỗi ô giữ đúng tọa độ nguồn.
    // Chỉ tách vị trí và xoay cả mảnh, không lấy ngẫu nhiên các ảnh/ô khác nhau.
    const pieces = [
      (
        cells: [Offset(0, 0), Offset(1, 0), Offset(0, 1)],
        drift: Offset(-24, -15),
        angle: -.14,
      ),
      (
        cells: [Offset(2, 0), Offset(3, 0), Offset(3, 1)],
        drift: Offset(24, -16),
        angle: .15,
      ),
      (
        cells: [Offset(1, 1), Offset(2, 1), Offset(1, 2)],
        drift: Offset(0, -1),
        angle: -.035,
      ),
      (
        cells: [Offset(0, 2), Offset(0, 3), Offset(1, 3)],
        drift: Offset(-22, 21),
        angle: .12,
      ),
      (
        cells: [Offset(2, 2), Offset(3, 2), Offset(2, 3), Offset(3, 3)],
        drift: Offset(22, 19),
        angle: -.10,
      ),
    ];
    Rect? source;
    if (image != null) {
      final imageSide = math.min(image!.width, image!.height).toDouble();
      source = Rect.fromLTWH(
        (image!.width - imageSide) / 2,
        sample ? image!.height - imageSide : (image!.height - imageSide) / 2,
        imageSide,
        imageSide,
      );
    }
    final scale = side / 154;
    for (final piece in pieces) {
      final path = Path();
      for (final point in piece.cells) {
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              board.left + point.dx * cell,
              board.top + point.dy * cell,
              cell,
              cell,
            ).deflate(.7),
            Radius.circular(cell * .13),
          ),
        );
      }
      final bounds = path.getBounds();
      final pivot = bounds.center;
      final drift = piece.drift * scale * (1 + (1 - reveal) * .35);
      canvas.save();
      canvas.translate(
        center.dx + pivot.dx + drift.dx,
        center.dy + pivot.dy + drift.dy,
      );
      canvas.rotate(piece.angle * (1 + (1 - reveal) * .5));
      canvas.translate(-pivot.dx, -pivot.dy);
      canvas.drawShadow(
        path,
        const Color(0xFF47384F).withValues(alpha: dark ? .48 : .28),
        7,
        false,
      );
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFFCF6));
      if (image != null && source != null) {
        canvas.save();
        canvas.clipPath(path);
        canvas.drawImageRect(
          image!,
          source,
          board,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: .84)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white.withValues(alpha: .17), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
      );
      canvas.restore();
    }

    void sparkle(Offset position, double radius) {
      final point = center + position * scale;
      final path = Path()
        ..moveTo(point.dx, point.dy - radius)
        ..quadraticBezierTo(
          point.dx + radius * .24,
          point.dy - radius * .24,
          point.dx + radius,
          point.dy,
        )
        ..quadraticBezierTo(
          point.dx + radius * .24,
          point.dy + radius * .24,
          point.dx,
          point.dy + radius,
        )
        ..quadraticBezierTo(
          point.dx - radius * .24,
          point.dy + radius * .24,
          point.dx - radius,
          point.dy,
        )
        ..quadraticBezierTo(
          point.dx - radius * .24,
          point.dy - radius * .24,
          point.dx,
          point.dy - radius,
        );
      canvas.drawPath(path, Paint()..color = const Color(0xFFD4B77D));
    }

    sparkle(const Offset(-135, -48), 7);
    sparkle(const Offset(137, 44), 5);
    canvas.drawCircle(
      center + const Offset(123, -82) * scale,
      3,
      Paint()..color = Colors.white.withValues(alpha: .9),
    );
    canvas.drawCircle(
      center + const Offset(-122, 83) * scale,
      2.5,
      Paint()..color = const Color(0xFFB9A7C9).withValues(alpha: .65),
    );
  }

  @override
  bool shouldRepaint(covariant _DiaryFragmentsPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.sample != sample ||
      oldDelegate.dark != dark ||
      oldDelegate.reveal != reveal;
}
