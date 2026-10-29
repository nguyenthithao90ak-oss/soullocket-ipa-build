import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../utils/services/l10n_service.dart';
import '../../widgets/companion/home_companion_motion.dart';
import '../../widgets/companion/home_companion_painter.dart';
import 'pet_care_garden_camera.dart';
import 'pet_care_garden_map.dart';
import 'pet_care_progress.dart';
part 'pet_care_garden_3d_art.dart';
part 'pet_care_garden_render.dart';
part 'pet_care_garden_bsp.dart';
part 'pet_care_garden_forest.dart';

enum PetGardenActionPhase { preparing, contact, finishing }

class PetCareGarden3D extends StatefulWidget {
  const PetCareGarden3D({
    required this.camera,
    required this.progress,
    required this.frame,
    required this.pets,
    required this.heading,
    required this.now,
    required this.onPlot,
    required this.onWalk,
    required this.onHome,
    this.enabled = true,
    this.animate = true,
    this.wateringPlot,
    this.actionPlot,
    this.actionPhase,
    super.key,
  });
  final PetGardenCamera camera;
  final PetCareProgress progress;
  final ValueNotifier<double> frame;
  final List<HomeCompanionMotion> pets;
  final double Function(int) heading;
  final DateTime now;
  final ValueChanged<int> onPlot;
  final ValueChanged<Offset> onWalk;
  final VoidCallback onHome;
  final bool enabled, animate;
  final int? wateringPlot;
  final int? actionPlot;
  final PetGardenActionPhase? actionPhase;
  @override
  State<PetCareGarden3D> createState() => _PetCareGarden3DState();
}

