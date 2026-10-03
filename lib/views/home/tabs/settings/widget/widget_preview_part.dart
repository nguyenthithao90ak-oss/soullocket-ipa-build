part of '../../settings_tab.dart';

extension _SettingsTabWidgetPreviewPart on _SettingsTabState {
  ({List<Color> colors, Color textColor, Color borderColor, bool premium})
  _widgetPreviewThemeSpec(String themeKey) {
    final colors =
        WidgetThemeDesign.palettes[WidgetThemeDesign.normalize(themeKey)]!;
    final textColor = switch (themeKey) {
      'pink' => const Color(0xFF333333),
      'white' => const Color(0xFF333333),
      'dark' => const Color(0xFFFFFFFF),
      'blue' => const Color(0xFF0D47A1),
      'orange' => const Color(0xFFE65100),
      'purple' => const Color(0xFF6A1B9A),
      'green' => const Color(0xFF1B5E20),
      'red' => const Color(0xFFFFF0DC),
      'cosmic' => const Color(0xFFFFF0BD),
      'premium' => Colors.white,
      _ => const Color(0xFF333333),
    };
    return (
      colors: colors,
      textColor: textColor,
      borderColor: Colors.white.withValues(alpha: .8),
      premium: themeKey == 'premium',
    );
  }

  List<Color> _widgetHeartPalette(String colorKey) {
    switch (colorKey) {
      case 'ruby':
        return const [Color(0xFFE11D48), Color(0xFFFB7185), Color(0xFFFFE4E6)];
      case 'violet':
        return const [Color(0xFF8B5CF6), Color(0xFFC084FC), Color(0xFFF3E8FF)];
      case 'ocean':
        return const [Color(0xFF0EA5E9), Color(0xFF67E8F9), Color(0xFFE0F2FE)];
      case 'sunset':
        return const [Color(0xFFF97316), Color(0xFFFBBF24), Color(0xFFFFF7ED)];
      case 'gold':
        return const [Color(0xFFEAB308), Color(0xFFFDE68A), Color(0xFFFFFBEA)];
      case 'rose':
      default:
        return const [Color(0xFFFF4D73), Color(0xFFFF8FB1), Color(0xFFFFE4EC)];
    }
  }

  Widget _buildWidgetDiaryPreview(
    Color textColor, {
    double width = 56,
    double height = 84,
  }) {
    if (!_showDiaryOnWidget) {
      return const SizedBox.shrink();
    }

    final houseId = _houseId?.trim();

    if (houseId == null || houseId.isEmpty) {
      return _buildWidgetCenterVisual(textColor);
    }

    return _WidgetDiaryPreviewStream(
      state: this,
      houseId: houseId,
      layoutKey: _widgetDiaryLayoutKey,
      textColor: textColor,
      width: width,
      height: height,
      revision: _widgetMediaRevision,
    );
  }

  Widget _buildWidgetCenterVisual(Color textColor) {
    if (_widgetStickerKey == 'none') {
      return _buildWidgetHeartPreview(textColor, size: 120);
    }
    final twinkle =
        _widgetHeartAnimated &&
        !MediaQuery.disableAnimationsOf(context) &&
        _widgetPreviewTickNotifier.value.isOdd;
    return WidgetStickerArtwork(
      stickerKey: _widgetStickerKey,
      twinkle: twinkle,
    );
  }

