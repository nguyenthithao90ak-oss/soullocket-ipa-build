import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/sl_theme.dart';
import '../../../../utils/services/l10n_service.dart';
import '../../../ui_prefs.dart';
import '../../widgets/companion/home_companion_motion.dart';
import '../../widgets/companion/home_companion_painter.dart';
import 'pet_care_progress.dart';
import 'pet_care_garden_map.dart';
import 'pet_care_garden_camera.dart';
import 'pet_care_garden_3d.dart';
export 'pet_care_garden_map.dart';
export 'pet_care_garden_camera.dart';
part 'pet_care_garden_art.dart';
part 'pet_care_garden_hud.dart';

enum _GardenTool { walk, plant, water, harvest }

class _GardenAction {
  _GardenAction({required this.plot, required this.tool, required this.crop});
  final int plot;
  final _GardenTool tool;
  final PetGardenCrop crop;
  PetGardenActionPhase phase = PetGardenActionPhase.preparing;
}

/// Không gian ngoài trời; vị trí/camera chỉ ở trên máy, cây lưu theo Nhà.
class PetCareGardenView extends StatefulWidget {
  const PetCareGardenView({
    required this.progress,
    required this.onHome,
    required this.onChange,
    required this.now,
    this.enabled = true,
    super.key,
  });
  final PetCareProgress progress;
  final VoidCallback onHome;
  final Future<bool> Function(PetCareGarden Function(PetCareGarden)) onChange;
  final DateTime Function() now;
  final bool enabled;
  @override
  State<PetCareGardenView> createState() => _PetCareGardenViewState();
}

class _GardenPetMotion extends HomeCompanionMotion {
  _GardenPetMotion(this.feet) : super(createsDust: false);
  Offset feet;
  final path = Queue<Offset>();
  double seconds = 0, cycles = 0, yaw = .28, speed = 0;
  bool right = true;
  @override
  bool get hasSurfaces => true;
  @override
  Offset get position => feet;
  @override
  bool get facingRight => right;
  @override
  HomeCompanionPhase get phase =>
      path.isEmpty ? HomeCompanionPhase.idle : HomeCompanionPhase.walking;
  @override
  double get stride => cycles;
  @override
  double get visualStride => cycles;
  @override
  double get elapsedSeconds => seconds;
  void tick(double dt) {
    seconds += dt;
    while (path.isNotEmpty && (path.first - feet).distance < .8) {
      feet = path.removeFirst();
    }
    if (path.isEmpty) {
      speed = 0;
      return;
    }
    final delta = path.first - feet;
    final distance = delta.distance;
    var desired = path.length == 1
        ? math.min(175.0, math.sqrt(2 * 450 * distance))
        : 175.0;
    if (path.length > 1 && distance < 42) {
      final next = path.elementAt(1) - path.first;
      final cosine =
          (delta.dx * next.dx + delta.dy * next.dy) /
          (distance * next.distance);
      desired *= .45 + .55 * cosine.clamp(0.0, 1.0);
    }
    speed += (desired - speed).clamp(-650 * dt, 460 * dt);
    final step = math.min(distance, speed * dt);
    feet += delta / distance * step;
    cycles += step / 78;
    if (delta.dx.abs() > .1) right = delta.dx > 0;
    final target = math.atan2(delta.dx, delta.dy);
    final turn = math.atan2(math.sin(target - yaw), math.cos(target - yaw));
    yaw += turn * (1 - math.exp(-12 * dt));
    if (step >= distance) path.removeFirst();
  }
}