class _PetCareGarden3DState extends State<PetCareGarden3D>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _stick = ValueNotifier<Offset>(Offset.zero);
  final _renderCache = _GardenRenderCache();
  late final _move = createTicker(_tick);
  late final _windowOpen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final _lampLight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final _sit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Duration? _last;
  bool _foreground = true, _tickerMode = true;
  bool _lamp = false, _window = false, _seated = false;
  double _lastScale = 1, _followAt = 0;
  bool get _active => widget.enabled && _foreground && _tickerMode;
  @override
  void initState() {
    super.initState();
    // Khởi tạo ticker khi State còn active, kể cả khi người dùng chưa chạm cần.
    _move;
    _windowOpen;
    _lampLight;
    _sit;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerMode = TickerMode.valuesOf(context).enabled;
    if (!_active) _stop();
    _objects();
  }

  @override
  void didUpdateWidget(PetCareGarden3D old) {
    super.didUpdateWidget(old);
    if (!_active || widget.camera.mode != PetGardenViewMode.firstPerson) {
      _stop();
    }
    _objects();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _stop();
    _objects();
  }

  void _objects() {
    for (final item in [
      (_windowOpen, _window),
      (_lampLight, _lamp),
      (_sit, _seated),
    ]) {
      final end = item.$2 ? 1.0 : 0.0;
      if (!_active || !widget.animate) {
        item.$1.value = end;
      } else if ((item.$1.value - end).abs() > .001 && !item.$1.isAnimating) {
        item.$1.animateTo(end, curve: Curves.easeInOutCubic);
      }
    }
  }

  void _stop() {
    _stick.value = Offset.zero;
    _move.stop();
    _last = null;
  }

  void _tick(Duration at) {
    final previous = _last;
    _last = at;
    if (previous == null || !_active) return;
    widget.camera.move(_stick.value, (at - previous).inMicroseconds / 1000000);
    _followAt += (at - previous).inMicroseconds / 1000000;
    if (_followAt > .7) {
      _followAt = 0;
      widget.onWalk(widget.camera.player.mapPoint);
    }
  }

  void _stickTo(Offset position) {
    if (!_active || widget.camera.mode != PetGardenViewMode.firstPerson) return;
    if (_seated) {
      setState(() => _seated = false);
      _sit.stop();
      _objects();
    }
    final delta = (position - const Offset(54, 54)) / 40;
    _stick.value = delta.distance > 1 ? delta / delta.distance : delta;
    if (!_move.isActive) {
      _last = null;
      _move.start();
    }
  }

  void _interact(String id) {
    if (!_active) return;
    if (id.startsWith('plot:')) {
      if (_seated) {
        setState(() => _seated = false);
        _sit.stop();
        _objects();
      }
      widget.onPlot(int.parse(id.substring(5)));
      return;
    }
    switch (id) {
      case 'door':
        widget.onHome();
      case 'window':
        setState(() => _window = !_window);
        _windowOpen.stop();
        _objects();
      case 'lamp':
        setState(() => _lamp = !_lamp);
        _lampLight.stop();
        _objects();
      case 'bench':
        widget.onWalk(const Offset(165, 465));
        setState(() => _seated = !_seated);
        _sit.stop();
        _objects();
    }
  }

  _GardenHit? _pick(Offset screen, Size size) {
    final camera = widget.camera;
    final direction = camera.ray(screen, size);
    _GardenHit? nearest;
    var distance = double.infinity;
    for (final hit in _gardenHits()) {
      final t = hit.intersection(camera.eye, direction);
      if (t != null && t < distance) {
        nearest = hit;
        distance = t;
      }
    }
    return nearest;
  }

  _GardenHit? _hitNearScreen(Offset screen, Size size) {
    _GardenHit? nearest;
    // Tâm semantics có thể lệch vài chục pixel so với tâm khối khi camera
    // hạ thấp; vùng ưu tiên rộng hơn giữ chạm ổn định ở góc cận cảnh.
    var best = 64.0;
    for (final hit in _gardenHits()) {
      if (hit.id == 'wall') continue;
      final projected = widget.camera.project(hit.center, size);
      if (projected == null) continue;
      final distance = (projected.$1 - screen).distance;
      if (distance < best) {
        best = distance;
        nearest = hit;
      }
    }
    return nearest;
  }

  void _touch(Offset screen, Size size) {
    if (!_active) return;
    final camera = widget.camera;
    // Ưu tiên tâm điểm tương tác đã vẽ trên HUD semantics. Điều này giữ
    // thao tác ổn định khi hiên, ghế và cửa nằm sát nhau ở góc nhìn gần.
    final nearest = _hitNearScreen(screen, size) ?? _pick(screen, size);
    if (nearest != null) {
      if (nearest.id == 'wall') return;
      final distance = nearest.intersection(
        camera.eye,
        camera.ray(screen, size),
      )!;
      if (camera.mode == PetGardenViewMode.firstPerson && distance > 2.8) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(context.tr('pet_garden_come_closer')),
          ),
        );
        return;
      }
      _interact(nearest.id);
      return;
    }
    final floor = camera.ground(screen, size);
    if (floor != null) {
      if (_seated) {
        setState(() => _seated = false);
        _sit.stop();
        _objects();
      }
      widget.onWalk(floor.mapPoint);
    }
  }

  // Semantics của một vật phải tác động đúng vật đó. Khi camera tiến gần,
  // tâm hộp của ghế/cửa sổ có thể nằm chồng lên một mặt khác; ray-pick lại
  // từ tâm màn hình sẽ khiến thao tác đọc màn hình bị rơi sang vật kế bên.
  void _semanticInteract(_GardenHit hit, Size size) {
    if (!_active) return;
    final distance = hit.intersection(
      widget.camera.eye,
      widget.camera.ray(
        widget.camera.project(hit.center, size)?.$1 ?? Offset.zero,
        size,
      ),
    );
    if (distance == null) return;
    if (widget.camera.mode == PetGardenViewMode.firstPerson && distance > 2.8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(context.tr('pet_garden_come_closer')),
        ),
      );
      return;
    }
    _interact(hit.id);
  }

  @override
  void dispose() {
    _move.dispose();
    _windowOpen.dispose();
    _lampLight.dispose();
    _sit.dispose();
    _stick.dispose();
    _renderCache.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final camera = widget.camera;
      camera.setViewport(size);
      final scene = RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('pet-garden-world-paint'),
          painter: _GardenWorldPainter(
            cache: _renderCache,
            camera: camera,
            progress: widget.progress,
            now: widget.now,
            frame: widget.frame,
            pets: widget.pets,
            heading: widget.heading,
            lamp: _lampLight,
            window: _windowOpen,
            sit: _sit,
            seated: _seated,
            animate: widget.animate,
            wateringPlot: widget.wateringPlot,
            actionPlot: widget.actionPlot,
            actionPhase: widget.actionPhase,
          ),
        ),
      );
      return ClipRect(
        child: AnimatedBuilder(
          animation: camera,
          child: scene,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  key: const ValueKey('pet-garden-world'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _touch(details.localPosition, size),
                  onLongPressStart: (details) =>
                      _touch(details.localPosition, size),
                  onScaleStart: (_) {
                    _lastScale = 1;
                  },
                  onScaleUpdate: (details) {
                    if (!_active) return;
                    camera.drag(details.focalPointDelta);
                    if (details.pointerCount > 1) {
                      camera.zoom(details.scale / _lastScale);
                      _lastScale = details.scale;
                    }
                  },
                  child: child,
                ),
                // Semantics nằm theo đúng phép chiếu; chạm thông thường vẫn ray-pick
                // vật gần nhất, tránh bấm xuyên tường và mái nhà.
                for (final hit in _gardenHits())
                  if (hit.id != 'wall')
                    if (camera.project(hit.center, size) case final p?)
                      Positioned(
                        left: p.$1.dx - 24,
                        top: p.$1.dy - 24,
                        width: 48,
                        height: 48,
                        child: Semantics(
                          key: ValueKey('pet-garden-world-object-${hit.id}'),
                          button: true,
                          label: hit.id.startsWith('plot:')
                              ? L10nScope.of(
                                  context,
                                ).format('pet_garden_plot', {
                                  'n': '${int.parse(hit.id.substring(5)) + 1}',
                                })
                              : context.tr('pet_garden_object_${hit.id}'),
                          onTap: _active
                              ? () => _semanticInteract(hit, size)
                              : null,
                          child: const IgnorePointer(child: SizedBox.expand()),
                        ),
                      ),
                if (camera.mode == PetGardenViewMode.firstPerson) ...[
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .8),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Color(0x553A5145), blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 16,
                    bottom: 16,
                    child: Semantics(
                      label: context.tr('pet_garden_joystick'),
                      child: GestureDetector(
                        key: const ValueKey('pet-garden-joystick'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _stickTo(d.localPosition),
                        onPanUpdate: (d) => _stickTo(d.localPosition),
                        onPanEnd: (_) => _stop(),
                        onPanCancel: _stop,
                        child: ValueListenableBuilder<Offset>(
                          valueListenable: _stick,
                          builder: (context, value, _) => Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              color: const Color(0x99FAF7E5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0x66FFFFFF),
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A314D3A),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.open_with_rounded,
                                  color: Color(0x55425C45),
                                  size: 74,
                                ),
                                Transform.translate(
                                  offset: value * 32,
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF758F6B),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x443D5B40),
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    },
  );
}

