import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/home_couple_decor_sync_service.dart';
import 'package:soullocket_app/widgets/couple_default_avatar.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';

import 'home_couple_decor_art.dart';
import 'home_couple_decor_model.dart';
import 'home_couple_profile_card.dart';

class HomeCoupleDecorEditorScreen extends StatefulWidget {
  const HomeCoupleDecorEditorScreen({
    super.key,
    required this.scope,
    required this.initialDecor,
    this.saveShared,
    this.initialRevision = 0,
    this.isVip = false,
    this.previewLeft,
    this.previewCenter,
    this.previewRight,
    this.isScopeCurrent,
    this.onSaved,
  });

  final String scope;
  final HomeCoupleCardDecor initialDecor;
  final HomeCoupleDecorSave? saveShared;
  final int initialRevision;
  final bool isVip;
  final Widget? previewLeft;
  final Widget? previewCenter;
  final Widget? previewRight;
  final bool Function()? isScopeCurrent;
  final ValueChanged<HomeCoupleCardDecor>? onSaved;

  @override
  State<HomeCoupleDecorEditorScreen> createState() =>
      _HomeCoupleDecorEditorScreenState();
}

class _HomeCoupleDecorEditorScreenState
    extends State<HomeCoupleDecorEditorScreen> {
  late HomeCoupleCardDecor _draft = _normalizedInitialDecor();
  late final TextEditingController _messageController = TextEditingController(
    text: _draft.message,
  );
  String _pack = 'cute';
  int _section = 2;
  int? _selected;
  String _drawColorKey = 'rose';
  double _drawWidth = .014;
  final _activeDrawing = ValueNotifier<HomeCoupleDrawingStroke?>(null);
  bool _saving = false;
  late HomeCoupleCardDecor _base = _normalizedInitialDecor();
  late int _revision = widget.initialRevision;
  HomeCoupleDecorSnapshot? _conflict;
  HomeCoupleCardDecor? _requestedDesign;
  String? _requestId;
  int _retryBlockedUntilMs = 0;

  HomeCoupleCardDecor _normalizedInitialDecor() {
    return HomeCoupleCardDecor.fromJson(
      widget.initialDecor.toJson(),
    ).withFrameAccess(isVip: widget.isVip);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _activeDrawing.dispose();
    super.dispose();
  }

  void _add(HomeCoupleStickerDefinition sticker) {
    if (_draft.stickers.length >= HomeCoupleCardDecor.maxStickers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10nService().format('home_decor_limit', {
              'count': '${HomeCoupleCardDecor.maxStickers}',
            }),
          ),
        ),
      );
      return;
    }
    final index = _draft.stickers.length;
    // Đặt sticker mới trong phần trống dưới khối; có thể kéo tới vị trí khác.
    setState(() {
      _draft = _draft.copyWith(
        stickers: [
          ..._draft.stickers,
          HomeCoupleStickerPlacement(
            id: sticker.id,
            x: .2 + index % 4 * .2,
            y: .84,
            scale: 1,
          ),
        ],
      );
      _selected = index;
    });
  }

  void _editSelected({double? scale, double? rotation}) {
    final index = _selected;
    if (index == null) return;
    final stickers = [..._draft.stickers];
    stickers[index] = stickers[index].copyWith(
      scale: scale,
      rotation: rotation,
    );
    setState(() => _draft = _draft.copyWith(stickers: stickers));
  }

  void _move(int index, Offset delta, Size size) {
    final stickers = [..._draft.stickers];
    stickers[index] = HomeCoupleDecorGeometry.move(
      stickers[index],
      delta,
      size,
    );
    setState(() {
      _selected = index;
      _draft = _draft.copyWith(stickers: stickers);
    });
  }

  void _remove() {
    final index = _selected;
    if (index == null) return;
    setState(() {
      _draft = _draft.copyWith(stickers: [..._draft.stickers]..removeAt(index));
      _selected = null;
    });
  }

  void _reset() {
    setState(() {
      _draft = HomeCoupleCardDecor.defaultValue();
      _selected = null;
      _activeDrawing.value = null;
      _messageController.clear();
    });
  }

  void _selectSection(int section) {
    setState(() {
      _section = section;
      _selected = null;
      _activeDrawing.value = null;
    });
  }

  Offset _normalizeDrawingPoint(Offset point, Size canvas) {
    if (canvas.width <= 0 || canvas.height <= 0) return const Offset(.5, .5);
    return Offset(
      (point.dx / canvas.width).clamp(0.0, 1.0),
      (point.dy / canvas.height).clamp(0.0, 1.0),
    );
  }

  void _startDrawing(Offset point, Size canvas) {
    if (_saving || !(widget.isScopeCurrent?.call() ?? true)) return;
    if (_draft.drawings.length >= HomeCoupleCardDecor.maxDrawingStrokes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10nService().format('home_decor_draw_limit', {
              'count': '${HomeCoupleCardDecor.maxDrawingStrokes}',
            }),
          ),
        ),
      );
      return;
    }
    final normalized = _normalizeDrawingPoint(point, canvas);
    _activeDrawing.value = HomeCoupleDrawingStroke(
      points: [normalized],
      colorValue: HomeCoupleDecorCatalog.drawColors[_drawColorKey]!.toARGB32(),
      width: _drawWidth,
    );
  }

  void _updateDrawing(Offset point, Size canvas) {
    if (_saving || !(widget.isScopeCurrent?.call() ?? true)) {
      _cancelDrawing();
      return;
    }
    final drawing = _activeDrawing.value;
    if (drawing == null) return;
    final normalized = _normalizeDrawingPoint(point, canvas);
    if ((drawing.points.last - normalized).distance < .002) return;
    final points = drawing.points.length < HomeCoupleDrawingStroke.maxPoints
        ? [...drawing.points]
        : [
            for (var index = 0; index < drawing.points.length - 1; index += 2)
              drawing.points[index],
            drawing.points.last,
          ];
    points.add(normalized);
    _activeDrawing.value = drawing.copyWith(points: List.unmodifiable(points));
  }

  void _finishDrawing() {
    if (_saving || !(widget.isScopeCurrent?.call() ?? true)) {
      _cancelDrawing();
      return;
    }
    final drawing = _activeDrawing.value;
    if (drawing == null || drawing.points.isEmpty) return;
    setState(() {
      _draft = _draft.copyWith(drawings: [..._draft.drawings, drawing]);
      _activeDrawing.value = null;
    });
  }

  void _cancelDrawing() {
    _activeDrawing.value = null;
  }

  void _undoDrawing() {
    if (_draft.drawings.isEmpty) return;
    setState(() {
      _activeDrawing.value = null;
      _draft = _draft.copyWith(drawings: [..._draft.drawings]..removeLast());
    });
  }

  void _clearDrawings() {
    if (_draft.drawings.isEmpty && _activeDrawing.value == null) return;
    setState(() {
      _activeDrawing.value = null;
      _draft = _draft.copyWith(drawings: const []);
    });
  }

  String _rateLimitMessage(int retryAfterMs) => L10nService().format(
    'ui_home_action_too_fast_blocked_in_value1_minutes_900f32',
    {'value1': '${(retryAfterMs / 60000).ceil().clamp(1, 30)}'},
  );

  Future<void> _save() async {
    if (_saving) return;
    final retryAfterMs =
        _retryBlockedUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (retryAfterMs > 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_rateLimitMessage(retryAfterMs))),
        );
      return;
    }
    if (!(widget.isScopeCurrent?.call() ?? true)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.tr('home_decor_save_failed'))),
        );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _cancelDrawing();
    final snapshot = HomeCoupleCardDecor.fromJson(_draft.toJson());
    if (_revision > 0 && _conflict == null && snapshot.sameDesign(_base)) {
      Navigator.of(context).pop(snapshot);
      return;
    }
    if (_requestedDesign == null || !snapshot.sameDesign(_requestedDesign!)) {
      _requestId = HomeCoupleDecorSyncService.newRequestId();
      _requestedDesign = snapshot;
    }
    setState(() => _saving = true);
    HomeCoupleDecorSaveResult result;
    try {
      final saver = widget.saveShared;
      if (saver != null) {
        result = await saver(
          decor: snapshot,
          expectedRevision: _revision,
          requestId: _requestId!,
        );
      } else {
        final saved = await HomeCoupleDecorStore.save(widget.scope, snapshot);
        result = saved
            ? HomeCoupleDecorSaveResult(
                HomeCoupleDecorSaveStatus.saved,
                snapshot: HomeCoupleDecorSnapshot(
                  decor: snapshot,
                  revision: _revision + 1,
                  requestId: _requestId!,
                  updatedBy: '',
                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                ),
              )
            : const HomeCoupleDecorSaveResult(HomeCoupleDecorSaveStatus.failed);
      }
    } catch (_) {
      result = const HomeCoupleDecorSaveResult(
        HomeCoupleDecorSaveStatus.failed,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!(widget.isScopeCurrent?.call() ?? true)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.tr('home_decor_save_failed'))),
        );
      return;
    }
    if (result.status == HomeCoupleDecorSaveStatus.saved ||
        result.status == HomeCoupleDecorSaveStatus.unchanged) {
      final saved = result.snapshot?.decor ?? snapshot;
      widget.onSaved?.call(saved);
      Navigator.of(context).pop(saved);
      return;
    }
    if (result.status == HomeCoupleDecorSaveStatus.conflict) {
      setState(() => _conflict = result.snapshot);
    }
    if (result.status == HomeCoupleDecorSaveStatus.rateLimited &&
        result.retryAfterMs > 0) {
      _retryBlockedUntilMs =
          DateTime.now().millisecondsSinceEpoch + result.retryAfterMs;
    }
    final message = switch (result.status) {
      HomeCoupleDecorSaveStatus.rateLimited => _rateLimitMessage(
        result.retryAfterMs,
      ),
      HomeCoupleDecorSaveStatus.conflict => context.tr(
        'notes_conflict_reloaded',
      ),
      HomeCoupleDecorSaveStatus.pending => context.tr(
        'ui_common_you_re_clicking_too_fast_eeefa5',
      ),
      _ => result.message ?? context.tr('home_decor_save_failed'),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _useLatest() {
    final latest = _conflict;
    if (latest == null) return;
    setState(() {
      _draft = latest.decor.withFrameAccess(isVip: widget.isVip);
      _base = _draft;
      _revision = latest.revision;
      _selected = null;
      _activeDrawing.value = null;
      _messageController.text = _draft.message;
      _conflict = null;
      _requestedDesign = null;
      _requestId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF1DFEA) : const Color(0xFF604656);
    final surface = dark ? const Color(0xFF302B37) : Colors.white;
    final accent = dark ? const Color(0xFFEAB0C8) : const Color(0xFFC66F92);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: dark
            ? const Color(0xFF211F28)
            : const Color(0xFFFFFAF7),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: ink,
          title: Text(
            context.tr('home_decorate_card'),
            style: SLTheme.quicksand(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _saving ? null : _reset,
              tooltip: context.tr('home_decor_reset'),
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            key: const ValueKey('home-couple-decor-save'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: dark ? const Color(0xFF352735) : Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(context.tr('home_decor_save')),
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: AbsorbPointer(
            absorbing: _saving,
            child: ListView(
              key: const ValueKey('home-decor-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(
                  context.tr('home_decor_subtitle'),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    height: 1.5,
                    color: ink.withValues(alpha: .8),
                  ),
                ),
                if (_conflict != null) ...[
                  const SizedBox(height: 12),
                  Text(context.tr('notes_conflict_reloaded')),
                  OutlinedButton.icon(
                    key: const ValueKey('home-decor-use-latest'),
                    onPressed: _useLatest,
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(context.tr('insight_reload')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TickerMode(
                  enabled: true,
                  child: HomeCoupleProfileCard(
                    key: const ValueKey('home-couple-decor-preview'),
                    decor: _draft,
                    selectedStickerIndex: _selected,
                    drawingEnabled: _section == 3,
                    activeDrawingListenable: _activeDrawing,
                    onSelectSticker: (index) =>
                        setState(() => _selected = index),
                    onMoveSticker: _move,
                    onDrawStart: _startDrawing,
                    onDrawUpdate: _updateDrawing,
                    onDrawEnd: _finishDrawing,
                    onDrawCancel: _cancelDrawing,
                    left:
                        widget.previewLeft ??
                        _PreviewPerson(
                          female: false,
                          label: context.tr('home_decor_preview_you'),
                        ),
                    center:
                        widget.previewCenter ??
                        const Padding(
                          padding: EdgeInsets.only(top: 25),
                          child: HomeCoupleDecorArt(id: 'heart', size: 40),
                        ),
                    right:
                        widget.previewRight ??
                        _PreviewPerson(
                          female: true,
                          label: context.tr('home_decor_preview_partner'),
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app_outlined, size: 17, color: accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.tr(
                            _section == 3
                                ? 'home_decor_draw_hint'
                                : 'home_decor_drag_hint',
                          ),
                          style: SLTheme.quicksand(
                            color: ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _sections(ink, surface, accent),
                const SizedBox(height: 16),
                if (_section == 0) _backgrounds(ink, dark),
                if (_section == 1) _frames(ink, surface, accent),
                if (_section == 2) _stickers(ink, surface, accent),
                if (_section == 3) _drawings(ink, surface, accent),
                if (_selected != null && _section != 3) ...[
                  const SizedBox(height: 16),
                  _selectedControls(surface, ink, accent),
                ],
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey('home-decor-message-input'),
                  controller: _messageController,
                  maxLength: HomeCoupleCardDecor.maxMessageLength,
                  minLines: 1,
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  style: SLTheme.quicksand(color: ink, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: context.tr('home_decor_message_title'),
                    hintText: context.tr('home_decor_preview_hint'),
                    filled: true,
                    fillColor: surface,
                    prefixIcon: Icon(Icons.edit_note_rounded, color: accent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: accent.withValues(alpha: .3),
                      ),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(message: value)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sections(Color ink, Color surface, Color accent) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(12) > 16
          ? 2
          : 4;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var index = 0; index < 4; index++)
            SizedBox(
              width: (constraints.maxWidth - 8 * (columns - 1)) / columns,
              child: Semantics(
                selected: _section == index,
                child: OutlinedButton(
                  key: ValueKey('home-decor-section-$index'),
                  onPressed: () => _selectSection(index),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 68),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 12,
                    ),
                    backgroundColor: _section == index
                        ? accent.withValues(alpha: .12)
                        : surface,
                    foregroundColor: ink,
                    side: BorderSide(
                      color: _section == index
                          ? accent
                          : accent.withValues(alpha: .15),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        [
                          Icons.gradient_rounded,
                          Icons.crop_square_rounded,
                          Icons.local_florist_outlined,
                          Icons.draw_outlined,
                        ][index],
                        size: 20,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.tr(
                          [
                            'home_decor_background_title',
                            'home_decor_frame_title',
                            'home_decor_sticker_title',
                            'home_decor_draw_title',
                          ][index],
                        ),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _selectedControls(Color surface, Color ink, Color accent) {
    final sticker = _draft.stickers[_selected!];
    final name = context.tr(
      HomeCoupleDecorCatalog.sticker(sticker.id)!.labelKey,
    );
    return Container(
      key: const ValueKey('home-decor-selected-controls'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HomeCoupleDecorArt(
                id: sticker.id,
                size: 32,
                animate:
                    HomeCoupleDecorCatalog.sticker(sticker.id)?.isAnimated ??
                    false,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: SLTheme.quicksand(
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('home-decor-remove'),
                tooltip: context.tr('home_decor_remove_selected'),
                onPressed: _remove,
                icon: Icon(Icons.delete_outline_rounded, color: accent),
              ),
            ],
          ),
          Text(
            context.tr('home_decor_size'),
            style: SLTheme.quicksand(color: ink, fontSize: 12),
          ),
          Slider(
            key: const ValueKey('home-decor-size'),
            value: sticker.scale,
            min: .65,
            max: 1.8,
            onChanged: (value) => _editSelected(scale: value),
            semanticFormatterCallback: (value) => '${(value * 100).round()}%',
          ),
          Text(
            context.tr('home_decor_rotation'),
            style: SLTheme.quicksand(color: ink, fontSize: 12),
          ),
          Slider(
            key: const ValueKey('home-decor-rotation'),
            value: sticker.rotation,
            min: -.65,
            max: .65,
            onChanged: (value) => _editSelected(rotation: value),
          ),
        ],
      ),
    );
  }

  Widget _backgrounds(Color ink, bool dark) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final key in HomeCoupleDecorCatalog.backgroundKeys)
          SizedBox(
            width: (constraints.maxWidth - 10) / 2,
            child: Semantics(
              selected: _draft.backgroundKey == key,
              child: InkWell(
                key: ValueKey('home-decor-background-$key'),
                onTap: () => setState(
                  () => _draft = _draft.copyWith(backgroundKey: key),
                ),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: HomeCoupleDecorCatalog.backgroundColors(
                        key,
                        dark: dark,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _draft.backgroundKey == key
                          ? const Color(0xFFCF83A1)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _draft.backgroundKey == key
                            ? Icons.check_circle_outline_rounded
                            : Icons.favorite_border_rounded,
                        color: ink,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('home_decor_background_$key'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _showVipDialog() async {
    final feature = context.tr('home_decor_frame_rainbow_vip');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SLAlertDialog(
        title: SLDialogHeading(
          title: context.tr('p6_upgrade_vip'),
          icon: Icons.diamond_outlined,
        ),
        content: Text(
          L10nService().format('dialog_vip_feature', {'feature': feature}),
        ),
        actions: [
          SLDialogAction(
            primary: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('toast_ok')),
          ),
        ],
      ),
    );
  }

  Widget _frames(Color ink, Color surface, Color accent) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final key in HomeCoupleDecorCatalog.frameKeys)
        Builder(
          builder: (context) {
            final locked =
                HomeCoupleDecorCatalog.isVipFrame(key) && !widget.isVip;
            return ChoiceChip(
              key: ValueKey('home-decor-frame-$key'),
              selected: _draft.frameKey == key,
              onSelected: (_) {
                if (locked) {
                  _showVipDialog();
                  return;
                }
                setState(() => _draft = _draft.copyWith(frameKey: key));
              },
              backgroundColor: surface,
              selectedColor: accent.withValues(alpha: .18),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              avatar: Icon(
                key == 'clean'
                    ? Icons.crop_square_rounded
                    : key == 'doodle'
                    ? Icons.gesture_rounded
                    : key == 'scallop'
                    ? Icons.filter_vintage_outlined
                    : key == 'rainbow_vip'
                    ? Icons.diamond_rounded
                    : Icons.auto_awesome_outlined,
                size: 20,
                color: locked ? accent.withValues(alpha: .55) : accent,
              ),
              label: Text(
                '${context.tr('home_decor_frame_$key')}${locked ? ' 🔒' : ''}',
                style: SLTheme.quicksand(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
    ],
  );

  Widget _stickers(Color ink, Color surface, Color accent) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final pack in [
              HomeCoupleDecorCatalog.pack('cute'),
              ...HomeCoupleDecorCatalog.packs.where(
                (item) => item.key != 'cute',
              ),
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  key: ValueKey('home-decor-pack-${pack.key}'),
                  selected: _pack == pack.key,
                  onSelected: (_) => setState(() => _pack = pack.key),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  selectedColor: pack.accent.withValues(alpha: .18),
                  avatar: HomeCoupleDecorArt(
                    id: pack.stickers.first.id,
                    size: 26,
                    animate: pack.stickers.first.isAnimated,
                  ),
                  label: Text(
                    context.tr(pack.labelKey),
                    style: SLTheme.quicksand(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
          final columns = (constraints.maxWidth / (76 * scale.clamp(1, 1.8)))
              .floor()
              .clamp(2, 4);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: HomeCoupleDecorCatalog.pack(_pack).stickers.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 82 + 30 * scale,
            ),
            itemBuilder: (context, index) {
              final sticker = HomeCoupleDecorCatalog.pack(
                _pack,
              ).stickers[index];
              return Material(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  key: ValueKey('home-decor-add-${sticker.id}'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _add(sticker),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HomeCoupleDecorArt(
                          id: sticker.id,
                          size: 48,
                          animate: sticker.isAnimated,
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            context.tr(sticker.labelKey),
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              color: ink,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ],
  );

  Widget _drawings(Color ink, Color surface, Color accent) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(Icons.gesture_rounded, size: 18, color: accent),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              context.tr('home_decor_draw_title'),
              style: SLTheme.quicksand(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        context.tr('home_decor_draw_color'),
        style: SLTheme.quicksand(
          color: ink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final key in HomeCoupleDecorCatalog.drawColorKeys)
            Semantics(
              button: true,
              selected: _drawColorKey == key,
              label: context.tr('home_decor_draw_color_$key'),
              child: Tooltip(
                message: context.tr('home_decor_draw_color_$key'),
                excludeFromSemantics: true,
                child: InkWell(
                  key: ValueKey('home-decor-draw-color-$key'),
                  onTap: () => setState(() => _drawColorKey = key),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _drawColorKey == key
                            ? accent
                            : accent.withValues(alpha: .18),
                        width: _drawColorKey == key ? 2.4 : 1,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HomeCoupleDecorCatalog.drawColors[key],
                        shape: BoxShape.circle,
                      ),
                      child: _drawColorKey == key
                          ? Icon(
                              Icons.check_rounded,
                              size: 21,
                              color: key == 'sunshine' || key == 'mint'
                                  ? const Color(0xFF473848)
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        context.tr('home_decor_draw_size'),
        style: SLTheme.quicksand(
          color: ink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(11) > 15
              ? 1
              : 3;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in [
                (width: .008, key: 'fine'),
                (width: .014, key: 'medium'),
                (width: .024, key: 'bold'),
              ])
                SizedBox(
                  width: (constraints.maxWidth - 8 * (columns - 1)) / columns,
                  child: Semantics(
                    selected: _drawWidth == option.width,
                    child: OutlinedButton(
                      key: ValueKey('home-decor-draw-size-${option.key}'),
                      onPressed: () =>
                          setState(() => _drawWidth = option.width),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        backgroundColor: _drawWidth == option.width
                            ? accent.withValues(alpha: .12)
                            : surface,
                        foregroundColor: ink,
                        side: BorderSide(
                          color: _drawWidth == option.width
                              ? accent
                              : accent.withValues(alpha: .18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 18,
                            height: (option.width * 700).clamp(4.0, 16.0),
                            decoration: BoxDecoration(
                              color: HomeCoupleDecorCatalog
                                  .drawColors[_drawColorKey],
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              context.tr('home_decor_draw_size_${option.key}'),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                color: ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final stackActions =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(12) > 16;
          final width = stackActions
              ? constraints.maxWidth
              : (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: width,
                child: OutlinedButton.icon(
                  key: const ValueKey('home-decor-draw-undo'),
                  onPressed: _draft.drawings.isEmpty ? null : _undoDrawing,
                  icon: const Icon(Icons.undo_rounded),
                  label: Text(
                    context.tr('home_decor_draw_undo'),
                    textAlign: TextAlign.center,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    foregroundColor: ink,
                    side: BorderSide(color: accent.withValues(alpha: .25)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: OutlinedButton.icon(
                  key: const ValueKey('home-decor-draw-clear'),
                  onPressed: _draft.drawings.isEmpty ? null : _clearDrawings,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(
                    context.tr('home_decor_draw_clear'),
                    textAlign: TextAlign.center,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: .25)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _PreviewPerson extends StatelessWidget {
  const _PreviewPerson({required this.female, required this.label});
  final bool female;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipOval(
        child: SizedBox.square(
          dimension: 80,
          child: CoupleDefaultAvatar(female: female, animate: false),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        label,
        textAlign: TextAlign.center,
        style: SLTheme.quicksand(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}
