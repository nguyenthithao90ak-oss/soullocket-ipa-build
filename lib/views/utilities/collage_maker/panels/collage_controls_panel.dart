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
        'label': context.tr('collage_preset_feed'),
        'hint': '4:5',
        'style': 'grid',
        'aspect': '4:5',
        'icon': Icons.grid_view_rounded,
      },
      {
        'label': context.tr('ui_utilities_album_dfb4c9'),
        'hint': '1:1',
        'style': 'polaroid',
        'aspect': '1:1',
        'icon': Icons.photo_album_rounded,
      },
      {
        'label': context.tr('collage_poster_preset'),
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
          _buildSectionHeading(
            step: '2',
            title: context.tr('ui_utilities_quick_presets_a60c8b'),
            icon: Icons.auto_awesome_mosaic_rounded,
            subtitle: context.tr('collage_subtitle'),
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
                           _buildQuickPresetPreview(
                             style: style,
                             icon: icon,
                             selected: selected,
                           ),
                           const SizedBox(height: 8),
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

  Widget _buildQuickPresetPreview({
    required String style,
    required IconData icon,
    required bool selected,
  }) {
    final accent = selected ? _paperRoseDeep : _paperMuted;
    final soft = selected
        ? _paperRoseDeep.withValues(alpha: 0.22)
        : _paperMist.withValues(alpha: 0.42);
    final image = BoxDecoration(
      color: soft,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: accent.withValues(alpha: 0.42)),
    );

    List<Widget> blocks;
    switch (style) {
      case 'story':
        blocks = [
          Positioned(left: 16, top: 3, bottom: 3, width: 24, child: DecoratedBox(decoration: image)),
          Positioned(left: 44, top: 9, right: 9, height: 12, child: DecoratedBox(decoration: image)),
          Positioned(left: 44, bottom: 9, right: 9, height: 12, child: DecoratedBox(decoration: image)),
        ];
        break;
      case 'poster':
        blocks = [
          Positioned(left: 6, top: 7, right: 6, height: 18, child: DecoratedBox(decoration: image)),
          Positioned(left: 14, bottom: 6, width: 25, height: 8, child: DecoratedBox(decoration: image)),
          Positioned(right: 14, bottom: 6, width: 25, height: 8, child: DecoratedBox(decoration: image)),
        ];
        break;
      case 'polaroid':
        blocks = [
          Positioned(left: 9, top: 7, width: 25, height: 24, child: DecoratedBox(decoration: image)),
          Positioned(right: 9, top: 11, width: 25, height: 24, child: DecoratedBox(decoration: image)),
        ];
        break;
      case 'heart':
        blocks = [
          Positioned(left: 17, top: 6, width: 20, height: 18, child: DecoratedBox(decoration: image)),
          Positioned(right: 17, top: 6, width: 20, height: 18, child: DecoratedBox(decoration: image)),
          Positioned(left: 25, bottom: 4, width: 20, height: 17, child: DecoratedBox(decoration: image)),
        ];
        break;
      default:
        blocks = [
          Positioned(left: 7, top: 6, width: 22, height: 13, child: DecoratedBox(decoration: image)),
          Positioned(right: 7, top: 6, width: 22, height: 13, child: DecoratedBox(decoration: image)),
          Positioned(left: 7, bottom: 6, width: 22, height: 13, child: DecoratedBox(decoration: image)),
          Positioned(right: 7, bottom: 6, width: 22, height: 13, child: DecoratedBox(decoration: image)),
        ];
    }

    return SizedBox(
      width: 76,
      height: 42,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
            ),
          ),
          ...blocks,
          Positioned(
            right: 3,
            bottom: 2,
            child: Icon(icon, size: 11, color: accent.withValues(alpha: 0.85)),
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
    return const SizedBox.shrink();
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
                              color: preset.accent.withValues(
                                alpha: selected ? 0.42 : 0.22,
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

  /// Đơn giản — 2 nút: chọn từ máy / chọn từ kỷ niệm
  Widget _buildSimplePhotoSource({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: _paperPanelDecoration(
        color: const Color(0xFFFFF8F2),
        borderColor: const Color(0xFFDCC9B8),
        flipped: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeading(
            step: '1',
            title: L10nService().translate('util_chnnh_719c35'),
            icon: Icons.add_photo_alternate_rounded,
            subtitle: context.tr(
              'ui_utilities_add_photos_from_your_library_or_choose_2e234c',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSourceModeButton(
                  useMemory: true,
                  icon: Icons.auto_stories_rounded,
                  label: context.tr('home_nhknim_6f622f'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSourceModeButton(
                  useMemory: false,
                  icon: Icons.photo_library_rounded,
                  label: context.tr('ui_utilities_choose_from_device_131ca4'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isFromMemory
                ? _buildMemorySourceOptions(compact: compact)
                : _buildDeviceSourceOptions(compact: compact),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceModeButton({
    required bool useMemory,
    required IconData icon,
    required String label,
  }) {
    final selected = _isFromMemory == useMemory;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchCollageSource(useMemory),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? _paperRoseDeep.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _paperRoseDeep : _paperLine,
            width: selected ? 1.8 : 1.1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? _paperRoseDeep : _paperMuted,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  color: selected ? _paperRoseDeep : _paperInk,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: _paperRoseDeep,
                size: 17,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemorySourceOptions({required bool compact}) {
    final hasPhotos = _memoryPhotos.isNotEmpty;
    return Container(
      key: const ValueKey('memory-source-options'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EFE5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _paperLine.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.collections_bookmark_rounded,
                color: _paperRoseDeep,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _allMemoryPhotosLabel(),
                  style: SLTheme.quicksand(
                    color: _paperInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildMemoryInfoChip(
                icon: Icons.cloud_done_rounded,
                label: hasPhotos
                    ? context.tr('memory_puzzle_cached')
                    : context.tr('util_0nh_e58f05'),
                highlighted: hasPhotos,
              ),
            ],
          ),
          if (_availableMonths.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('collage_choose_time'),
              style: SLTheme.quicksand(
                color: _paperMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildMemoryMonthChip(
                    keyValue: 'all',
                    label: _allMemoryPhotosLabel(),
                  ),
                  ..._availableMonths.map(
                    (month) => _buildMemoryMonthChip(
                      keyValue: month,
                      label: _monthMenuLabel(
                        month,
                        _memoryPhotos.where((item) {
                          final ts = item['ts'] as int? ?? 0;
                          if (ts == 0) return false;
                          final date = DateTime.fromMillisecondsSinceEpoch(ts);
                          return '${date.year}-${date.month.toString().padLeft(2, '0')}' == month;
                        }).length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            context.tr('ui_utilities_choose_2_to_9_photos_choose_a_a76a0d'),
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              color: _paperMuted,
              fontSize: 11.2,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryMonthChip({required String keyValue, required String label}) {
    final selected = _selectedMonth == keyValue;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) {
          if (_selectedMonth == keyValue) return;
          setState(() {
            _selectedMonth = keyValue;
            _markCollagePreviewDirty();
          });
          _scheduleAutoGenerate(immediate: true);
        },
        selectedColor: _paperRoseDeep,
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        side: BorderSide(color: selected ? _paperRoseDeep : _paperLine),
        labelStyle: SLTheme.quicksand(
          color: selected ? Colors.white : _paperInk,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildDeviceSourceOptions({required bool compact}) {
    final count = _deviceFiles.length;
    return Container(
      key: const ValueKey('device-source-options'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EFE5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _paperLine.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            count == 0
                ? context.tr('collage_tap_select_photos')
                : context.tr('collage_selected_photo_count').replaceAll('{count}', '$count'),
            style: SLTheme.quicksand(
              color: _paperInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          _buildSourceButton(
            icon: Icons.add_photo_alternate_rounded,
            label: context.tr('ui_utilities_choose_from_device_131ca4'),
            onTap: _pickDevicePhotos,
            accent: _paperRoseDeep,
          ),
          const SizedBox(height: 7),
          Text(
            context.tr('home_nhxemtrcsc_3818ff'),
            textAlign: TextAlign.center,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              color: _paperMuted,
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _paperLine),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(height: 5),
            Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _paperInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
