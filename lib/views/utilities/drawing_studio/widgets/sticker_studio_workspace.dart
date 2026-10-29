part of '../../drawing_studio_screen.dart';

extension _StickerStudioWorkspace on _DrawingStudioScreenState {
  Widget _buildStickerStudio() {
    return Scaffold(
      backgroundColor: _StudioStyle.cream,
      bottomNavigationBar: _isFocusMode
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: _buildStudioToolbar(),
              ),
            )
          : null,
      body: CustomPaint(
        painter: const _StudioGrainPainter(),
        child: SafeArea(
          child: SingleChildScrollView(
            key: const Key('drawing-workspace-scroll'),
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              _isFocusMode ? 6 : 12,
              8,
              _isFocusMode ? 6 : 12,
              _isFocusMode ? 8 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStudioHeader(),
                    if (!_isFocusMode) ...[
                      const SizedBox(height: 10),
                      _buildStudioModes(),
                    ],
                    const SizedBox(height: 10),
                    _buildCanvasControls(),
                    const SizedBox(height: 12),
                    _buildStudioCanvas(),
                    if (!_isFocusMode) ...[
                      const SizedBox(height: 14),
                      _buildStudioToolbar(),
                      const SizedBox(height: 12),
                      _buildStudioRatios(),
                      const SizedBox(height: 12),
                      _buildStudioPalette(),
                      const SizedBox(height: 12),
                      _buildQuickStickers(),
                      const SizedBox(height: 10),
                      _buildStudioFooter(),
                      const SizedBox(height: 12),
                      _buildGallerySection(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioHeader() {
    final title = context.tr('util_xngv_5f1f18');
    final titleStyle = GoogleFonts.nunito(
      fontSize: 30,
      fontWeight: FontWeight.w900,
      height: 1.02,
      letterSpacing: -0.7,
    );
    return Row(
      children: [
        _studioCircleButton(
          icon: Icons.arrow_back_rounded,
          label: context.tr('home_quayli_0033aa'),
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Semantics(
            header: true,
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: Text(
                    title,
                    style: titleStyle.copyWith(
                      foreground: Paint()
                        ..color = Colors.white
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 6,
                      shadows: const [
                        Shadow(
                          color: Color(0x33C48C69),
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  title,
                  style: titleStyle.copyWith(color: _StudioStyle.coral),
                ),
              ],
            ),
          ),
        ),
        if (!_isFocusMode)
          _StudioSprite(atlas: _studioAtlas, index: 0, size: 86),
        _studioCircleButton(
          icon: Icons.info_outline_rounded,
          label: context.tr('p8_drawing_info_tooltip'),
          onTap: () => _showInfoDialog(context),
        ),
      ],
    );
  }

  Widget _studioCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFCF8),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x1AC08F6E),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon, color: _StudioStyle.coral, size: 25),
      ),
    );
  }