  Widget _buildWidgetStickerPicker() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 400 ? 3 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: WidgetAppearance.stickerKeys
            .where((key) => key != 'none')
            .map(
              (key) => SizedBox(
                width: width,
                child: WidgetVisualChoiceTile(
                  key: ValueKey('widget-sticker-$key'),
                  label: context.tr('widget_sticker_$key'),
                  selected: _widgetStickerKey == key && !_showDiaryOnWidget,
                  onTap: () => unawaited(_handleWidgetStickerChanged(key)),
                  artwork: WidgetStickerArtwork(stickerKey: key),
                ),
              ),
            )
            .toList(growable: false),
      );
    },
  );

  Widget _buildWidgetHeartStylePicker() => WidgetHeartStylePicker(
    selectedKey: _widgetHeartStyleKey,
    active: _widgetStickerKey == 'none' && !_showDiaryOnWidget,
    colorLabel: context.tr('widget_heart_colors'),
    symbolLabel: context.tr('widget_heart_symbols'),
    optionLabel: (index) => context
        .tr('p7_heart_style_option')
        .replaceAll('{index}', index.toString()),
    onChanged: (key) => unawaited(_handleWidgetHeartStyleChanged(key)),
  );

  Widget _buildWidgetHeartPreview(Color textColor, {double size = 72}) =>
      SizedBox(
        width: size,
        height: size,
        child: WidgetHeartArtwork(
          styleKey: _normalizeWidgetHeartStyleKey(_widgetHeartStyleKey),
          animated: _widgetHeartAnimated,
          phase: _widgetPreviewTickNotifier.value,
        ),
      );

  String _resolvedWidgetSeasonKey() => WidgetService.resolveSeasonEffect(
    seasonModeKey: _widgetSeasonModeKey,
    loveDate: _loveDate,
    birthday1: _dobU1,
    birthday2: _dobU2,
  );

  List<Color> _widgetSeasonPalette(String key) => switch (key) {
    'valentine' => const [Color(0xFFFF5B8A), Color(0xFFFFC4D6)],
    'anniversary' => const [Color(0xFFFFB84D), Color(0xFFFFE5A8)],
    'birthday' => const [Color(0xFF5B8CFF), Color(0xFF8FE8FF)],
    _ => const [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
  };

  double _widgetPreviewCardWidth(double width) => width;

  Widget _buildPremiumWidgetPreviewAurora(double cardWidth, double cardHeight) {
    final phase = _widgetPreviewTickNotifier.value % 4;
    const firstAlignments = <Alignment>[
      Alignment(-0.9, -0.9),
      Alignment(-0.55, -0.8),
      Alignment(-0.75, -0.35),
      Alignment(-0.5, -0.85),
    ];
    const secondAlignments = <Alignment>[
      Alignment(0.95, -0.15),
      Alignment(0.7, -0.45),
      Alignment(0.95, -0.3),
      Alignment(0.7, -0.1),
    ];
    const thirdAlignments = <Alignment>[
      Alignment(0.15, 1.0),
      Alignment(-0.15, 0.9),
      Alignment(0.3, 0.75),
      Alignment(-0.05, 1.0),
    ];

    Widget blob({
      required Alignment alignment,
      required double size,
      required List<Color> colors,
      required double opacity,
    }) {
      return AnimatedAlign(
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeInOut,
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors.first.withValues(alpha: opacity),
                colors.last.withValues(alpha: opacity * 0.52),
                Colors.transparent,
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
        ),
      );
    }

    final themeKey = _draftWidgetThemeKey ?? 'pink';
    final isCosmic = themeKey == 'cosmic';

    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          blob(
            alignment: firstAlignments[phase],
            size: cardWidth * 0.72,
            colors: isCosmic
                ? const [Color(0xFFFFD700), Color(0xFFB59410)]
                : const [Color(0xFFFF8AB8), Color(0xFFFFB86B)],
            opacity: isCosmic ? 0.35 : 0.54,
          ),
          blob(
            alignment: secondAlignments[phase],
            size: cardWidth * 0.62,
            colors: isCosmic
                ? const [Color(0xFFFDE68A), Color(0xFFFFB86B)]
                : const [Color(0xFF8AE7FF), Color(0xFF6D7CFF)],
            opacity: isCosmic ? 0.28 : 0.48,
          ),
          blob(
            alignment: thirdAlignments[phase],
            size: cardHeight * 0.98,
            colors: isCosmic
                ? const [Color(0xFFFFFBEB), Color(0xFFEAB308)]
                : const [Color(0xFFFFD38A), Color(0xFFCE8BFF)],
            opacity: isCosmic ? 0.22 : 0.34,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          if (isCosmic) ...[
            Positioned(
              top: cardHeight * 0.15,
              left: cardWidth * 0.2,
              child: Icon(
                Icons.star_rounded,
                size: 8,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Positioned(
              top: cardHeight * 0.3,
              right: cardWidth * 0.25,
              child: Icon(
                Icons.star_rounded,
                size: 6,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            Positioned(
              bottom: cardHeight * 0.2,
              left: cardWidth * 0.3,
              child: Icon(
                Icons.star_rounded,
                size: 7,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            Positioned(
              bottom: cardHeight * 0.15,
              right: cardWidth * 0.15,
              child: Icon(
                Icons.star_rounded,
                size: 5,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
          Positioned(
            top: cardHeight * 0.16,
            right: cardWidth * 0.16,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: cardWidth * 0.06,
              color: isCosmic
                  ? const Color(0xFFFFD700).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSWidgetStatusPreview(String name1, String name2, Color color) {
    return StableFutureBuilder<List<String>>(
      requestKey: (_auth.currentUser?.uid, _houseId, _widgetMediaRevision),
      load: () async {
        if (kIsWeb || !Platform.isIOS) return ['', ''];
        return [
          await HomeWidget.getWidgetData<String>('status1') ?? '',
          await HomeWidget.getWidgetData<String>('status2') ?? '',
        ];
      },
      builder: (context, snapshot) {
        final values = snapshot.data ?? ['', ''];
        Widget person(String name, String status) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                status.isEmpty ? context.tr('home_angoffline_bbb3d5') : status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 10,
                  color: color.withValues(alpha: .8),
                ),
              ),
            ],
          ),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              person(name1, values[0]),
              const SizedBox(width: 8),
              person(name2, values[1]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWidgetPreview() {
    return ValueListenableBuilder<int>(
      valueListenable: _widgetPreviewTickNotifier,
      builder: (context, _, _) {
        final themeKey = _draftWidgetThemeKey ?? 'pink';
        final theme = _widgetPreviewThemeSpec(themeKey);
        final textColor = theme.textColor;
        final heartPalette = _widgetHeartPalette(_widgetHeartColorKey);
        final seasonKey = _resolvedWidgetSeasonKey();
        final seasonPalette = _widgetSeasonPalette(seasonKey);
        final accentColor = seasonKey == 'none'
            ? heartPalette.first
            : seasonPalette.first;
        final dark = const [
          'dark',
          'premium',
          'cosmic',
          'red',
        ].contains(themeKey);
        final daysBase = switch (themeKey) {
          'white' => const Color(0xFF9B335E),
          'blue' => const Color(0xFF0F52BA),
          'orange' => const Color(0xFFF97316),
          'purple' => const Color(0xFF8B5CF6),
          'green' => const Color(0xFF16A34A),
          'red' => const Color(0xFFFFE1AB),
          'dark' || 'premium' => Colors.white,
          'cosmic' => const Color(0xFFFFE396),
          _ => const Color(0xFFFF4D73),
        };
        final softAccent = seasonKey == 'none'
            ? Color.lerp(heartPalette[1], Colors.white, .38)!
            : seasonPalette[1];
        final daysColor = Color.lerp(
          daysBase,
          dark ? softAccent : accentColor,
          dark ? .28 : .36,
        )!;
        final days = _loveDayCounter();
        final label1 = _nameU1.trim().isEmpty
            ? context.tr('role_male')
            : _nameU1.trim();
        final label2 = _nameU2.trim().isEmpty
            ? context.tr('role_female')
            : _nameU2.trim();
        final showDiaryPreview = _showDiaryOnWidget;
        final isCountdownStyle = _widgetStyleKey == 'countdown';
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
                constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 340.0;
            final cardWidth = _widgetPreviewCardWidth(maxWidth);
            final isCompact = cardWidth < 320;
            final isSoulEventStyle = _widgetPanelTabKey == 'soulevent';
            if (isSoulEventStyle) {
              final widgetHeight = (cardWidth * (isCompact ? 0.56 : 0.52))
                  .clamp(176.0, 228.0)
                  .toDouble();

              return StableFutureBuilder<Map<String, String>>(
                requestKey: (
                  _auth.currentUser?.uid,
                  _houseId,
                  _widgetMediaRevision,
                  Localizations.localeOf(context).toLanguageTag(),
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                ),
                load: _loadSoulEventPreviewDataInternal,
                builder: (context, snapshot) {
                  if (!snapshot.hasData &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox(
                      height: widgetHeight,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  final data = snapshot.data ?? _emptySoulEventPreviewData();

                  final colorHex = data['color']!;
                  Color eventColor;
                  try {
                    final buffer = StringBuffer();
                    if (colorHex.length == 6 || colorHex.length == 7) {
                      buffer.write('ff');
                    }
                    buffer.write(colorHex.replaceFirst('#', ''));
                    eventColor = Color(int.parse(buffer.toString(), radix: 16));
                  } catch (_) {
                    eventColor = const Color(0xFFEC4899);
                  }

                  final eventTitle = data['title']!;
                  final eventDate = data['date']!;
                  final eventDays = data['days']!;
                  final eventLabel = data['label']!;

                  return WidgetIOSEventPreview(
                    sizeKey: _widgetPreviewSizeKey,
                    heading: context.tr('p8_events_title'),
                    title: eventTitle,
                    days: eventDays,
                    label: eventLabel,
                    date: eventDate,
                    accent: eventColor,
                    themeKey: themeKey,
                    animated: _widgetHeartAnimated,
                  );
                },
              );
            }

            return WidgetCouplePreview(
              sizeKey: _widgetPreviewSizeKey,
              colors: theme.colors,
              textColor: textColor,
              daysColor: daysColor,
              heading: context.tr('countdown_couple_mode'),
              days: '$days',
              unit: _loveUnit.trim().isEmpty
                  ? context.tr('p7_day_lowercase')
                  : _loveUnit.trim(),
              name1: label1,
              name2: label2,
              avatar1: _avatarUrl1,
              avatar2: _avatarUrl2,
              countdown: isCountdownStyle,
              loveDate: _loveDate,
              themeKey: themeKey,
              themeAnimated: _widgetHeartAnimated,
              footer: Theme.of(context).platform == TargetPlatform.iOS
                  ? _buildIOSWidgetStatusPreview(label1, label2, textColor)
                  : null,
              dark: const [
                'dark',
                'premium',
                'cosmic',
                'red',
              ].contains(themeKey),
              center: showDiaryPreview && !isCountdownStyle
                  ? _buildWidgetDiaryPreview(
                      textColor,
                      width: 120,
                      height: 98.4,
                    )
                  : _buildWidgetCenterVisual(textColor),
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>> _loadSoulEventPreviewDataInternal() async {
    final emptyData = _emptySoulEventPreviewData();
    final todayLabel = context.tr('p7_today_upper');
    final daysRemainingLabel = context.tr('p7_days_remaining');
    final houseId = _houseId ?? '';
    if (houseId.isEmpty) {
      return emptyData;
    }

    try {
      // Mobile xem đúng snapshot native, gồm cả sự kiện tùy chỉnh đã lưu.
      // Không tạo thêm truy vấn mạng chỉ để dựng lại mẫu trong Cài đặt.
      if (WidgetService.supportsMobileWidgets) {
        await WidgetService.ensureInitialized();
        final hasEvent =
            await HomeWidget.getWidgetData<bool>('se_has_event') ?? false;
        if (!hasEvent) return emptyData;
        final targetKey =
            await HomeWidget.getWidgetData<String>('se_target_date') ?? '';
        final target = DateTime.tryParse(targetKey);
        final remaining = target == null
            ? null
            : SoulEvent.daysBetween(target, DateTime.now());
        return {
          'title':
              await HomeWidget.getWidgetData<String>('se_title') ??
              emptyData['title']!,
          'date':
              await HomeWidget.getWidgetData<String>('se_date') ??
              emptyData['date']!,
          'days': remaining == null || remaining < 0
              ? '—'
              : remaining == 0
              ? context.tr('p8_events_today_upper')
              : '$remaining',
          'label': remaining == 0
              ? '✦'
              : context.tr('p8_events_days_remaining_label'),
          'color':
              await HomeWidget.getWidgetData<String>('se_color') ?? '#984C36',
        };
      }
      final events = await SoulEventService().getEvents(houseId);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      SoulEvent? topEvent;
      int minDays = 99999;

      for (final event in events) {
        if (!event.isPinned) continue;
        final nextDate = event.calculateNextOccurrence(today);
        if (nextDate != null) {
          final diff = nextDate.difference(today).inDays;
          if (diff >= 0 && diff < minDays) {
            minDays = diff;
            topEvent = event;
          }
        }
      }

      if (topEvent == null && events.isNotEmpty) {
        for (final event in events) {
          final nextDate = event.calculateNextOccurrence(today);
          if (nextDate != null) {
            final diff = nextDate.difference(today).inDays;
            if (diff >= 0 && diff < minDays) {
              minDays = diff;
              topEvent = event;
            }
          }
        }
      }

      if (topEvent != null) {
        final nextDate = topEvent.calculateNextOccurrence(today)!;
        final isToday = nextDate.isAtSameMomentAs(today);
        final dateStr =
            '${nextDate.day.toString().padLeft(2, '0')}/${nextDate.month.toString().padLeft(2, '0')}/${nextDate.year}';
        final colorHex = topEvent.colorHex.isNotEmpty
            ? topEvent.colorHex
            : '#EC4899';

        return {
          'title': topEvent.title,
          'date': dateStr,
          'days': isToday ? todayLabel : minDays.toString(),
          'label': isToday ? '🎉' : daysRemainingLabel,
          'color': colorHex,
        };
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/home/tabs/settings/widget/widget_preview_part.dart: $error',
      );
    }

    return emptyData;
  }

  Map<String, String> _emptySoulEventPreviewData() {
    return {
      'title': context.tr('p7_no_upcoming_event'),
      'date': '--/--/----',
      'days': '0',
      'label': context.tr('p7_days_remaining'),
      'color': '#EC4899',
    };
  }
}

class _WidgetDiaryPreviewStream extends StatefulWidget {
  const _WidgetDiaryPreviewStream({
    required this.state,
    required this.houseId,
    required this.layoutKey,
    required this.textColor,
    required this.width,
    required this.height,
    required this.revision,
  });

  final _SettingsTabState state;
  final String houseId;
  final String layoutKey;
  final Color textColor;
  final double width;
  final double height;
  final int revision;

  @override
  State<_WidgetDiaryPreviewStream> createState() =>
      _WidgetDiaryPreviewStreamState();
}

class _WidgetDiaryPreviewStreamState extends State<_WidgetDiaryPreviewStream> {
  static const double _outerRadius = 18;

  late Future<List<String>> _imageUrlsFuture;
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  @override
  void didUpdateWidget(covariant _WidgetDiaryPreviewStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId ||
        oldWidget.revision != widget.revision) {
      _updateStream();
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _updateStream() {
    _imageUrlsFuture = _loadPreviewImages();
  }

  Future<List<String>> _loadPreviewImages() async {
    if (WidgetService.supportsMobileWidgets) {
      final raw = await HomeWidget.getWidgetData<String>(
        'diaryImagePaths',
        defaultValue: '[]',
      );
      final paths = (jsonDecode(raw ?? '[]') as List).whereType<String>();
      return paths
          .where((path) => File(path).existsSync())
          .toList(growable: false);
    }
    return widget.state._loadWidgetDiaryUrls(limit: 12);
  }

  Widget _buildEmptyPreview() =>
      widget.state._buildWidgetCenterVisual(widget.textColor);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _imageUrlsFuture,
    builder: (context, snapshot) {
      final paths = snapshot.data ?? const <String>[];
      if (paths.isEmpty) return _buildEmptyPreview();
      Widget image(String path) => WidgetService.supportsMobileWidgets
          ? Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildEmptyPreview(),
            )
          : CachedNetworkImage(
              imageUrl: path,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _buildEmptyPreview(),
            );
      return WidgetPhotoCollage(
        images: paths.take(4).map(image).toList(),
        layoutKey: widget.layoutKey,
        frameKey: widget.state._widgetPhotoFrameKey,
        frameColor: widget.state._widgetHeartPalette(
          widget.state._widgetHeartColorKey,
        )[1],
        stickerKey: widget.state._widgetStickerKey,
      );
    },
  );
}
