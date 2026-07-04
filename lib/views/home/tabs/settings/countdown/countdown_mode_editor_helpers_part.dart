part of '../../settings_tab.dart';

extension _CountdownModeEditorHelpersPart on _CountdownModeEditorScreenState {
  void _showMessageImpl(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _disposeTemporaryUrlImpl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || !_temporaryUploadedUrls.remove(trimmed)) {
      return;
    }
    unawaited(_storageService.deleteImageByUrl(trimmed));
  }

  void _rememberUploadedUrlImpl({
    required String previousUrl,
    required String nextUrl,
  }) {
    final previous = previousUrl.trim();
    final next = nextUrl.trim();
    if (previous == next) {
      return;
    }
    _disposeTemporaryUrl(previous);
    if (next.isNotEmpty) {
      _temporaryUploadedUrls.add(next);
    }
  }

  void _preserveCurrentUploadsImpl() {
    _temporaryUploadedUrls.remove(_leftAvatarCtrl.text.trim());
    _temporaryUploadedUrls.remove(_rightAvatarCtrl.text.trim());
    _temporaryUploadedUrls.remove(_customBackgroundUrl.trim());
  }

  void _clearBackgroundImageImpl() {
    _disposeTemporaryUrl(_customBackgroundUrl);
    _safeSetState(() {
      _customBackgroundUrl = '';
    });
  }

  InputDecoration _fieldDecorationImpl({
    required String label,
    String? hint,
    bool dark = false,
  }) {
    final fillColor =
        dark ? const Color(0xFF162136) : Colors.white.withValues(alpha: 0.88);
    final labelColor = dark ? Colors.white70 : const Color(0xFF8A5B76);
    final hintColor = dark ? Colors.white38 : const Color(0xFFB9A6B3);
    final borderColor =
        dark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF3CBDD);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: fillColor,
      labelStyle: SLTheme.quicksand(
        color: labelColor,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: SLTheme.quicksand(
        color: hintColor,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Color(0xFFD81B60), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _sectionCardImpl({
    required IconData icon,
    required String title,
    required String subtitle,
    List<Color>? iconGradient,
    required Widget child,
  }) {
    final gradient = iconGradient ??
        const [
          Color(0xFFEC407A),
          Color(0xFFD81B60),
        ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFF8FB),
            Color(0xFFFDF0F6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF8DBE8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.last.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7C6D76),
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Future<void> _pickAnchorDateImpl() async {
    final now = DateTime.now();
    final firstDate = DateTime(1970, 1, 1);
    final lastDate = DateTime(now.year + 5, 12, 31);
    final initialDate = _anchorDate ?? now;
    final picked = await _showAnchorDateInputDialogImpl(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && mounted) {
      _safeSetState(() {
        _anchorDate = picked;
      });
    }
  }

  Future<DateTime?> _showAnchorDateInputDialogImpl({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final dialogInitial = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    final minDate = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final maxDate = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final inputCtrl = TextEditingController(
      text: DateInputUtils.formatDisplayDate(dialogInitial),
    );
    String? errorText;

    bool inRange(DateTime value) {
      return !(value.isBefore(minDate) || value.isAfter(maxDate));
    }

    DateTime? parseInput(String raw) {
      final parsed = DateInputUtils.parse(
        raw,
        firstYear: firstDate.year,
        lastYear: lastDate.year,
        allowMissingYear: true,
        fallbackYear: dialogInitial.year,
      );
      if (parsed == null) {
        return null;
      }
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    String explainError(String raw) {
      final validationError = DateInputUtils.validationError(
        raw,
        firstYear: firstDate.year,
        lastYear: lastDate.year,
        allowMissingYear: true,
        fallbackYear: dialogInitial.year,
      );
      if (validationError != null) return validationError;
      final parsed = parseInput(raw.trim());
      if (parsed == null) {
        return context.tr('home_ngykhnghpl_b660fe');
      }
      if (!inRange(parsed)) {
        return 'Ngày phải trong khoảng ${DateInputUtils.formatDisplayDate(minDate)} - ${DateInputUtils.formatDisplayDate(maxDate)}.';
      }
      return context.tr('home_nhdngchang_9fbba2');
    }

    try {
      return await showDialog<DateTime>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> pickFromCalendar() async {
                final candidate = parseInput(inputCtrl.text);
                final calendarInitial = candidate != null && inRange(candidate)
                    ? candidate
                    : dialogInitial;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: calendarInitial,
                  firstDate: firstDate,
                  lastDate: lastDate,
                );
                if (!context.mounted || !dialogContext.mounted) {
                  return;
                }
                if (picked == null) {
                  return;
                }
                setDialogState(() {
                  errorText = null;
                  inputCtrl.text = DateInputUtils.formatDisplayDate(picked);
                  inputCtrl.selection = TextSelection.collapsed(
                    offset: inputCtrl.text.length,
                  );
                });
              }

              void submit() {
                final parsed = parseInput(inputCtrl.text);
                if (parsed == null || !inRange(parsed)) {
                  setDialogState(() {
                    errorText = explainError(inputCtrl.text);
                  });
                  return;
                }
                inputCtrl.text = DateInputUtils.formatDisplayDate(parsed);
                Navigator.of(dialogContext).pop(parsed);
              }

              return AlertDialog(
                title: Text(
                  context.tr('home_chnngy_d2cce5'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: inputCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: const [FlexibleDateInputFormatter()],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (errorText == null) {
                          return;
                        }
                        setDialogState(() => errorText = null);
                      },
                      onSubmitted: (_) => submit(),
                      onEditingComplete: () {
                        inputCtrl.text = DateInputUtils.normalizeForDisplay(
                          inputCtrl.text,
                          firstYear: firstDate.year,
                          lastYear: lastDate.year,
                          allowMissingYear: true,
                          fallbackYear: dialogInitial.year,
                        );
                        inputCtrl.selection = TextSelection.collapsed(
                          offset: inputCtrl.text.length,
                        );
                      },
                      decoration: InputDecoration(
                        labelText: context.tr('home_nhpngy_91932a'),
                        hintText: context.tr('home_ngythngnm_a697d0'),
                        helperText: context.tr('home_angnhpngyt_377d85'),
                        errorText: errorText,
                        prefixIcon: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFFD81B60),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(context.tr('home_hy_1e4050')),
                  ),
                  TextButton(
                    onPressed: () => unawaited(pickFromCalendar()),
                    child: Text(context.tr('home_chnlch_e1fe3f')),
                  ),
                  ElevatedButton(
                    onPressed: submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD81B60),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(context.tr('ok')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      inputCtrl.dispose();
    }
  }

  _CountdownModeSettingsResult _buildResultImpl(
    _CountdownModeSettingsAction action,
  ) {
    if (action == _CountdownModeSettingsAction.save) {
      _preserveCurrentUploads();
    }
    return _CountdownModeSettingsResult(
      action: action,
      singleMode: _singleMode,
      anchorDate: _anchorDate,
      themeKey: _themeKey,
      styleKey: _styleKey,
      frameKey: _frameKey,
      fontKey: _fontKey,
      transparentMode: _transparentMode,
      sizePx: _sizePx,
      topLabel: _topCtrl.text.trim(),
      bottomLabel: _bottomCtrl.text.trim(),
      nameU1: _leftCtrl.text.trim(),
      nameU2: _rightCtrl.text.trim(),
      avatarUrl1: _leftAvatarCtrl.text.trim(),
      avatarUrl2: _rightAvatarCtrl.text.trim(),
      customBackgroundUrl: _customBackgroundUrl.trim(),
      centerIconType: _centerIconType,
    );
  }

  IconData _countdownThemeSwatchIcon(String key) {
    switch (key) {
      case 'theme-pink-glow':
        return Icons.favorite_rounded;
      case 'theme-default':
        return Icons.wb_sunny_rounded;
      case 'theme-ocean':
        return Icons.waves_rounded;
      case 'theme-sunset':
        return Icons.wb_twilight_rounded;
      case 'theme-night':
        return Icons.nights_stay_rounded;
      case 'theme-dark':
        return Icons.dark_mode_rounded;
      case 'theme-mystic-dark':
        return Icons.auto_awesome_rounded;
      case 'theme-auto':
        return Icons.access_time_filled_rounded;
      default:
        return Icons.block_rounded;
    }
  }

  String _countdownThemeSwatchEmoji(String key) {
    switch (key) {
      case 'theme-pink-glow':
        return '🌸';
      case 'theme-default':
        return '☀️';
      case 'theme-ocean':
        return '🌊';
      case 'theme-sunset':
        return '🌅';
      case 'theme-night':
        return '🌙';
      case 'theme-dark':
        return '🖤';
      case 'theme-mystic-dark':
        return '✨';
      case 'theme-auto':
        return '⏱️';
      default:
        return '🚫';
    }
  }

  Widget _buildCountdownThemeSwatchGrid() {
    final swatches = <(String, List<Color>, String)>[
      (
        'theme-auto',
        [const Color(0xFF64748B), const Color(0xFF334155)],
        _CountdownModeIndependentScreenState._themeOptions
            .firstWhere((o) => o.value == 'theme-auto',
                orElse: () => const MapEntry('Tự động', 'theme-auto'))
            .key
      ),
      (
        'theme-pink-glow',
        [const Color(0xFFFFB6CA), const Color(0xFFFF7098)],
        _CountdownModeIndependentScreenState._themeOptions
            .firstWhere((o) => o.value == 'theme-pink-glow',
                orElse: () => const MapEntry('Sáng hồng', 'theme-pink-glow'))
            .key
      ),
      (
        'theme-default',
        [const Color(0xFFFBC02D), const Color(0xFFF57F17)],
        _CountdownModeIndependentScreenState._themeOptions
            .firstWhere((o) => o.value == 'theme-default',
                orElse: () => const MapEntry('Mặc định', 'theme-default'))
            .key
      ),
      (
        'theme-ocean',
        [const Color(0xFF4FC3F7), const Color(0xFF0288D1)],
        _CountdownModeIndependentScreenState._themeOptions
            .firstWhere((o) => o.value == 'theme-ocean',
                orElse: () => const MapEntry('Đại dương', 'theme-ocean'))
            .key
      ),
      (
        'theme-sunset',
        [const Color(0xFFFF8A65), const Color(0xFFD84315)],
        _CountdownModeIndependentScreenState._themeOptions
            .firstWhere((o) => o.value == 'theme-sunset',
                orElse: () => const MapEntry('Hoàng hôn', 'theme-sunset'))
            .key
      ),
      (
        'theme-night',
        [const Color(0xFF7986CB), const Color(0xFF303F9F)],
        _CountdownModeIndependentScreenState._themeOptions
            .firstWhere((o) => o.value == 'theme-night',
                orElse: () => const MapEntry('Đêm thâu', 'theme-night'))
            .key
      ),
      (
        'theme-dark',
        [const Color(0xFF616161), const Color(0xFF212121)],
        _CountdownModeIndependentScreenState._themeOptions
            .firstWhere((o) => o.value == 'theme-dark',
                orElse: () => const MapEntry('Tối', 'theme-dark'))
            .key
      ),
      (
        'theme-mystic-dark',
        [const Color(0xFFB388FF), const Color(0xFF651FFF)],
        _CountdownModeIndependentScreenState._themeOptions
            .firstWhere((o) => o.value == 'theme-mystic-dark',
                orElse: () =>
                    const MapEntry('Tối huyền bí', 'theme-mystic-dark'))
            .key
      ),
      (
        'off',
        [const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)],
        _CountdownModeIndependentScreenState._themeOptions
            .firstWhere((o) => o.value == 'off',
                orElse: () => const MapEntry('Tắt', 'off'))
            .key
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: swatches.map((swatch) {
        final key = swatch.$1;
        final colors = swatch.$2;
        final label = swatch.$3;
        final isSelected = _themeKey == key;
        final themeIcon = _countdownThemeSwatchIcon(key);
        final themeEmoji = _countdownThemeSwatchEmoji(key);
        final isDarkTheme =
            key.contains('dark') || key == 'theme-night' || key == 'theme-auto';
        final iconColor = isDarkTheme
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.85);

        return GestureDetector(
          onTap: () => setState(() => _themeKey = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? colors.last.withValues(alpha: 0.90)
                    : const Color(0xFFE0E7EF),
                width: isSelected ? 2.2 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.first.withValues(alpha: 0.38),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: colors.last.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.first,
                          Color.lerp(colors.first, colors.last, 0.5)!,
                          colors.last,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Icon(
                            themeIcon,
                            size: 28,
                            color: isDarkTheme
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.20),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 6,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                        if (!isDarkTheme)
                          Positioned(
                            bottom: -22,
                            left: -10,
                            right: -10,
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.elliptical(50, 15),
                                ),
                              ),
                            ),
                          ),
                        Center(
                          child: isSelected
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.92),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.last
                                                .withValues(alpha: 0.30),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: colors.last,
                                      ),
                                    ),
                                  ],
                                )
                              : Icon(
                                  themeIcon,
                                  size: 20,
                                  color: iconColor,
                                ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 5,
                            left: 6,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.90),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [
                                colors.first.withValues(alpha: 0.08),
                                Colors.white,
                              ]
                            : [Colors.white, Colors.white],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Text(
                            themeEmoji,
                            style: const TextStyle(fontSize: 9),
                          ),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              fontSize: 10.4,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: isSelected
                                  ? colors.last
                                  : const Color(0xFF64748B),
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
        );
      }).toList(),
    );
  }
}
