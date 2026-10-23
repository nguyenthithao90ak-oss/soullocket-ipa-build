import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../widgets/companion/home_companion_motion.dart';
import '../../widgets/companion/home_companion_painter.dart';
import 'pet_care_progress.dart';

/// Vật rơi trong trò hứng sao. Mây giông làm bé choáng và trừ điểm.
enum PetCatchKind {
  star(1),
  heart(2),
  seed(3),
  storm(-2);

  const PetCatchKind(this.points);
  final int points;
}

class PetCatchItem {
  PetCatchItem(this.kind, this.x, this.speed, this.spin);
  final PetCatchKind kind;
  final double x;
  final double speed;
  final double spin;
  double y = -.08;
}

/// Một lần hứng trúng, dùng để vẽ lóe sáng và phát âm.
class PetCatchHit {
  const PetCatchHit(this.kind, this.x, this.y);
  final PetCatchKind kind;
  final double x;
  final double y;
}

/// Luật chơi thuần Dart (tọa độ 0…1) để kiểm thử không cần vẽ.
class PetCatchGameEngine {
  PetCatchGameEngine({math.Random? random, this.duration = 30})
    : _random = random ?? math.Random();

  final math.Random _random;
  final double duration;
  final List<PetCatchItem> items = [];
  double elapsed = 0;
  double petX = .5;
  double stunned = 0;
  int score = 0;
  int caught = 0;
  double _spawnIn = .5;

  static const catchTop = .74;
  static const catchBottom = .9;
  static const reach = .12;

  bool get finished => elapsed >= duration;
  double get remaining => (duration - elapsed).clamp(0, duration);
  double get _pace => (elapsed / duration).clamp(0.0, 1.0);

  void moveTo(double x) {
    if (stunned > 0 || finished) return;
    petX = x.clamp(.1, .9);
  }

  /// Tiến [dt] giây; trả về các món vừa hứng được trong bước này.
  List<PetCatchHit> step(double dt) {
    if (finished) return const [];
    elapsed = math.min(duration, elapsed + dt);
    if (stunned > 0) stunned = math.max(0, stunned - dt);
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawn();
      _spawnIn = .78 - .38 * _pace + _random.nextDouble() * .18;
    }
    final hits = <PetCatchHit>[];
    for (final item in items) {
      item.y += item.speed * dt;
      if (item.y >= catchTop &&
          item.y <= catchBottom &&
          (item.x - petX).abs() < reach) {
        hits.add(PetCatchHit(item.kind, item.x, item.y));
        score = math.max(0, score + item.kind.points);
        if (item.kind == PetCatchKind.storm) {
          stunned = .7;
        } else {
          caught++;
        }
        item.y = 2;
      }
    }
    items.removeWhere((item) => item.y > 1.05);
    return hits;
  }

  void _spawn() {
    final roll = _random.nextDouble();
    final kind = roll < .12 + _pace * .1
        ? PetCatchKind.storm
        : roll < .6
        ? PetCatchKind.star
        : roll < .86
        ? PetCatchKind.heart
        : PetCatchKind.seed;
    items.add(
      PetCatchItem(
        kind,
        .1 + _random.nextDouble() * .8,
        .3 + _pace * .26 + _random.nextDouble() * .12,
        _random.nextDouble() * math.pi * 2,
      ),
    );
  }
}

/// Mini game "Hứng sao": kéo bé qua lại để hứng sao, tim, hạt; tránh mây giông.
class PetCareCatchGame extends StatefulWidget {
  const PetCareCatchGame({
    required this.pet,
    required this.seedsLeft,
    required this.canStart,
    required this.onFinish,
    required this.onClose,
    required this.labels,
    this.onHit,
    this.onDouble,
    this.onRevive,
    this.random,
    super.key,
  });

  final PetCarePet pet;

  /// Hạt còn nhận được hôm nay từ trò này.
  final int seedsLeft;

  /// Bé còn đủ năng lượng để chơi thêm ván.
  final bool canStart;
  final ValueChanged<int> onFinish;
  final VoidCallback onClose;
  final PetCatchLabels labels;
  final ValueChanged<PetCatchKind>? onHit;

  /// Xem quảng cáo nhân đôi Hạt vừa nhận; null khi hết lượt hôm nay.
  /// Trả về true khi đã cộng thêm Hạt.
  final Future<bool> Function(int earned)? onDouble;