class _GardenHit {
  const _GardenHit(this.id, this.min, this.max);
  final String id;
  final GardenVec3 min, max;
  GardenVec3 get center => (min + max) * .5;
  double? intersection(GardenVec3 origin, GardenVec3 direction) {
    var lo = 0.0, hi = double.infinity;
    for (final axis in [
      (origin.x, direction.x, min.x, max.x),
      (origin.y, direction.y, min.y, max.y),
      (origin.z, direction.z, min.z, max.z),
    ]) {
      if (axis.$2.abs() < .00001) {
        if (axis.$1 < axis.$3 || axis.$1 > axis.$4) return null;
        continue;
      }
      final a = (axis.$3 - axis.$1) / axis.$2,
          b = (axis.$4 - axis.$1) / axis.$2;
      lo = math.max(lo, math.min(a, b));
      hi = math.min(hi, math.max(a, b));
      if (hi < lo) return null;
    }
    return hi > 0 ? lo : null;
  }
}

List<_GardenHit> _gardenHits() => [
  const _GardenHit(
    'wall',
    GardenVec3(-3.6, 0, -4.4),
    GardenVec3(1.4, 2.6, -1.1),
  ),
  const _GardenHit(
    'wall',
    GardenVec3(-3.8, 2.6, -4.6),
    GardenVec3(1.6, 3.95, -.9),
  ),
  const _GardenHit(
    'door',
    GardenVec3(-1.82, 0, -1.08),
    GardenVec3(-.7, 2.1, -.91),
  ),
  const _GardenHit(
    'window',
    GardenVec3(-3.13, 1, -1.09),
    GardenVec3(-2.15, 1.9, -.94),
  ),
  const _GardenHit(
    'lamp',
    GardenVec3(-4.4, 0, -.75),
    GardenVec3(-3.8, 2.1, -.15),
  ),
  const _GardenHit(
    'bench',
    GardenVec3(-3.9, 0, -.9),
    GardenVec3(-2.5, .85, -.42),
  ),
  for (var i = 0; i < PetGardenMap.plots.length; i++)
    _GardenHit(
      'plot:$i',
      GardenVec3.fromMap(PetGardenMap.plots[i]) +
          GardenVec3(i < 6 ? -.8 : -.5, 0, i < 6 ? -.5 : -.4),
      GardenVec3.fromMap(PetGardenMap.plots[i]) +
          GardenVec3(i < 6 ? .8 : .5, i < 6 ? .8 : 2, i < 6 ? .5 : .4),
    ),
];