  Widget _buildStudioModes() {
    return _StudioCard(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _studioMode(
              'frame',
              context.tr('util_vkhung_cc3a36'),
              Icons.crop_free_rounded,
            ),
          ),
          Expanded(
            child: _studioMode(
              'pic',
              context.tr('util_vtranh_d96af9'),
              Icons.brush_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _studioMode(String value, String label, IconData icon) {
    final selected = _mode == value;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: Key('drawing-mode-$value'),
          borderRadius: BorderRadius.circular(999),
          onTap: _isExporting || _isDrawing
              ? null
              : () => _updateStudio(() => _mode = value),
          child: AnimatedContainer(
            duration: _StudioStyle.motion(context),
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFFFF8398), _StudioStyle.coral],
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected ? Colors.white : _StudioStyle.coral,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: _StudioStyle.text(
                      21,
                      color: selected ? Colors.white : _StudioStyle.coral,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasControls() {
    return _StudioCard(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _canvasModeChoice(
                  scroll: false,
                  icon: Icons.draw_rounded,
                  label: context.tr('drawing_studio_mode_draw'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _canvasModeChoice(
                  scroll: true,
                  icon: Icons.swipe_vertical_rounded,
                  label: context.tr('drawing_studio_mode_scroll'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              context.tr(
                _isScrollMode
                    ? 'drawing_studio_scroll_hint'
                    : 'drawing_studio_draw_hint',
              ),
              style: _StudioStyle.text(15, color: _StudioStyle.muted),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const Key('drawing-focus-toggle'),
              onPressed: _isDrawing || _isExporting
                  ? null
                  : () => _setFocusMode(!_isFocusMode),
              icon: Icon(
                _isFocusMode
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                size: 20,
              ),
              label: Text(
                context.tr(
                  _isFocusMode
                      ? 'drawing_studio_focus_off'
                      : 'drawing_studio_focus_on',
                ),
                style: _StudioStyle.text(16),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _StudioStyle.coral,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvasModeChoice({
    required bool scroll,
    required IconData icon,
    required String label,
  }) {
    final selected = _isScrollMode == scroll;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? _StudioStyle.coral : const Color(0xFFFFF0EF),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key(
            scroll ? 'drawing-interaction-scroll' : 'drawing-interaction-draw',
          ),
          borderRadius: BorderRadius.circular(16),
          onTap: _isDrawing || _isExporting
              ? null
              : () => _setScrollMode(scroll),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : _StudioStyle.coral,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: _StudioStyle.text(
                      18,
                      color: selected ? Colors.white : _StudioStyle.coral,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = math.max(
          220.0,
          MediaQuery.sizeOf(context).height * (_isFocusMode ? 0.62 : 0.54),
        );
        final width = math.min(
          constraints.maxWidth - 22,
          maxHeight * _selectedRatio.ratio,
        );
        final height = width / _selectedRatio.ratio;
        return Center(
          child: _StudioArtworkBoundary(
            key: _artworkKey,
            child: SizedBox(
              width: width + 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    painter: const _StudioPaperShadow(),
                    child: ClipPath(
                      clipper: const _StudioPaperClipper(),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Stack(
                          children: [
                            RepaintBoundary(
                              key: _canvasKey,
                              child: Semantics(
                                label: context.tr('p8_drawing_canvas_label'),
                                hint: context.tr('p8_drawing_canvas_hint'),
                                child: RawGestureDetector(
                                  key: const Key('drawing-canvas'),
                                  behavior: HitTestBehavior.opaque,
                                  gestures: _isScrollMode || _isExporting
                                      ? const <Type, GestureRecognizerFactory>{}
                                      : <Type, GestureRecognizerFactory>{
                                          EagerGestureRecognizer:
                                              GestureRecognizerFactoryWithHandlers<
                                                EagerGestureRecognizer
                                              >(
                                                () => EagerGestureRecognizer(),
                                                (_) {},
                                              ),
                                        },
                                  child: Listener(
                                    onPointerDown: _canvasPointerDown,
                                    onPointerMove: _canvasPointerMove,
                                    onPointerUp: _canvasPointerUp,
                                    onPointerCancel: _canvasPointerUp,
                                    child: SizedBox(
                                      width: width,
                                      height: height,
                                      child: CustomPaint(
                                        painter: _DrawingCanvasPainter(
                                          backgroundId: _backgroundId,
                                          strokes: _allVisibleStrokes,
                                          atlas: _studioAtlas,
                                          repaint: _canvasRepaintNotifier,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!_hasAnyStroke)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: SizedBox(
                                          width: width - 48,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _StudioSprite(
                                                atlas: _studioAtlas,
                                                index: 1,
                                                size: math.min(
                                                  width * 0.42,
                                                  math.min(height * 0.4, 134),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                context.tr(
                                                  'drawing_studio_empty_hint',
                                                ),
                                                key: const Key(
                                                  'drawing-empty-hint',
                                                ),
                                                textAlign: TextAlign.center,
                                                style: _StudioStyle.text(
                                                  21,
                                                  color: const Color(
                                                    0xFF975651,
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
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _StudioPaperTrim()),
                    ),
                  ),
                  const Positioned(
                    top: -3,
                    left: -5,
                    child: _StudioWashiTape(),
                  ),
                  const Positioned(
                    bottom: -2,
                    right: -4,
                    child: _StudioWashiTape(blue: true),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudioToolbar() {
    return _StudioCard(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(constraints.maxWidth, 6 * 52),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StudioTool(
                      id: 'pen',
                      label: context.tr('drawing_studio_tool_pen'),
                      atlas: _studioAtlas,
                      sprite: 2,
                      fallback: Icons.edit_rounded,
                      selected: !_isEraser,
                      onTap: _isExporting
                          ? null
                          : () {
                              final wasPen = !_isEraser;
                              _updateStudio(() => _isEraser = false);
                              if (wasPen) unawaited(_showStudioBrushSheet());
                            },
                      onLongPress: _showStudioBrushSheet,
                    ),
                  ),
                  Expanded(
                    child: _StudioTool(
                      id: 'eraser',
                      label: context.tr('drawing_studio_tool_eraser'),
                      atlas: _studioAtlas,
                      sprite: 3,
                      fallback: Icons.auto_fix_normal_rounded,
                      selected: _isEraser,
                      onTap: _isExporting
                          ? null
                          : () => _updateStudio(() => _isEraser = !_isEraser),
                      onLongPress: _showStudioBrushSheet,
                    ),
                  ),
                  Expanded(
                    child: _StudioTool(
                      id: 'undo',
                      label: context.tr('util_hontc_96ce27'),
                      atlas: _studioAtlas,
                      sprite: 4,
                      fallback: Icons.undo_rounded,
                      onTap: _strokes.isEmpty || _isExporting
                          ? null
                          : _undoStroke,
                    ),
                  ),
                  Expanded(
                    child: _StudioTool(
                      id: 'redo',
                      label: context.tr('drawing_studio_tool_redo'),
                      atlas: _studioAtlas,
                      sprite: 5,
                      fallback: Icons.redo_rounded,
                      onTap: _redoStrokes.isEmpty || _isExporting
                          ? null
                          : _redoStroke,
                    ),
                  ),
                  Expanded(
                    child: _StudioTool(
                      id: 'color',
                      label: context.tr('drawing_studio_tool_color'),
                      atlas: _studioAtlas,
                      sprite: 6,
                      fallback: Icons.palette_rounded,
                      onTap: _isExporting ? null : _showStudioPaletteSheet,
                    ),
                  ),
                  Expanded(
                    child: _StudioTool(
                      id: 'save',
                      label: context.tr('p3_save'),
                      atlas: _studioAtlas,
                      sprite: 7,
                      fallback: Icons.save_outlined,
                      busy: _isExporting,
                      onTap: !_hasAnyStroke || _isExporting
                          ? null
                          : _showStudioExportSheet,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _studioSectionTitle(String title, {int? sprite, IconData? icon}) {
    return Row(
      children: [
        if (sprite != null)
          _StudioSprite(atlas: _studioAtlas, index: sprite, size: 25)
        else
          Icon(icon, color: _StudioStyle.coral, size: 22),
        const SizedBox(width: 7),
        Expanded(child: Text(title, style: _StudioStyle.text(21))),
      ],
    );
  }

  Widget _buildStudioRatios() {
    return _StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _studioSectionTitle(
            context.tr('util_tlkhungv_873220'),
            icon: Icons.crop_free_rounded,
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = math.max(
                48.0,
                MediaQuery.textScalerOf(context).scale(16) * 2.5 + 12,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(
                    constraints.maxWidth,
                    itemWidth * _DrawingStudioScreenState._ratioPresets.length +
                        24,
                  ),
                  child: Row(
                    children: [
                      for (
                        var i = 0;
                        i < _DrawingStudioScreenState._ratioPresets.length;
                        i++
                      ) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _studioRatioChip(
                            _DrawingStudioScreenState._ratioPresets[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _studioRatioChip(_CanvasRatioPreset preset) {
    final selected = _aspectRatioId == preset.id;
    final label = L10nService().format('p8_drawing_select_ratio', {
      'ratio': preset.label,
    });
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: Key('drawing-ratio-${preset.id}'),
            borderRadius: BorderRadius.circular(14),
            onTap: _isExporting || _isDrawing
                ? null
                : () => _updateStudio(() => _aspectRatioId = preset.id),
            child: AnimatedContainer(
              duration: _StudioStyle.motion(context),
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _StudioStyle.coral : const Color(0xFFFFF0EF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? Colors.white : const Color(0xFFF2D1D0),
                  width: 2,
                ),
                boxShadow: selected
                    ? const [BoxShadow(color: Color(0x33FF526C), blurRadius: 6)]
                    : null,
              ),
              child: Text(
                preset.label,
                style: _StudioStyle.text(
                  17,
                  color: selected ? Colors.white : _StudioStyle.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioPalette() {
    return _StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _studioSectionTitle(context.tr('util_bngmu_5abdcd'), sprite: 6),
          const SizedBox(height: 7),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (
                  var i = 0;
                  i < _DrawingStudioScreenState._palette.length;
                  i++
                )
                  _studioColorButton(_DrawingStudioScreenState._palette[i], i),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _studioColorButton(Color color, int index, {bool dismiss = false}) {
    final selected = _currentColor == color && !_isEraser;
    final label = L10nService().format('drawing_studio_color_number', {
      'index': index + 1,
    });
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: Key('drawing-color-$index'),
          customBorder: const CircleBorder(),
          onTap: _isExporting
              ? null
              : () {
                  _updateStudio(() {
                    _currentColor = color;
                    _isEraser = false;
                  });
                  if (dismiss) Navigator.of(context).pop();
                },
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: AnimatedContainer(
                duration: _StudioStyle.motion(context),
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: selected ? color : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStickers() {
    return _StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _studioSectionTitle(
            context.tr('drawing_studio_quick_stickers'),
            sprite: 9,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _studioStickerTile(
                    i + 8,
                    [
                      'drawing_studio_sticker_heart',
                      'effect_stars',
                      'drawing_studio_sticker_smile',
                    ][i],
                    [
                      const Color(0xFFFFDEE6),
                      const Color(0xFFFFF0C5),
                      const Color(0xFFECDDFF),
                    ][i],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _studioStickerTile(int index, String labelKey, Color color) {
    final label = context.tr(labelKey);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('drawing-sticker-$index'),
          borderRadius: BorderRadius.circular(20),
          onTap: _isExporting || _studioAtlas == null
              ? null
              : () => _addQuickSticker(index),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(4, 7, 4, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.38),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _StudioSprite(atlas: _studioAtlas, index: index, size: 52),
                const SizedBox(height: 3),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: _StudioStyle.text(17),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioFooter() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        TextButton.icon(
          key: const Key('drawing-background'),
          onPressed: _isExporting ? null : _showBackgroundPicker,
          icon: const Icon(Icons.wallpaper_rounded, size: 19),
          label: Text(
            context.tr('util_inn_2c444b'),
            style: _StudioStyle.text(17),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _StudioStyle.ink,
            minimumSize: const Size(48, 48),
          ),
        ),
        TextButton.icon(
          key: const Key('drawing-clear'),
          onPressed: _strokes.isEmpty || _isExporting ? null : _clearDrawing,
          icon: const Icon(Icons.delete_outline_rounded, size: 19),
          label: Text(
            context.tr('util_xantv_68c9be'),
            style: _StudioStyle.text(17),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _StudioStyle.ink,
            minimumSize: const Size(48, 48),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.phone_iphone_rounded,
              size: 15,
              color: _StudioStyle.muted,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                context.tr('util_luringtrnm_3707e8'),
                style: _StudioStyle.text(14, color: _StudioStyle.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _studioSheet(String title, Widget child) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _StudioStyle.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: _StudioStyle.text(25)),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showStudioPaletteSheet() {
    return _studioSheet(
      context.tr('util_bngmu_5abdcd'),
      Wrap(
        children: [
          for (var i = 0; i < _DrawingStudioScreenState._palette.length; i++)
            _studioColorButton(
              _DrawingStudioScreenState._palette[i],
              i,
              dismiss: true,
            ),
        ],
      ),
    );
  }

  Future<void> _showStudioBrushSheet() {
    return _studioSheet(
      context.tr('util_dynt_e5cd93'),
      StatefulBuilder(
        builder: (context, updateSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 40,
              child: Center(
                child: Container(
                  width: 140,
                  height: _strokeWidth,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            Slider(
              value: _strokeWidth,
              min: 2,
              max: 28,
              divisions: 26,
              label: '${_strokeWidth.round()} px',
              activeColor: _StudioStyle.coral,
              onChanged: (value) {
                _updateStudio(() => _strokeWidth = value);
                updateSheet(() {});
              },
            ),
            Text('${_strokeWidth.round()} px', style: _StudioStyle.text(20)),
          ],
        ),
      ),
    );
  }

  Future<void> _showStudioExportSheet() {
    Widget action(
      IconData icon,
      String key,
      Future<void> Function() callback, {
      bool enabled = true,
    }) {
      return ListTile(
        enabled: enabled,
        leading: Icon(icon, color: _StudioStyle.coral),
        title: Text(context.tr(key), style: _StudioStyle.text(20)),
        onTap: !enabled
            ? null
            : () {
                Navigator.of(context).pop();
                unawaited(callback());
              },
      );
    }

    return _studioSheet(
      context.tr('p3_save'),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          action(
            Icons.collections_bookmark_outlined,
            'util_luvokhov_68fefe',
            _saveDrawing,
          ),
          action(
            Icons.download_rounded,
            'util_luvmy_4ac0a6',
            _saveCurrentCanvasToDevice,
            enabled: !kIsWeb,
          ),
          action(
            Icons.auto_awesome_rounded,
            'util_ctvinstick_30f8c2',
            _saveStickerToGallery,
          ),
          action(
            Icons.content_cut_rounded,
            'util_lusticker_ddf743',
            _saveStickerToDevice,
            enabled: !kIsWeb,
          ),
        ],
      ),
    );
  }
}