  /// Xem quảng cáo cho bé hết mệt; null khi bé không cần hoặc hết lượt.
  final Future<bool> Function()? onRevive;
  final math.Random? random;

  @override
  State<PetCareCatchGame> createState() => _PetCareCatchGameState();
}

/// Chữ đã dịch truyền từ màn cha (game không tự tra khóa dịch).
class PetCatchLabels {
  const PetCatchLabels({
    required this.hint,
    required this.start,
    required this.done,
    required this.again,
    required this.close,
    required this.score,
    required this.seeds,
    required this.tired,
    required this.doubleSeeds,
    required this.revive,
  });
  final String hint;
  final String start;
  final String done;
  final String again;
  final String close;
  final String score;
  final String seeds;
  final String tired;
  final String doubleSeeds;
  final String revive;
}

class _PetCareCatchGameState extends State<PetCareCatchGame>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late PetCatchGameEngine _engine = PetCatchGameEngine(random: widget.random);
  late final Ticker _ticker = createTicker(_onTick);
  final _motion = _CatchMotion();
  final List<(PetCatchHit, double)> _flashes = [];
  Duration _last = Duration.zero;
  bool _running = false;
  bool _ended = false;
  bool _foreground = true;
  bool _doubled = false;
  bool _adBusy = false;
  double _seconds = 0;
  double _lastX = .5;

  /// Trần hạt lúc bắt đầu ván, để bảng kết quả không đổi khi màn cha lưu.
  late int _seedCap = widget.seedsLeft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion.setPinnedPosition(
      const Offset(180, 260),
      const Rect.fromLTWH(0, 0, 360, 300),
    );
    _ticker.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, .1);
    _last = elapsed;
    if (!_foreground || !TickerMode.valuesOf(context).enabled) return;
    _seconds += dt;
    // Bé quay mặt theo hướng đang chạy, đứng yên thì thở bình thường.
    final moved = _engine.petX - _lastX;
    _motion.walking = moved.abs() > .002;
    if (_motion.walking) _motion.right = moved > 0;
    _lastX = _engine.petX;
    if (_running) {
      final hits = _engine.step(dt);
      for (final hit in hits) {
        _flashes.add((hit, _seconds));
        widget.onHit?.call(hit.kind);
      }
      if (_engine.finished && !_ended) {
        _ended = true;
        _running = false;
        widget.onFinish(_engine.score);
      }
    }
    _flashes.removeWhere((flash) => _seconds - flash.$2 > .6);
    setState(() {});
  }

  void _start() {
    if (!widget.canStart) return;
    setState(() {
      _engine = PetCatchGameEngine(random: widget.random);
      _seedCap = widget.seedsLeft;
      _flashes.clear();
      _ended = false;
      _doubled = false;
      _running = true;
    });
  }

  /// Chờ quảng cáo ở màn cha; khóa nút trong lúc đó để không bấm hai lần.
  Future<void> _watch(
    Future<bool> Function() show, {
    bool doubling = false,
  }) async {
    if (_adBusy) return;
    setState(() => _adBusy = true);
    var ok = false;
    try {
      ok = await show();
    } finally {
      if (mounted) {
        setState(() {
          _adBusy = false;
          if (ok && doubling) _doubled = true;
        });
      }
    }
  }

  void _drag(Offset local, double width) {
    if (!_running || width <= 0) return;
    _engine.moveTo(local.dx / width);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final earned = math.min(
      _engine.score ~/ PetCareEarn.pointsPerSeed,
      _seedCap,
    );
    return Material(
      key: const ValueKey('pet-care-game'),
      color: dark ? const Color(0xFF2B2843) : const Color(0xFFCFEAF8),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  key: const ValueKey('pet-care-game-field'),
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (d) => _drag(d.localPosition, width),
                  onPanUpdate: (d) => _drag(d.localPosition, width),
                  child: Semantics(
                    label: widget.labels.hint,
                    child: CustomPaint(
                      painter: _CatchPainter(
                        engine: _engine,
                        pet: widget.pet,
                        motion: _motion,
                        seconds: _seconds,
                        dark: dark,
                        flashes: _flashes,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 8,
                  child: _hud(context, dark),
                ),
                if (!_running) _overlay(context, dark, earned),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _glass(Widget child, bool dark) => DecoratedBox(
    decoration: BoxDecoration(
      color: dark ? const Color(0xE64A4157) : const Color(0xEBFFFFFF),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22594049),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _hud(BuildContext context, bool dark) {
    final ink = dark ? const Color(0xFFF6E7E9) : const Color(0xFF614D50);
    final time = _engine.remaining.ceil();
    return Row(
      children: [
        _glass(
          IconButton(
            key: const ValueKey('pet-care-game-close'),
            tooltip: widget.labels.close,
            onPressed: widget.onClose,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: Icon(Icons.close_rounded, color: ink),
          ),
          dark,
        ),
        const Spacer(),
        Semantics(
          label: '${widget.labels.score} ${_engine.score}',
          excludeSemantics: true,
          child: _glass(
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF0B13E),
                    size: 26,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_engine.score}',
                    key: const ValueKey('pet-care-game-score'),
                    style: TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            dark,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox.square(
          dimension: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _engine.remaining / _engine.duration,
                strokeWidth: 5,
                color: time <= 5
                    ? const Color(0xFFE06C6C)
                    : const Color(0xFF7FB7E0),
                backgroundColor: dark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x88FFFFFF),
              ),
              Text(
                '$time',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overlay(BuildContext context, bool dark, int earned) {
    final ink = dark ? const Color(0xFFF6E7E9) : const Color(0xFF614D50);
    final panel = dark ? const Color(0xF23B3347) : const Color(0xF7FFFAED);
    // Cuộn được khi màn thấp hoặc chữ hệ thống lớn để nút luôn bấm tới.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            color: panel,
            borderRadius: BorderRadius.circular(28),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_ended) ...[
                    Text(
                      widget.labels.done,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        _stat(
                          Icons.star_rounded,
                          const Color(0xFFF0B13E),
                          '${_engine.score}',
                          widget.labels.score,
                          ink,
                        ),
                        _stat(
                          Icons.spa_rounded,
                          const Color(0xFFD9922F),
                          '+${_doubled ? earned * 2 : earned}',
                          widget.labels.seeds,
                          ink,
                        ),
                      ],
                    ),
                    if (widget.onDouble case final onDouble?
                        when earned > 0 && !_doubled) ...[
                      const SizedBox(height: 14),
                      _adButton(
                        key: 'pet-care-game-double',
                        icon: Icons.smart_display_rounded,
                        label: widget.labels.doubleSeeds,
                        onPressed: () =>
                            _watch(() => onDouble(earned), doubling: true),
                      ),
                    ],
                  ] else ...[
                    const _SwipeHint(),
                    const SizedBox(height: 10),
                    Text(
                      widget.labels.hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (!widget.canStart) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.labels.tired,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink.withValues(alpha: .75),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    if (widget.onRevive case final onRevive?) ...[
                      const SizedBox(height: 12),
                      _adButton(
                        key: 'pet-care-game-revive',
                        icon: Icons.bolt_rounded,
                        label: widget.labels.revive,
                        onPressed: () => _watch(onRevive),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_ended) ...[
                        OutlinedButton(
                          key: const ValueKey('pet-care-game-done'),
                          onPressed: widget.onClose,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(56, 52),
                            shape: const StadiumBorder(),
                            foregroundColor: ink,
                          ),
                          child: Tooltip(
                            message: widget.labels.close,
                            child: const Icon(Icons.check_rounded),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      FilledButton.icon(
                        key: const ValueKey('pet-care-game-start'),
                        onPressed: widget.canStart ? _start : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(120, 52),
                          shape: const StadiumBorder(),
                          backgroundColor: const Color(0xFFFFC765),
                          foregroundColor: const Color(0xFF7A4B1E),
                        ),
                        icon: Icon(
                          _ended
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          _ended ? widget.labels.again : widget.labels.start,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Nút xem quảng cáo có thưởng, chiếm cả hàng để chữ dài vẫn đọc đủ.
  Widget _adButton({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      key: ValueKey(key),
      onPressed: _adBusy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: const StadiumBorder(),
        backgroundColor: const Color(0xFFF08FAC),
        foregroundColor: Colors.white,
      ),
      icon: _adBusy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
  );

  Widget _stat(
    IconData icon,
    Color color,
    String value,
    String label,
    Color ink,
  ) => Semantics(
    label: '$label $value',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: ink,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

/// Bàn tay vẽ đơn giản lướt qua lại, gợi ý thao tác kéo.
class _SwipeHint extends StatefulWidget {
  const _SwipeHint();
  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    height: 54,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(
        children: [
          Positioned(
            left: 10,
            right: 10,
            top: 24,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x33856C7A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            left: 8 + Curves.easeInOutSine.transform(_controller.value) * 100,
            top: 6,
            child: const Icon(
              Icons.touch_app_rounded,
              size: 36,
              color: Color(0xFFB07FC4),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Chỉ cấp tư thế cho painter bé dùng chung trong trò chơi.
class _CatchMotion extends HomeCompanionMotion {
  _CatchMotion() : super(createsDust: false);
  bool walking = false;
  bool cheering = false;
  bool right = true;
  double strideCycles = 0;
  double seconds = 0;
  double cheer = 0;

  @override
  HomeCompanionPhase get phase => walking
      ? HomeCompanionPhase.walking
      : cheering
      ? HomeCompanionPhase.celebrating
      : HomeCompanionPhase.idle;
  @override
  bool get facingRight => right;
  @override
  double get stride => math.sin(strideCycles * math.pi * 2) * .25;
  @override
  double get elapsedSeconds => seconds;
  @override
  double get celebration => cheering ? cheer : 0;
}

class _CatchPainter extends CustomPainter {
  _CatchPainter({
    required this.engine,
    required this.pet,
    required this.motion,
    required this.seconds,
    required this.dark,
    required this.flashes,
  });

  final PetCatchGameEngine engine;
  final PetCarePet pet;
  final _CatchMotion motion;
  final double seconds;
  final bool dark;
  final List<(PetCatchHit, double)> flashes;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF26244A), Color(0xFF4B3F6B)]
              : const [Color(0xFFBFE3F7), Color(0xFFFDE9F1)],
        ).createShader(rect),
    );
    // Mây trôi chậm và đồi xa.
    for (var i = 0; i < 4; i++) {
      final x = ((seconds * (8 + i * 3) + i * 140) % (size.width + 160)) - 80;
      _cloud(
        canvas,
        Offset(x, 90 + i * 70.0),
        .5 + i % 2 * .2,
        Colors.white.withValues(alpha: dark ? .12 : .7),
      );
    }
    final ground = size.height * .9;
    canvas.drawOval(
      Rect.fromLTWH(-size.width * .2, ground - 50, size.width * .9, 120),
      Paint()..color = dark ? const Color(0xFF3F5A54) : const Color(0xFFBFE3C9),
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * .35, ground - 40, size.width, 120),
      Paint()..color = dark ? const Color(0xFF466355) : const Color(0xFFA9D8B4),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, ground, size.width, size.height - ground),
      Paint()..color = dark ? const Color(0xFF3E5A4A) : const Color(0xFF96CC8A),
    );
    final unit = math.min(size.width, size.height) / 360;
    for (final item in engine.items) {
      final p = Offset(item.x * size.width, item.y * size.height);
      _item(canvas, item.kind, p, unit * 1.3, item.spin + seconds * 2);
    }
    // Bé đứng trên cỏ, ôm giỏ trước bụng.
    final x = engine.petX * size.width;
    motion
      ..strideCycles = seconds * 2.4
      ..seconds = seconds
      ..cheering =
          flashes.isNotEmpty && flashes.last.$1.kind != PetCatchKind.storm
      ..cheer = flashes.isEmpty
          ? 0
          : ((seconds - flashes.last.$2) / .6).clamp(0.0, 1.0);
    final scale = unit * (pet == PetCarePet.rabbit ? 3.3 : 3.0);
    canvas.save();
    canvas.translate(x, ground + 6);
    if (engine.stunned > 0) {
      canvas.rotate(math.sin(seconds * 30) * .08);
    }
    canvas.scale(scale);
    canvas.translate(-180, -260);
    HomeCompanionPainter(
      motion: motion,
      darkMode: dark,
      character: pet == PetCarePet.rabbit
          ? HomeCompanionCharacter.bunny
          : HomeCompanionCharacter.bear,
      showEffects: true,
      care: const PetCareVitals(joy: 100, food: 80, clean: 90, energy: 90),
    ).paint(canvas, const Size(360, 300));
    canvas.restore();
    // Giỏ ôm ngang bụng, thấp hơn mặt bé.
    final basket = Offset(x, ground - 24 * unit);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: basket, width: 70 * unit, height: 24 * unit),
        Radius.circular(9 * unit),
      ),
      Paint()..color = const Color(0xFFD9A26A),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        basket + Offset(-28 * unit, (-6 + i * 6) * unit),
        basket + Offset(28 * unit, (-6 + i * 6) * unit),
        Paint()
          ..color = const Color(0xFFF1CB98)
          ..strokeWidth = 1.4 * unit,
      );
    }
    if (engine.stunned > 0) {
      for (var i = 0; i < 3; i++) {
        final a = seconds * 6 + i * math.pi * 2 / 3;
        _star(
          canvas,
          Offset(
            x + math.cos(a) * 24 * unit,
            ground - 150 * unit + math.sin(a) * 8 * unit,
          ),
          5 * unit,
          const Color(0xFFF2C66B),
        );
      }
    }
    for (final (hit, at) in flashes) {
      final u = ((seconds - at) / .6).clamp(0.0, 1.0);
      final p = Offset(hit.x * size.width, ground - 50 * unit);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        _star(
          canvas,
          p + Offset(math.cos(a), math.sin(a)) * (12 + u * 30) * unit,
          4 * unit * (1 - u),
          (hit.kind == PetCatchKind.storm
                  ? const Color(0xFF8A8FA8)
                  : const Color(0xFFFFD86B))
              .withValues(alpha: 1 - u),
        );
      }
    }
  }

  void _item(Canvas c, PetCatchKind kind, Offset p, double unit, double spin) {
    c.save();
    c.translate(p.dx, p.dy);
    switch (kind) {
      case PetCatchKind.star:
        c.rotate(spin * .3);
        _star(c, Offset.zero, 14 * unit, const Color(0xFFF7C35F));
        _star(c, Offset.zero, 7 * unit, const Color(0xFFFFE9A8));
      case PetCatchKind.heart:
        c.scale(unit);
        c.drawPath(
          Path()
            ..moveTo(0, 12)
            ..cubicTo(-26, -4, -9, -19, 0, -7)
            ..cubicTo(9, -19, 26, -4, 0, 12),
          Paint()..color = const Color(0xFFF08FAC),
        );
      case PetCatchKind.seed:
        c.drawCircle(
          Offset.zero,
          12 * unit,
          Paint()
            ..shader =
                const LinearGradient(
                  colors: [Color(0xFFF7C35F), Color(0xFFD9922F)],
                ).createShader(
                  Rect.fromCircle(center: Offset.zero, radius: 12 * unit),
                ),
        );
        for (final side in const [-1.0, 1.0]) {
          c.save();
          c.rotate(side * .55);
          c.drawOval(
            Rect.fromLTWH(-2.6 * unit, -9 * unit, 5.2 * unit, 10 * unit),
            Paint()..color = Colors.white,
          );
          c.restore();
        }
      case PetCatchKind.storm:
        _cloud(c, Offset.zero, .4 * unit, const Color(0xFF9AA0B8));
        c.drawPath(
          Path()
            ..moveTo(-2 * unit, 6 * unit)
            ..lineTo(-8 * unit, 18 * unit)
            ..lineTo(0, 16 * unit)
            ..lineTo(-4 * unit, 28 * unit)
            ..lineTo(8 * unit, 12 * unit)
            ..lineTo(1 * unit, 14 * unit)
            ..close(),
          Paint()..color = const Color(0xFFFFD45E),
        );
    }
    c.restore();
  }

  void _star(Canvas c, Offset p, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 - math.pi / 2;
      final size = i.isEven ? r : r * .47;
      final point = p + Offset(math.cos(a), math.sin(a)) * size;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  void _cloud(Canvas c, Offset p, double scale, Color color) {
    final paint = Paint()..color = color;
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    c.drawOval(const Rect.fromLTWH(-37, -6, 76, 30), paint);
    c.drawCircle(const Offset(-20, -2), 19, paint);
    c.drawCircle(const Offset(3, -12), 24, paint);
    c.drawCircle(const Offset(26, -1), 18, paint);
    c.restore();
  }

  @override
  bool shouldRepaint(_CatchPainter oldDelegate) => true;
}