class _PetCareGardenViewState extends State<PetCareGardenView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _camera = TransformationController();
  final _worldCamera = PetGardenCamera();
  final _frame = ValueNotifier<double>(0);
  final _pets = [
    _GardenPetMotion(const Offset(340, 460)),
    _GardenPetMotion(const Offset(480, 460)),
  ];
  late final _ticker = createTicker(_tick);
  Timer? _clock;
  Duration? _last;
  bool _foreground = true, _tickerMode = true, _reduce = false, _busy = false;
  Size _view = Size.zero;
  double _fit = .4;
  int? _selected;
  _GardenTool _tool = _GardenTool.plant;
  PetGardenCrop _crop = PetGardenCrop.carrot;
  (int, _GardenTool, PetGardenCrop)? _queued;
  (int, _GardenTool, double)? _effect;
  _GardenAction? _action;
  var _actionToken = 0;
  bool _saveError = false, _seedTrayOpen = false;
  static int _orientationRevision = 0;
  void _refresh(VoidCallback action) => setState(action);

  void _orientation(bool garden) {
    // Desktop vẫn gửi lệnh để widget test và desktop preview có cùng vòng đời
    // với Android/iOS; hệ điều hành không hỗ trợ sẽ tự bỏ qua lệnh này. Web
    // không có API orientation native nên giữ nguyên bố cục responsive.
    if (kIsWeb) {
      return;
    }
    final revision = ++_orientationRevision;
    final orientations = garden
        ? [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
    // Gửi ngay theo thứ tự lifecycle. Method channel vốn đã xếp hàng lệnh;
    // không chờ một Future cũ để lần vào vườn hiện tại bị trễ xoay màn.
    unawaited(() async {
      try {
        await SystemChrome.setPreferredOrientations(orientations);
      } catch (error) {
        if (revision == _orientationRevision) {
          debugPrint('Không thể đổi hướng màn vườn: $error');
        }
      }
    }());
  }

  bool get _active => _foreground && _tickerMode && widget.enabled;
  bool get _animate => _active && !_reduce;
  DateTime get _now => widget.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _worldCamera.addListener(_cameraChanged);
    _orientation(true);
    UiPrefs.notifier.addListener(_preferences);
  }

  void _cameraChanged() {
    // PetCareGarden3D tự repaint theo từng pose. Chỉ dựng lại HUD khi camera
    // đã tới mode đích để nút điều khiển không nhấp nháy giữa lúc tween.
    if (mounted && !_worldCamera.isTransitioning) setState(() {});
  }

  void _preferences() {
    if (mounted) {
      setState(() {
        _readMotionPreference();
        _syncActivity();
      });
    }
  }

  void _readMotionPreference() {
    _reduce =
        MediaQuery.disableAnimationsOf(context) ||
        !UiPrefs.resolveEffectProfile(
          state: UiPrefs.notifier.value,
          isWeb: false,
        ).animationEnabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerMode = TickerMode.valuesOf(context).enabled;
    _readMotionPreference();
    _syncActivity();
  }

  @override
  void didUpdateWidget(PetCareGardenView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _queued = null;
      _actionToken++;
      _action = null;
      _busy = false;
      for (final pet in _pets) {
        pet.path.clear();
      }
    }
    _syncActivity();
    if (mounted) setState(() {});
  }

  void _syncActivity() {
    _last = null;
    if (_animate) {
      if (!_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
    if (_active && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _active) setState(() {});
      });
    } else if (!_active) {
      _clock?.cancel();
      _clock = null;
    }
    if ((!_active && !_busy) || _reduce) {
      _queued = null;
      for (final pet in _pets) {
        pet.path.clear();
      }
    }
    for (var i = 0; i < _pets.length; i++) {
      if (widget.progress.vitalsFor(PetCarePet.values[i]).sleeping) {
        _pets[i].path.clear();
      }
    }
  }

  void _tick(Duration elapsed) {
    final before = _last;
    _last = elapsed;
    if (before == null || !_animate) return;
    final dt = ((elapsed - before).inMicroseconds / 1000000).clamp(0.0, .05);
    _worldCamera.advanceTransition(dt.toDouble());
    for (var i = 0; i < _pets.length; i++) {
      if (!widget.progress.vitalsFor(PetCarePet.values[i]).sleeping) {
        _pets[i].tick(dt);
      }
    }
    _frame.value += dt;
    final queued = _queued;
    if (queued != null && _pets.every((p) => p.path.isEmpty)) {
      _queued = null;
      unawaited(_act(queued.$1, queued.$2, queued.$3));
    }
  }

  void _walk(Offset at) {
    if (!_active || _busy) return;
    _queued = null;
    for (var i = 0; i < _pets.length; i++) {
      final pet = _pets[i];
      pet.path.clear();
      if (widget.progress.vitalsFor(PetCarePet.values[i]).sleeping) continue;
      final route = PetGardenMap.smoothRoute(
        pet.feet,
        at + Offset(i * 130.0, 0),
      );
      if (_reduce && route.isNotEmpty) {
        pet.feet = route.last;
      } else {
        pet.path.addAll(route);
      }
    }
    _frame.value += .001;
  }

  void _plot(int plot) {
    if (!_active || _busy) return;
    final crop = plot >= 6
        ? PetGardenCrop.apple
        : (_crop.isTree ? PetGardenCrop.carrot : _crop);
    setState(() {
      _selected = plot;
      _crop = crop;
      _saveError = false;
    });
    _walk(PetGardenMap.plots[plot] + const Offset(0, 90));
    if (_tool == _GardenTool.walk) return;
    if (_reduce || _pets.every((p) => p.path.isEmpty)) {
      unawaited(_act(plot, _tool, crop));
    } else {
      _queued = (plot, _tool, crop);
    }
  }

  Future<void> _act(int plot, _GardenTool tool, PetGardenCrop crop) async {
    if (!_active || _busy) return;
    final now = _now;
    PetCareGarden change(PetCareGarden garden) => switch (tool) {
      _GardenTool.plant => garden.plant(plot, crop),
      _GardenTool.water => garden.water(plot, now),
      _GardenTool.harvest => garden.harvest(plot, now),
      _GardenTool.walk => garden,
    };
    final nextGarden = change(widget.progress.garden);
    if (identical(nextGarden, widget.progress.garden)) {
      return;
    }
    final token = ++_actionToken;
    setState(() {
      _busy = true;
      _saveError = false;
      if (!_reduce) {
        _action = _GardenAction(plot: plot, tool: tool, crop: crop);
      }
    });

    // Một hành động nhìn thấy được luôn có ba nhịp: chuẩn bị, chạm vào vật
    // và kết thúc. Chế độ giảm chuyển động vẫn lưu ngay để không làm chậm
    // thao tác trợ năng và giữ nguyên hành vi test/thiết bị yếu.
    if (!_reduce) {
      if (!await _waitAction(token, const Duration(milliseconds: 220))) return;
      if (!mounted || token != _actionToken) return;
      setState(() {
        _action?.phase = PetGardenActionPhase.contact;
      });
      if (!await _waitAction(
        token,
        tool == _GardenTool.water
            ? const Duration(milliseconds: 460)
            : const Duration(milliseconds: 300),
      )) {
        return;
      }
    }
    var saved = false;
    try {
      saved = await widget.onChange(change);
    } on Object {
      saved = false;
    }
    if (!mounted || token != _actionToken) return;
    setState(() {
      _busy = false;
      _saveError = !saved;
      if (saved) _effect = (plot, tool, _frame.value);
      if (!_reduce && _action != null) {
        _action!.phase = PetGardenActionPhase.finishing;
      }
    });
    if (!_reduce && await _waitAction(token, const Duration(milliseconds: 280))) {
      if (mounted && token == _actionToken) {
        setState(() => _action = null);
      }
    }
  }

  Future<bool> _waitAction(int token, Duration delay) async {
    await Future<void>.delayed(delay);
    if (!mounted || token != _actionToken) return false;
    if (!_active) {
      _actionToken++;
      setState(() {
        _action = null;
        _busy = false;
      });
      return false;
    }
    return true;
  }

  void _resetCamera() {
    if (_worldCamera.mode != PetGardenViewMode.map) {
      _worldCamera.reset();
      return;
    }
    if (_view.isEmpty) return;
    _camera.value = Matrix4.identity()
      ..translateByDouble(
        (_view.width - PetGardenMap.bounds.width * _fit) / 2,
        (_view.height - PetGardenMap.bounds.height * _fit) / 2,
        0,
        1,
      )
      ..scaleByDouble(_fit, _fit, _fit, 1);
  }

  void _zoom(double factor) {
    if (_worldCamera.mode != PetGardenViewMode.map) {
      _worldCamera.zoom(factor);
      return;
    }
    final old = _camera.value;
    final scale = old.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(_fit, _fit * 3);
    final center = Offset(_view.width / 2, _view.height / 2);
    final scene = _camera.toScene(center);
    _camera.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - scene.dx * next,
        center.dy - scene.dy * next,
        0,
        1,
      )
      ..scaleByDouble(next, next, next, 1);
  }

  void _basket() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('pet_garden_basket'),
                  style: SLTheme.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                for (final crop in PetGardenCrop.values)
                  ListTile(
                    leading: SizedBox.square(
                      dimension: 36,
                      child: CustomPaint(painter: _GardenSeedIcon(crop)),
                    ),
                    title: Text(_cropName(crop)),
                    trailing: Text(
                      '${widget.progress.garden.inventory[crop] ?? 0}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _orientation(false);
    _queued = null;
    _clock?.cancel();
    _ticker.dispose();
    _camera.dispose();
    _worldCamera.removeListener(_cameraChanged);
    _worldCamera.dispose();
    _frame.dispose();
    for (final pet in _pets) {
      pet.dispose();
    }
    UiPrefs.notifier.removeListener(_preferences);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _cropName(PetGardenCrop crop) =>
      context.tr('pet_garden_crop_${crop.name}');
  String _status() {
    if (_saveError) return context.tr('pet_care_save_error');
    if (_selected == null) {
      return context.tr(
        _worldCamera.mode == PetGardenViewMode.firstPerson
            ? 'pet_garden_first_hint'
            : _worldCamera.mode == PetGardenViewMode.orbit
            ? 'pet_garden_direct_hint'
            : 'pet_garden_hint',
      );
    }
    final plant = widget.progress.garden.plots[_selected];
    if (plant == null) {
      return context.tr(
        _selected! >= 6 ? 'pet_garden_orchard' : 'pet_garden_empty',
      );
    }
    if (plant.wateredAt == null) {
      return '${_cropName(plant.crop)} · ${context.tr('pet_garden_thirsty')}';
    }
    if (plant.ready(_now)) {
      return '${_cropName(plant.crop)} · ${context.tr('pet_garden_ready')}';
    }
    final seconds = plant.remaining(_now);
    final remaining =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return L10nScope.of(context).format('pet_garden_growing', {
      'crop': _cropName(plant.crop),
      'time': remaining,
    });
  }

  Widget _mapButton(
    String key,
    IconData icon,
    String label,
    VoidCallback action,
  ) => IconButton.filledTonal(
    key: ValueKey(key),
    onPressed: action,
    tooltip: context.tr(label),
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: const Color(0xFFFDF9EA),
      foregroundColor: const Color(0xFF385A4B),
    ),
    icon: Icon(icon, size: 22),
  );

  Widget _tools(Color ink, bool dark) => LayoutBuilder(
    builder: (context, constraints) {
      final scaled = MediaQuery.textScalerOf(context).scale(11);
      final large = scaled > 15.4 || constraints.maxWidth < 336;
      final height = large ? math.max(70.0, 24 + scaled * 2.9) : 82.0;
      Widget button(_GardenTool tool) {
        final icon = [
          Icons.directions_walk_rounded,
          Icons.spa_rounded,
          Icons.water_drop_rounded,
          Icons.shopping_basket_rounded,
        ][tool.index];
        final text = Text(
          context.tr('pet_garden_tool_${tool.name}'),
          textAlign: large ? TextAlign.start : TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(fontSize: 11, fontWeight: FontWeight.w800),
        );
        return Semantics(
          selected: _tool == tool,
          child: TextButton(
            key: ValueKey('pet-garden-tool-${tool.name}'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _tool = tool;
                    _queued = null;
                  }),
            style: TextButton.styleFrom(
              backgroundColor: _tool == tool
                  ? const Color(0xFFDDEBC6)
                  : (dark ? const Color(0xFF354C40) : const Color(0xFFF0EDDF)),
              foregroundColor: _tool == tool ? const Color(0xFF355648) : ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            child: large
                ? Row(
                    children: [
                      Icon(icon, size: 24),
                      const SizedBox(width: 8),
                      Expanded(child: text),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 24),
                      const SizedBox(height: 3),
                      text,
                    ],
                  ),
          ),
        );
      }

      if (large) {
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final tool in _GardenTool.values)
              SizedBox(
                width: (constraints.maxWidth - 8) / 2,
                height: height,
                child: button(tool),
              ),
          ],
        );
      }
      return SizedBox(
        height: height,
        child: Row(
          children: [
            for (final tool in _GardenTool.values) ...[
              if (tool.index > 0) const SizedBox(width: 6),
              Expanded(
                child: SizedBox(height: height, child: button(tool)),
              ),
            ],
          ],
        ),
      );
    },
  );

  void _mode(PetGardenViewMode value) {
    _queued = null;
    for (final pet in _pets) {
      pet.path.clear();
    }
    setState(() {
      final canTween =
          _worldCamera.mode != PetGardenViewMode.map &&
          value != PetGardenViewMode.map &&
          _animate;
      if (canTween) {
        _worldCamera.transitionTo(
          value,
          duration: const Duration(milliseconds: 440),
        );
      } else {
        _worldCamera.setMode(value);
      }
      if (value == PetGardenViewMode.map) _resetCamera();
    });
    // Khi chuyển từ canvas 3D sang InteractiveViewer, widget bản đồ được
    // tạo sau setState. Đặt lại thêm một nhịp để controller không bị state mới
    // ghi đè thành ma trận identity.
    if (value == PetGardenViewMode.map) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _worldCamera.mode == PetGardenViewMode.map) {
          _resetCamera();
        }
      });
    }
  }

  void _directPlot(int id) {
    final plant = widget.progress.garden.plots[id];
    _tool = plant == null
        ? _GardenTool.plant
        : plant.wateredAt == null
        ? _GardenTool.water
        : plant.ready(_now)
        ? _GardenTool.harvest
        : _GardenTool.walk;
    _plot(id);
  }

  Widget _viewModes(Color ink) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
    child: Row(
      children: [
        for (final mode in PetGardenViewMode.values) ...[
          if (mode.index > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              selected: _worldCamera.mode == mode,
              child: OutlinedButton(
                key: ValueKey('pet-garden-view-${mode.name}'),
                onPressed: () => _mode(mode),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 6,
                  ),
                  foregroundColor: ink,
                  backgroundColor: _worldCamera.mode == mode
                      ? const Color(0x447A9D67)
                      : Colors.transparent,
                  side: BorderSide(color: ink.withValues(alpha: .2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      [
                        Icons.threed_rotation_rounded,
                        Icons.visibility_rounded,
                        Icons.map_outlined,
                      ][mode.index],
                      size: 20,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('pet_garden_view_${mode.name}'),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _gardenScene(bool dark) => LayoutBuilder(
    builder: (context, constraints) {
      if (_view != constraints.biggest) {
        _view = constraints.biggest;
        _fit = _view.width > _view.height
            ? math.max(
                _view.width / PetGardenMap.bounds.width,
                _view.height / PetGardenMap.bounds.height,
              )
            : math.min(
                _view.width / PetGardenMap.bounds.width,
                _view.height / PetGardenMap.bounds.height,
              );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _resetCamera();
        });
      }
      return Stack(
        children: [
          if (_worldCamera.mode != PetGardenViewMode.map)
            Positioned.fill(
              child: PetCareGarden3D(
                key: const ValueKey('pet-garden-world-view'),
                camera: _worldCamera,
                progress: widget.progress,
                frame: _frame,
                pets: _pets,
                heading: (i) => _pets[i].yaw,
                now: _now,
                onPlot: _directPlot,
                onWalk: _walk,
                onHome: widget.onHome,
                enabled: _active && !_busy,
                animate: _animate,
                wateringPlot:
                    _action?.tool == _GardenTool.water
                        ? _action!.plot
                        : _effect != null &&
                              _effect!.$2 == _GardenTool.water &&
                              _frame.value - _effect!.$3 < 1.6
                        ? _effect!.$1
                        : null,
                actionPlot: _action?.plot,
                actionPhase: _action?.phase,
              ),
            )
          else
            Positioned.fill(
              child: InteractiveViewer(
                key: const ValueKey('pet-garden-map'),
                transformationController: _camera,
                constrained: false,
                alignment: Alignment.topLeft,
                minScale: _fit,
                maxScale: _fit * 3,
                boundaryMargin: const EdgeInsets.all(90),
                panEnabled: _active,
                scaleEnabled: _active,
                child: GestureDetector(
                  key: const ValueKey('pet-garden-ground'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _walk(
                    details.localPosition + PetGardenMap.bounds.topLeft,
                  ),
                  child: SizedBox(
                    width: PetGardenMap.bounds.width,
                    height: PetGardenMap.bounds.height,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: _GardenMapSurroundings()),
                        ),
                        Positioned(
                          left: -PetGardenMap.bounds.left,
                          top: -PetGardenMap.bounds.top,
                          width: PetGardenMap.size.width,
                          height: PetGardenMap.size.height,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _GardenLandscape(dark: dark),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _GardenPlants(
                                      garden: widget.progress.garden,
                                      now: _now,
                                      selected: _selected,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      key: const ValueKey('pet-garden-actors'),
                                      painter: _GardenActors(
                                        motions: _pets,
                                        frame: _frame,
                                        progress: widget.progress,
                                        dark: dark,
                                        animate: _animate,
                                        effect: _effect,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              for (
                                var i = 0;
                                i < PetGardenMap.plots.length;
                                i++
                              )
                                Positioned.fromRect(
                                  rect: Rect.fromCenter(
                                    center:
                                        PetGardenMap.plots[i] -
                                        const Offset(0, 15),
                                    width: 160,
                                    height: 150,
                                  ),
                                  child: Semantics(
                                    button: true,
                                    label:
                                        '${L10nScope.of(context).format("pet_garden_plot", {"n": "${i + 1}"})}. '
                                        '${widget.progress.garden.plots[i] == null ? context.tr("pet_garden_empty") : _cropName(widget.progress.garden.plots[i]!.crop)}',
                                    child: GestureDetector(
                                      key: ValueKey('pet-garden-plot-$i'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _plot(i),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 267,
                                top: 285,
                                width: 160,
                                height: 155,
                                child: Semantics(
                                  button: true,
                                  label: context.tr('pet_garden_home'),
                                  child: GestureDetector(
                                    key: const ValueKey(
                                      'pet-garden-house-door',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: widget.onHome,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_worldCamera.mode != PetGardenViewMode.firstPerson)
            PositionedDirectional(
              top:
                  MediaQuery.sizeOf(context).width >
                      MediaQuery.sizeOf(context).height
                  ? 76
                  : 10,
              end:
                  MediaQuery.sizeOf(context).width >
                      MediaQuery.sizeOf(context).height
                  ? null
                  : 10,
              start:
                  MediaQuery.sizeOf(context).width >
                      MediaQuery.sizeOf(context).height
                  ? 10
                  : null,
              child: Flex(
                direction:
                    MediaQuery.sizeOf(context).width >
                        MediaQuery.sizeOf(context).height
                    ? Axis.horizontal
                    : Axis.vertical,
                children: [
                  _mapButton(
                    'pet-garden-zoom-in',
                    Icons.add_rounded,
                    'pet_garden_zoom_in',
                    () => _zoom(1.35),
                  ),
                  const SizedBox(height: 6),
                  _mapButton(
                    'pet-garden-zoom-out',
                    Icons.remove_rounded,
                    'pet_garden_zoom_out',
                    () => _zoom(1 / 1.35),
                  ),
                  const SizedBox(height: 6),
                  _mapButton(
                    'pet-garden-camera-reset',
                    Icons.crop_free_rounded,
                    'pet_garden_camera',
                    _resetCamera,
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF253E37) : const Color(0xFFFBF7EA);
    final ink = dark ? const Color(0xFFE7F1DB) : const Color(0xFF355648);
    if (MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height) {
      return _wideGarden(ink, paper, dark);
    }
    return ColoredBox(
      color: paper,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 12, 4),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('pet-garden-home'),
                  onPressed: widget.onHome,
                  tooltip: context.tr('pet_garden_home'),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: Icon(Icons.arrow_back_rounded, color: ink),
                ),
                Expanded(
                  child: Text(
                    context.tr('pet_garden_title'),
                    style: SLTheme.quicksand(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('pet-garden-basket'),
                  onPressed: _basket,
                  style: TextButton.styleFrom(
                    foregroundColor: ink,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Semantics(
                    label: context.tr('pet_garden_basket'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_basket_rounded, size: 24),
                        const SizedBox(width: 5),
                        Text(
                          '${widget.progress.garden.totalHarvest}',
                          key: const ValueKey('pet-garden-stock'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _viewModes(ink),
          Expanded(child: _gardenScene(dark)),
          DecoratedBox(
            decoration: BoxDecoration(
              color: paper,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18364E39),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        if (_busy)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(end: 8),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            _status(),
                            key: const ValueKey('pet-garden-status'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_tool == _GardenTool.plant ||
                      (_worldCamera.mode != PetGardenViewMode.map &&
                          _selected == null)) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height:
                          MediaQuery.textScalerOf(context).scale(12) * 2 + 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: PetGardenCrop.values.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          final crop = PetGardenCrop.values[i];
                          return ChoiceChip(
                            key: ValueKey('pet-garden-seed-${crop.name}'),
                            selected: _crop == crop,
                            avatar: SizedBox.square(
                              dimension: 24,
                              child: CustomPaint(
                                painter: _GardenSeedIcon(crop),
                              ),
                            ),
                            label: Text(_cropName(crop)),
                            onSelected: _busy
                                ? null
                                : (_) => setState(() {
                                    _crop = crop;
                                    _queued = null;
                                  }),
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            labelStyle: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _crop == crop
                                  ? const Color(0xFF355648)
                                  : ink,
                            ),
                            backgroundColor: dark
                                ? const Color(0xFF354C40)
                                : const Color(0xFFFFFDF7),
                            selectedColor: const Color(0xFFDDEBC6),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (_worldCamera.mode == PetGardenViewMode.map)
                    _tools(ink, dark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
