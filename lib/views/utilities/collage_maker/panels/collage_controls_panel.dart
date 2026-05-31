// ignore_for_file: invalid_use_of_protected_member

part of '../../collage_maker_screen.dart';

extension _CollageControlsPanel on _CollageMakerScreenState {
  Widget _buildQuickPresetSelector() {
    final presets = <Map<String, Object>>[
      {
        'label': 'TikTok',
        'hint': '9:16',
        'style': 'story',
        'aspect': '9:16',
        'icon': Icons.smart_display_rounded,
      },
      {
        'label': 'Feed 4 ảnh',
        'hint': '4:5',
        'style': 'grid',
        'aspect': '4:5',
        'icon': Icons.grid_view_rounded,
      },
      {
        'label': 'Album',
        'hint': '1:1',
        'style': 'polaroid',
        'aspect': '1:1',
        'icon': Icons.photo_album_rounded,
      },
      {
        'label': 'Poster',
        'hint': '16:9',
        'style': 'poster',
        'aspect': '16:9',
        'icon': Icons.wallpaper_rounded,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _paperPanelDecoration(
        color: const Color(0xFFFFF8F2),
        borderColor: const Color(0xFFDCC9B8),
        flipped: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mẫu nhanh',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w800,
              color: _paperInk,
              fontSize: 14,
            ),
          ),
          SLSpacing.h8,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((preset) {
                final style = preset['style']! as String;
                final aspect = preset['aspect']! as String;
                final selected =
                    _selectedStyle == style && _selectedAspectRatio == aspect;
                final icon = preset['icon']! as IconData;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _selectedStyle = style;
                        _selectedAspectRatio = aspect;
                        _generatedCollageBytes = null;
                        _hasFullQualityRender = false;
                      });
                      if (_getFilteredUrls().isNotEmpty) {
                        _generateCollage(
                          bypassDebounce: true,
                          randomizeLayout: true,
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 112,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFF2E4DA)
                            : Colors.white.withValues(alpha: 0.74),
                        borderRadius: _paperRadius(flipped: !selected),
                        border: Border.all(
                          color: selected ? _paperRoseDeep : _paperLine,
                          width: selected ? 2 : 1.2,
                        ),
                        boxShadow: _paperShadow(
                          selected ? _paperRoseDeep : _paperCocoa,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            icon,
                            size: 22,
                            color: selected ? _paperRoseDeep : _paperMuted,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            preset['label']! as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 12.6,
                              fontWeight: FontWeight.w900,
                              color: selected ? _paperRoseDeep : _paperInk,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            preset['hint']! as String,
                            style: SLTheme.quicksand(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _paperMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAspectRatioSelector() {
    final compact = MediaQuery.sizeOf(context).width < 380;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('util_tlnhxut_31dcdb'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w700,
            color: _paperInk,
            fontSize: 15,
          ),
        ),
        SLSpacing.h8,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _CollageMakerScreenState._aspectPresets.map((preset) {
              final bool isSelected = preset.id == _selectedAspectRatio;
              final double previewWidth = preset.ratio >= 1 ? 30 : 20;
              final double previewHeight =
                  preset.ratio >= 1 ? previewWidth / preset.ratio : 34;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _selectedAspectRatio = preset.id;
                      _generatedCollageBytes = null;
                    });
                    if (_getFilteredUrls().isNotEmpty) {
                      _generateCollage();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: compact ? 102 : 112,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF2E4DA)
                          : const Color(0xFFFFF8F2),
                      borderRadius: _paperRadius(flipped: !isSelected),
                      border: Border.all(
                        color: isSelected ? _paperRoseDeep : _paperLine,
                        width: isSelected ? 2 : 1.2,
                      ),
                      boxShadow: _paperShadow(
                        isSelected ? _paperRoseDeep : _paperCocoa,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 34,
                          child: Center(
                            child: Container(
                              width: previewWidth,
                              height: previewHeight,
                              decoration: BoxDecoration(
                                color: isSelected ? _paperRoseDeep : _paperMist,
                                borderRadius: _paperRadius(flipped: true),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? _paperRoseDeep : _paperInk,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          preset.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 10.2,
                            fontWeight: FontWeight.w700,
                            color: _paperMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
        SLSpacing.h8,
        Text(
          context.tr('util_xutnhanhch_311e76'),
          style: SLTheme.quicksand(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _paperMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildStickerPicker() {
    final compact = MediaQuery.sizeOf(context).width < 380;
    final stickerOptions = _showAllStickerOptions
        ? _CollageMakerScreenState._stickerOptions
        : _CollageMakerScreenState._stickerOptions
            .take(StickerLibraryScreen.previewStickerLimit)
            .toList(growable: false);
    final hasMoreStickers = _CollageMakerScreenState._stickerOptions.length >
        StickerLibraryScreen.previewStickerLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('util_stickertra_1dac20'),
          style: SLTheme.quicksand(
              fontWeight: FontWeight.w700, color: _paperInk, fontSize: 15),
        ),
        SLSpacing.h8,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _paperPanelDecoration(
            color: const Color(0xFFFFF8F2),
            borderColor: const Color(0xFFD8C7B7),
            flipped: true,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = compact ? 5 : 6;
              const spacing = 8.0;
              final rawTileExtent =
                  (constraints.maxWidth - (crossAxisCount - 1) * spacing) /
                      crossAxisCount;
              final tileExtent = rawTileExtent.clamp(36.0, 46.0);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stickerOptions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  mainAxisExtent: tileExtent,
                ),
                itemBuilder: (context, index) {
                  final sticker = stickerOptions[index];
                  final selected = _selectedStickers.contains(sticker);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedStickers.remove(sticker);
                        } else {
                          _selectedStickers.add(sticker);
                        }
                        _generatedCollageBytes = null;
                      });
                      if (_getFilteredUrls().isNotEmpty) {
                        _generateCollage();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFF2DED3)
                            : const Color(0xFFF8EFE5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? _paperRoseDeep : _paperLine,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: _paperShadow(
                          selected ? _paperRoseDeep : _paperCocoa,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          sticker,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (hasMoreStickers) ...[
          SLSpacing.h8,
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllStickerOptions = !_showAllStickerOptions;
                });
              },
              icon: Icon(
                _showAllStickerOptions
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: _paperRoseDeep,
              ),
              label: Text(
                _showAllStickerOptions ? context.tr('util_thugn_5d7176') : context.tr('util_xemthm_129410'),
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _paperRoseDeep,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
        SLSpacing.h8,
        Text(
          context.tr('util_cthchnnhiu_8eee2d'),
          style: SLTheme.quicksand(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _paperMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSizeControl() {
    final percent = (_photoScale * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _paperPanelDecoration(
        color: const Color(0xFFF9EFE5),
        borderColor: const Color(0xFFDCC7B3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('util_kchthcnhtr_93d00b'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: _paperInk,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: _paperRoseDeep,
                ),
              ),
            ],
          ),
          Slider(
            value: _photoScale,
            min: 0.82,
            max: 1.18,
            divisions: 12,
            activeColor: _paperRoseDeep,
            inactiveColor: const Color(0xFFDCC7B3),
            onChanged: (value) {
              setState(() => _photoScale = value);
            },
            onChangeEnd: (_) {
              setState(() => _generatedCollageBytes = null);
              if (_getFilteredUrls().isNotEmpty) {
                _generateCollage();
              }
            },
          ),
          Text(
            context.tr('util_konhnhhocl_c9c2e0'),
            style: SLTheme.quicksand(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _paperMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleOption(String id, IconData icon, String label) {
    final preset = _CollageMakerScreenState._stylePresets.firstWhere(
      (item) => item.id == id,
      orElse: () => _CollageMakerScreenState._stylePresets.first,
    );
    final bool isSelected = _selectedStyle == id;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedStyle = id;
          _generatedCollageBytes = null;
        });
        if (_getFilteredUrls().isNotEmpty) {
          _generateCollage();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 118,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: isSelected ? preset.background : const Color(0xFFFFF9F2),
          borderRadius: _paperRadius(flipped: !isSelected),
          border: Border.all(
            color: isSelected ? preset.accent : _paperLine,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: preset.accent.withValues(alpha: isSelected ? 0.16 : 0.05),
              blurRadius: isSelected ? 18 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? preset.accent.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.88),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? preset.accent.withValues(alpha: 0.45)
                      : _paperLine.withValues(alpha: 0.7),
                ),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? preset.accent : _paperMuted,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _editorialStyle(
                size: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? preset.accent : _paperInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preset.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _paperMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundThemePicker() {
    final compact = MediaQuery.sizeOf(context).width < 380;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('util_nnnhghp_2dfd7a'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w700,
            color: _paperInk,
            fontSize: 15,
          ),
        ),
        SLSpacing.h8,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _CollageMakerScreenState._backgroundPresets.map((preset) {
              final bool selected = preset.id == _selectedBackgroundTheme;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _selectedBackgroundTheme = preset.id;
                      _generatedCollageBytes = null;
                    });
                    if (_getFilteredUrls().isNotEmpty) {
                      _generateCollage();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: compact ? 112 : 124,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? preset.background
                          : const Color(0xFFFFF9F2),
                      borderRadius: _paperRadius(flipped: !selected),
                      border: Border.all(
                        color: selected ? preset.accent : _paperLine,
                        width: selected ? 2 : 1.2,
                      ),
                      boxShadow: _paperShadow(
                        selected ? preset.accent : _paperCocoa,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: preset.accent.withValues(alpha: 
                                selected ? 0.42 : 0.22,
                              ),
                            ),
                          ),
                          child: Icon(
                            preset.icon,
                            size: 19,
                            color: preset.accent,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          preset.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 13.2,
                            fontWeight: FontWeight.w800,
                            color: selected ? preset.accent : _paperInk,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          preset.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 10.2,
                            fontWeight: FontWeight.w700,
                            color: _paperMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
        SLSpacing.h8,
        Text(
          context.tr('util_mcnhdngnnh_8f83dd'),
          style: SLTheme.quicksand(
            fontSize: 12.2,
            fontWeight: FontWeight.w600,
            color: _paperMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceModeButton({
    required String label,
    required bool selected,
    required bool flipped,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final compactLabel = MediaQuery.sizeOf(context).width < 430;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: SizedBox.expand(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compactLabel ? 6 : 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  style: SLTheme.quicksand(
                    fontSize: compactLabel ? 14 : 15,
                    fontWeight: FontWeight.w800,
                    color: selected ? accent : _paperMuted,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setSourceMode(bool fromMemory) {
    if (_isFromMemory == fromMemory) {
      return;
    }
    setState(() {
      _isFromMemory = fromMemory;
      _generatedCollageBytes = null;
      _hasFullQualityRender = false;
    });
    _scheduleAutoGenerate();
  }

  Widget _buildSourceModeTabs({required bool compact}) {
    final outerRadius = BorderRadius.circular(compact ? 30 : 32);
    final thumbRadius = BorderRadius.circular(compact ? 26 : 28);
    final activeAccent = _isFromMemory ? _paperRoseDeep : _paperMistDeep;
    final controlHeight = compact ? 58.0 : 68.0;

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: double.infinity,
        child: Container(
          height: controlHeight,
          padding: EdgeInsets.all(compact ? 4 : 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF4E9DE),
            borderRadius: outerRadius,
            border: Border.all(
              color: const Color(0xFFDCC9B8).withValues(alpha: 0.96),
              width: 1.2,
            ),
            boxShadow: _paperShadow(),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: _isFromMemory
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _paperShell,
                      borderRadius: thumbRadius,
                      border: Border.all(
                        color: activeAccent.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: activeAccent.withValues(alpha: 0.10),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: _buildSourceModeButton(
                        label: context.tr('util_knim_4f6aeb'),
                        selected: _isFromMemory,
                        flipped: false,
                        accent: _paperRoseDeep,
                        onTap: () => _setSourceMode(true),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 10),
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: _buildSourceModeButton(
                        label: context.tr('util_tchn_0513f1'),
                        selected: !_isFromMemory,
                        flipped: true,
                        accent: _paperMistDeep,
                        onTap: () => _setSourceMode(false),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
