part of '../pet_care_game_screen.dart';

enum _PartyPhase { candles, blown, opened }

/// Tiệc sinh nhật khi hai bé lên tuổi (kiểu Talking Tom): dây cờ, bóng bay,
/// pháo giấy, bánh kem có nến theo tuổi. Chạm bánh để thổi nến, rồi mở hộp
/// quà Hạt Ấm (nếu còn quà chưa mở). Hai bé trong cảnh đội mũ tiệc nhảy mừng.
class _BirthdayParty extends StatefulWidget {
  const _BirthdayParty({
    required this.age,
    required this.gift,
    required this.onBlow,
    required this.onOpen,
    required this.onClose,
    super.key,
  });

  final int age;

  /// Hạt Ấm trong các hộp quà đang chờ (0 khi đã mở hết).
  final int gift;
  final VoidCallback onBlow;
  final Future<bool> Function() onOpen;
  final VoidCallback onClose;

  @override
  State<_BirthdayParty> createState() => _BirthdayPartyState();
}

class _BirthdayPartyState extends State<_BirthdayParty>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  _PartyPhase _phase = _PartyPhase.candles;
  double _blownAt = -10;
  int _received = 0;
  bool _opening = false;
  bool _animate = true;

  double get _seconds => _clock.value * 12;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        UiPrefs.resolveEffectProfile(
          state: UiPrefs.notifier.value,
          isWeb: kIsWeb,
        ).animationEnabled;
    if (animate == _animate && (_clock.isAnimating || !animate)) return;
    _animate = animate;
    if (animate) {
      _clock.repeat();
    } else {
      _clock.stop();
      _clock.value = .3;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _blow() {
    if (_phase != _PartyPhase.candles) return;
    setState(() {
      _phase = _PartyPhase.blown;
      _blownAt = _seconds;
    });
    widget.onBlow();
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final gift = widget.gift;
    final saved = await widget.onOpen();
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (saved) {
        _phase = _PartyPhase.opened;
        _received = gift;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final title = context.tr('pet_care_birthday_title');
    final age = l10n.format('pet_care_birthday_age', {'age': '${widget.age}'});
    final lit = _phase == _PartyPhase.candles;
    return Material(
      key: const ValueKey('pet-care-birthday'),
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Nền mờ nhẹ: vẫn thấy hai bé đội mũ nhảy mừng phía sau.
          const ColoredBox(color: Color(0x29342434)),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, _) => CustomPaint(
                  painter: _PartyPainter(
                    seconds: _seconds,
                    burst: lit ? -1 : _seconds - _blownAt,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: IconButton.filledTonal(
                      key: const ValueKey('pet-care-birthday-close'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: _outlined(title, 30, const Color(0xFFE5507A)),
                ),
                const SizedBox(height: 6),
                _outlined(age, 18, const Color(0xFF9A5BC0)),
                const Spacer(),
                // Bánh ở góc dưới, nút bên cạnh: không che hai bé đang nhảy
                // giữa phòng.
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 12, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Semantics(
                        button: lit,
                        label: lit ? context.tr('pet_care_birthday_blow') : age,
                        onTap: lit ? _blow : null,
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: const ValueKey('pet-care-birthday-cake'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _blow,
                          child: SizedBox(
                            width: 168,
                            height: 154,
                            child: FittedBox(
                              child: SizedBox(
                                width: 230,
                                height: 210,
                                child: AnimatedBuilder(
                                  animation: _clock,
                                  builder: (context, _) => CustomPaint(
                                    painter: _CakePainter(
                                      age: widget.age,
                                      seconds: _seconds,
                                      blown: lit ? -1 : _seconds - _blownAt,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Cao theo nội dung: sau khi mở quà có thêm dòng số Hạt.
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: Center(child: _action(context, lit)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, bool lit) {
    if (lit) {
      return _pill(
        context.tr('pet_care_birthday_blow'),
        icon: Icons.touch_app_rounded,
      );
    }
    if (_phase == _PartyPhase.blown && widget.gift > 0) {
      return FilledButton.icon(
        key: const ValueKey('pet-care-birthday-open'),
        onPressed: _opening ? null : _open,
        style: FilledButton.styleFrom(
          minimumSize: const Size(160, 52),
          backgroundColor: const Color(0xFFFFC765),
          foregroundColor: const Color(0xFF7A4B1E),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.card_giftcard_rounded),
        label: Text(
          '${context.tr('pet_care_birthday_open')}  +${widget.gift}',
          style: SLTheme.quicksand(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_received > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _pill(
              L10nScope.of(
                context,
              ).format('pet_care_birthday_gift', {'seeds': '$_received'}),
              icon: Icons.spa_rounded,
            ),
          ),
        FilledButton(
          key: const ValueKey('pet-care-birthday-done'),
          onPressed: widget.onClose,
          style: FilledButton.styleFrom(
            minimumSize: const Size(140, 44),
            backgroundColor: const Color(0xFFE5507A),
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          child: Text(
            context.tr('pet_care_birthday_done'),
            style: SLTheme.quicksand(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, {required IconData icon}) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [BoxShadow(color: Color(0x33594049), blurRadius: 8)],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE5507A)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6B4A5E),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// Chữ to viền trắng, đọc rõ trên nền phòng nhiều màu.
  Widget _outlined(String text, double size, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(fontSize: size, fontWeight: FontWeight.w900)
              .copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * .22
                  ..strokeJoin = StrokeJoin.round
                  ..color = Colors.white,
              ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    ),
  );
}

const _partyColors = [
  Color(0xFFF58DAE),
  Color(0xFFF7CF5E),
  Color(0xFF7FD0B4),
  Color(0xFF86B3EE),
  Color(0xFFB998EC),
  Color(0xFFFFA07A),
];

/// Dây cờ đuôi nheo, bóng bay bay lên và pháo giấy rơi; [burst] là số giây
/// từ lúc thổi nến (âm khi chưa thổi) để bắn thêm một chùm pháo giấy.
class _PartyPainter extends CustomPainter {
  const _PartyPainter({required this.seconds, required this.burst});
  final double seconds;
  final double burst;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Bóng bay bay chậm từ dưới lên, lắc nhẹ theo gió.
    for (var i = 0; i < 7; i++) {
      final speed = 16 + (i % 3) * 5.0;
      final y = h + 60 - ((seconds * speed + i * 137) % (h + 160));
      final x = w * (.08 + i * .14) + math.sin(seconds * .9 + i) * 12;
      final color = _partyColors[i % _partyColors.length];
      final string = Path()
        ..moveTo(x, y + 30)
        ..quadraticBezierTo(x - 8, y + 50, x + 2, y + 70);
      canvas.drawPath(
        string,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x99856C7A),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 40, height: 50),
        Paint()..color = color.withValues(alpha: .92),
      );
      canvas.drawPath(
        Path()
          ..moveTo(x - 4, y + 29)
          ..lineTo(x + 4, y + 29)
          ..lineTo(x, y + 24)
          ..close(),
        Paint()..color = color,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x - 8, y - 10), width: 8, height: 13),
        Paint()..color = Colors.white.withValues(alpha: .55),
      );
    }
    // Dây cờ võng qua đầu màn.
    final top = h * .2;
    final flags = (w / 34).ceil();
    for (var i = 0; i < flags; i++) {
      final x0 = i * w / flags;
      final x1 = (i + 1) * w / flags;
      double sag(double x) => top + math.sin(x / w * math.pi) * 26;
      final a = Offset(x0, sag(x0));
      final b = Offset(x1, sag(x1));
      final tip = Offset((x0 + x1) / 2, sag((x0 + x1) / 2) + 26);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(tip.dx, tip.dy)
          ..close(),
        Paint()..color = _partyColors[i % _partyColors.length],
      );
    }
    final rope = Path()..moveTo(0, top);
    rope.quadraticBezierTo(w / 2, top + 52, w, top);
    canvas.drawPath(
      rope,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFB98A62),
    );
    // Pháo giấy rơi liên tục.
    for (var i = 0; i < 46; i++) {
      final fall = 40 + (i % 5) * 12.0;
      final y = (seconds * fall + i * 53) % (h + 20) - 10;
      final x = (i * 97 % 100) / 100 * w + math.sin(seconds * 2 + i) * 10;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(seconds * (1 + i % 3) + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -2, 8, 4),
          const Radius.circular(1.5),
        ),
        Paint()..color = _partyColors[i % _partyColors.length],
      );
      canvas.restore();
    }
    // Thổi nến xong: chùm pháo giấy bắn từ bánh lên.
    if (burst >= 0 && burst < 2.2) {
      final t = burst / 2.2;
      final origin = Offset(w / 2, h * .68);
      for (var i = 0; i < 36; i++) {
        final angle = -math.pi / 2 + (i / 36 - .5) * math.pi * 1.4;
        final speed = 220 + (i % 4) * 60.0;
        final p =
            origin +
            Offset(math.cos(angle), math.sin(angle)) * speed * t +
            Offset(0, 260 * t * t);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(i + t * 9);
        canvas.drawRect(
          const Rect.fromLTWH(-4.5, -2, 9, 4),
          Paint()
            ..color = _partyColors[i % _partyColors.length].withValues(
              alpha: (1 - t).clamp(0.0, 1.0),
            ),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PartyPainter oldDelegate) =>
      oldDelegate.seconds != seconds || oldDelegate.burst != burst;
}

/// Bánh kem hai tầng có dâu, nến theo tuổi (tối đa 7 cây, lớn hơn thì cắm
/// số tuổi); [blown] là số giây từ lúc thổi (âm khi nến còn cháy).
class _CakePainter extends CustomPainter {
  const _CakePainter({
    required this.age,
    required this.seconds,
    required this.blown,
  });
  final int age;
  final double seconds;
  final double blown;

  static const _plate = Color(0xFFFFF5E6);
  static const _sponge = Color(0xFFF6B3C6);
  static const _spongeDark = Color(0xFFE48CA6);
  static const _cream = Color(0xFFFFFBF3);
  static const _creamShade = Color(0xFFF1D9C9);
  static const _berry = Color(0xFFE5506A);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final base = size.height - 14;
    void round(Rect r, double radius, Color color) => canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      Paint()..color = color,
    );
    // Đĩa và bóng.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, base + 4), width: 210, height: 22),
      Paint()..color = const Color(0x33594049),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, base), width: 200, height: 20),
      Paint()..color = _plate,
    );
    // Tầng dưới.
    final low = Rect.fromLTWH(cx - 82, base - 66, 164, 64);
    round(low, 16, _spongeDark);
    round(low.deflate(3).shift(const Offset(0, -2)), 14, _sponge);
    _drips(canvas, Rect.fromLTWH(low.left, low.top - 2, low.width, 26));
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(
        Offset(low.left + 18 + i * 26.0, low.bottom - 16),
        3,
        Paint()..color = _partyColors[i % _partyColors.length],
      );
    }
    // Tầng trên.
    final up = Rect.fromLTWH(cx - 56, low.top - 50, 112, 52);
    round(up, 14, _spongeDark);
    round(up.deflate(3).shift(const Offset(0, -2)), 12, _sponge);
    _drips(canvas, Rect.fromLTWH(up.left, up.top - 2, up.width, 22));
    for (final dx in [-38.0, 38.0]) {
      final berry = Offset(cx + dx, up.top - 2);
      canvas.drawCircle(berry, 7, Paint()..color = _berry);
      canvas.drawCircle(
        berry + const Offset(-2, -2),
        2,
        Paint()..color = Colors.white.withValues(alpha: .7),
      );
    }
    // Nến.
    final top = up.top + 2;
    if (age <= 7) {
      final count = math.max(1, age);
      for (var i = 0; i < count; i++) {
        final x = cx + (i - (count - 1) / 2) * (count > 5 ? 11 : 14);
        _candle(canvas, Offset(x, top), i);
      }
    } else {
      // Tuổi lớn: nến số.
      final digits = '$age';
      final painter = TextPainter(
        text: TextSpan(
          text: digits,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Color(0xFF8FC9F2),
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = Offset(cx - painter.width / 2, top - painter.height + 4);
      final outline = TextPainter(
        text: TextSpan(
          text: digits,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            height: 1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..color = Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      outline.paint(canvas, box);
      painter.paint(canvas, box);
      for (var i = 0; i < digits.length; i++) {
        final x = box.dx + painter.width * (i + .5) / digits.length;
        _flame(canvas, Offset(x, box.dy - 2), i);
      }
    }
  }

  void _candle(Canvas canvas, Offset bottom, int i) {
    final color = _partyColors[i % _partyColors.length];
    final body = Rect.fromLTWH(bottom.dx - 3, bottom.dy - 24, 6, 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2)),
      Paint()..color = color,
    );
    for (var k = 0; k < 3; k++) {
      canvas.drawLine(
        Offset(body.left, body.top + 5 + k * 7),
        Offset(body.right, body.top + 8 + k * 7),
        Paint()
          ..color = Colors.white.withValues(alpha: .8)
          ..strokeWidth = 1.4,
      );
    }
    _flame(canvas, Offset(bottom.dx, body.top - 2), i);
  }

  /// Ngọn lửa lập lòe; đã thổi thì thành làn khói cuộn lên rồi tan.
  void _flame(Canvas canvas, Offset base, int i) {
    if (blown < 0) {
      final flicker = 1 + math.sin(seconds * 14 + i * 1.7) * .12;
      canvas.drawCircle(
        base + const Offset(0, -6),
        11,
        Paint()..color = const Color(0x33FFD970),
      );
      final flame = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          base.dx - 5,
          base.dy - 6 * flicker,
          base.dx,
          base.dy - 14 * flicker,
        )
        ..quadraticBezierTo(
          base.dx + 5,
          base.dy - 6 * flicker,
          base.dx,
          base.dy,
        )
        ..close();
      canvas.drawPath(flame, Paint()..color = const Color(0xFFFFB347));
      canvas.drawOval(
        Rect.fromCenter(
          center: base + const Offset(0, -4),
          width: 3.6,
          height: 6,
        ),
        Paint()..color = const Color(0xFFFFF3B0),
      );
      return;
    }
    final t = (blown / 1.6).clamp(0.0, 1.0);
    if (t >= 1) return;
    for (var k = 0; k < 3; k++) {
      final u = (t * 1.3 - k * .12).clamp(0.0, 1.0);
      if (u <= 0) continue;
      canvas.drawCircle(
        base + Offset(math.sin(u * 6 + i + k) * 5, -6 - u * 34 - k * 4),
        3 + u * 4,
        Paint()
          ..color = const Color(0xFFB9B2C4).withValues(alpha: .5 * (1 - u)),
      );
    }
  }

  void _drips(Canvas canvas, Rect band) {
    const pattern = [1.0, .45, .8, .35, .95, .55, .7];
    final count = math.max(3, (band.width / 18).round());
    final step = band.width / count;
    final base = band.top + band.height * .35;
    final path = Path()
      ..moveTo(band.left + 6, band.top)
      ..lineTo(band.right - 6, band.top)
      ..quadraticBezierTo(band.right, band.top, band.right, band.top + 6)
      ..lineTo(band.right, base);
    for (var i = count - 1; i >= 0; i--) {
      final mid = band.left + (i + .5) * step;
      final half = step * .26;
      final len = pattern[i % pattern.length] * (band.height - base + band.top);
      path
        ..lineTo(mid + half, base)
        ..lineTo(mid + half, base + len - half)
        ..cubicTo(
          mid + half,
          base + len + half * .6,
          mid - half,
          base + len + half * .6,
          mid - half,
          base + len - half,
        )
        ..lineTo(mid - half, base)
        ..lineTo(band.left + i * step, base);
    }
    path
      ..lineTo(band.left, band.top + 6)
      ..quadraticBezierTo(band.left, band.top, band.left + 6, band.top)
      ..close();
    canvas.save();
    canvas.translate(0, 1.6);
    canvas.drawPath(path, Paint()..color = _creamShade);
    canvas.restore();
    canvas.drawPath(path, Paint()..color = _cream);
  }

  @override
  bool shouldRepaint(_CakePainter oldDelegate) =>
      oldDelegate.age != age ||
      oldDelegate.seconds != seconds ||
      oldDelegate.blown != blown;
}
