part of '../../settings_tab.dart';
// ignore_for_file: dead_code, unused_element

extension _CountdownModeIndependentScreenViewPart
    on _CountdownModeIndependentScreenState {
  String _resolveThemeKey(String rawKey) {
    final key = rawKey.trim();
    if (key.isNotEmpty && key != 'theme-auto') return key;
    final now = DateTime.now();
    if (now.hour >= 19 || now.hour < 5) return 'theme-night';
    switch (now.month) {
      case 6:
      case 7:
      case 8:
        return 'theme-ocean';
      case 9:
      case 10:
      case 11:
        return 'theme-sunset';
      default:
        return 'theme-pink-glow';
    }
  }

  Color _titleColor(_CountdownModeThemeData themeData) {
    return themeData.isDark ? Colors.white : const Color(0xFF263242);
  }

  Color _subtitleColor(_CountdownModeThemeData themeData) {
    return themeData.isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF8A94A6);
  }

  Color _surfaceFillColor(_CountdownModeThemeData themeData) {
    if (themeData.isDark) {
      return Colors.white.withValues(alpha: 0.12);
    }
    switch (UiPrefs.notifier.value.homeBlockToneKey) {
      case 'mist':
        return const Color(0xFFF7FBFF).withValues(alpha: 0.78);
      case 'rose':
        return const Color(0xFFFFF2F7).withValues(alpha: 0.80);
      case 'glass':
        return Colors.white.withValues(alpha: 0.66);
      default:
        return Colors.white.withValues(alpha: 0.78);
    }
  }

  Color _surfaceBorderColor(_CountdownModeThemeData themeData) {
    if (themeData.isDark) {
      return Colors.white.withValues(alpha: 0.18);
    }
    switch (UiPrefs.notifier.value.homeBlockToneKey) {
      case 'mist':
        return const Color(0xFFE3F2FD).withValues(alpha: 0.86);
      case 'rose':
        return const Color(0xFFF8D7E4).withValues(alpha: 0.86);
      case 'glass':
        return Colors.white.withValues(alpha: 0.72);
      default:
        return Colors.white.withValues(alpha: 0.72);
    }
  }

  Color _surfaceShadowColor(_CountdownModeThemeData themeData) {
    if (themeData.isDark) {
      return Colors.black.withValues(alpha: 0.22);
    }
    switch (UiPrefs.notifier.value.homeBlockToneKey) {
      case 'mist':
        return const Color(0xFF64B5F6).withValues(alpha: 0.08);
      case 'rose':
        return const Color(0xFFD94C86).withValues(alpha: 0.08);
      case 'glass':
        return Colors.white.withValues(alpha: 0.06);
      default:
        return const Color(0xFFD94C86).withValues(alpha: 0.08);
    }
  }

  Widget _surface({
    required _CountdownModeThemeData themeData,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _surfaceFillColor(themeData),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _surfaceBorderColor(themeData),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: _surfaceShadowColor(themeData),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  int _pulseMetric(int seed, int min, int max) {
    final days = _anchorDate == null ? 0 : _daysSince(_anchorDate!);
    final spread = max - min;
    if (spread <= 0) return min;
    final value =
        (days * 7 + DateTime.now().day * 13 + seed * 17) % (spread + 1);
    return min + value;
  }

  Widget _buildPulseCard(_CountdownModeThemeData themeData) {
    final subtitleColor = _subtitleColor(themeData);
    final metrics = <({String label, int value, Color color})>[
      (
        label: context.tr('home_mp_84d641'),
        value: _pulseMetric(1, 72, 96),
        color: const Color(0xFFD94C86)
      ),
      (
        label: context.tr('home_ktni_74e82a'),
        value: _pulseMetric(2, 68, 94),
        color: const Color(0xFF4BA7FF)
      ),
      (
        label: context.tr('home_nhnhung_cf22ff'),
        value: _pulseMetric(3, 60, 90),
        color: const Color(0xFF8C7BFF)
      ),
    ];

    return _surface(
      themeData: themeData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFD94C86),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _singleMode ? context.tr('home_tngquanhmn_0e1b6b') : context.tr('home_hnhtrnhiqu_cbcf59'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: const Color(0xFFD94C86),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _singleMode
                ? context.tr('home_gilikhitng_b1ed7c')
                : context.tr('home_gilikhitng_0bfb93'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: subtitleColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final children = metrics
                  .map(
                    (metric) => Container(
                      width: compact ? (constraints.maxWidth - 8) / 2 : null,
                      height: compact ? 104 : 112,
                      margin: EdgeInsets.symmetric(
                        horizontal: compact ? 0 : 4,
                        vertical: compact ? 4 : 0,
                      ),
                      padding: EdgeInsets.fromLTRB(
                        compact ? 8 : 10,
                        12,
                        compact ? 8 : 10,
                        12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: themeData.isDark ? 0.08 : 0.60),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(
                              alpha: themeData.isDark ? 0.12 : 0.82),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: metric.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${metric.value}',
                              style: SLTheme.quicksand(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: metric.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            metric.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: compact ? 10.5 : 11,
                              fontWeight: FontWeight.w800,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList();

              if (!compact) {
                return Row(
                  children:
                      children.map((child) => Expanded(child: child)).toList(),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 0,
                children: children,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color foreground,
    required bool isDark,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.94),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: foreground, size: 22),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: tooltip,
      child: child,
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    _CountdownModeThemeData themeData,
    _CountdownModeStyleData styleData,
    BoxConstraints viewportConstraints,
  ) {
    final responsiveCircleMax = (viewportConstraints.maxWidth - 44)
        .clamp(280.0, UiPrefs.maxCountdownSizePx);
    final circleSize = (_countdownSizePx < responsiveCircleMax
            ? _countdownSizePx
            : responsiveCircleMax)
        .clamp(280.0, UiPrefs.maxCountdownSizePx)
        .roundToDouble();
    final value =
        _anchorDate == null ? '--' : _daysSince(_anchorDate!).toString();
    final titleColor = _titleColor(themeData);
    final subtitleColor = _subtitleColor(themeData);
    final isAccepted = _acceptedSpaceHouseIds
        .contains(_openedSpaceHouseId ?? _selfSpaceHouseId);
    final statusColor =
        isAccepted ? const Color(0xFF4BA7FF) : const Color(0xFFFFB74D);

    return Column(
      children: [
        if (false)
          Text(
            _spaceTitle(_openedSpaceHouseId ?? _selfSpaceHouseId),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
        if (false) const SizedBox(height: 8),
        if (false)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.22)),
            ),
            child: Text(
              isAccepted ? context.tr('home_ghpni_369328') : context.tr('home_chghpni_0a2955'),
              style: SLTheme.quicksand(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
          ),
        const SizedBox(height: 18),
        Column(
          children: [
            Center(
              child: SizedBox(
                width: circleSize,
                height: circleSize,
                child: _CountdownModeCircle(
                  size: circleSize,
                  value: value,
                  topLabel: _topLabel(),
                  bottomLabel: _bottomLabel(),
                  styleData: styleData,
                  fontKey: _fontKey,
                  onTopTap: () => _editCountdownLabel(
                    editTopLabel: true,
                  ),
                  onValueTap: _pickAnchorDate,
                  onBottomTap: () => _editCountdownLabel(
                    editTopLabel: false,
                  ),
                ),
              ),
            ),
            if (_anchorDate != null) const SizedBox(height: 16),
            if (_anchorDate != null) _buildLoveTimeCounters(),
          ],
        ),
        if (false) const SizedBox(height: 16),
        if (false)
          Text(
            _caption(context),
            textAlign: TextAlign.center,
            style: SLTheme.textStyleForKey(
              _fontKey,
              color: subtitleColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        if (false) const SizedBox(height: 10),
        if (false)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: themeData.isDark ? 0.08 : 0.56),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white
                    .withValues(alpha: themeData.isDark ? 0.10 : 0.86),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_calendar_rounded,
                  size: 16,
                  color: Color(0xFFD94C86),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.tr('home_chmvovngms_d76e82'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLoveTimeCounters() {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (tick) => tick),
      initialData: 0,
      builder: (context, snapshot) {
        final detail = _loveTimeDetail(_anchorDate);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLoveTimeCell(value: detail['h']!, label: context.tr('home_gi_770f40')),
            const SizedBox(width: 8),
            _buildLoveTimeCell(
              value: detail['m']!,
              label: context.tr('home_pht_06b001'),
              alternate: true,
            ),
            const SizedBox(width: 8),
            _buildLoveTimeCell(value: detail['s']!, label: context.tr('home_giy_392758')),
          ],
        );
      },
    );
  }

  Map<String, String> _loveTimeDetail(DateTime? anchorDate) {
    if (anchorDate == null) {
      return const {'h': '00', 'm': '00', 's': '00'};
    }

    final difference = DateTime.now().difference(anchorDate);
    if (difference.isNegative) {
      return const {'h': '00', 'm': '00', 's': '00'};
    }

    return {
      'h': (difference.inHours % 24).toString().padLeft(2, '0'),
      'm': (difference.inMinutes % 60).toString().padLeft(2, '0'),
      's': (difference.inSeconds % 60).toString().padLeft(2, '0'),
    };
  }

  Widget _buildLoveTimeCell({
    required String value,
    required String label,
    bool alternate = false,
  }) {
    return Container(
      width: 74,
      height: 72,
      decoration: BoxDecoration(
        color: _transparentMode
            ? Colors.white.withValues(alpha: 0.80)
            : Colors.white.withValues(alpha: 0.95),
        gradient: _transparentMode
            ? null
            : LinearGradient(
                colors: alternate
                    ? [
                        const Color(0xFFFFFAFC).withValues(alpha: 0.70),
                        const Color(0xFFFFECF6).withValues(alpha: 0.70),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.70),
                        const Color(0xFFEEF5FF).withValues(alpha: 0.70),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.40), width: 1),
        boxShadow: _transparentMode
            ? const []
            : [
                BoxShadow(
                  color: (alternate
                          ? const Color(0xFFD81B60)
                          : const Color(0xFF2563EB))
                      .withValues(alpha: 0.10),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _handleOpenedSpaceBack() async {
    if (_openedSpaceHouseId == null) {
      return true;
    }

    await _closeOpenedSpace();
    return false;
  }

  Future<void> _openSettingsSheet() async {
    final currentSpaceId = (_openedSpaceHouseId ?? _selfSpaceHouseId).trim();
    final sharedSpace = _sharedSpaceFor(currentSpaceId);
    final deleteRequest = _deleteRequestFor(currentSpaceId);
    final result =
        await Navigator.of(context).push<_CountdownModeSettingsResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CountdownModeEditorScreen(
          currentHouseId: widget.currentHouseId,
          isVipActive: widget.isVipActive,
          spaceTitle: _spaceTitle(currentSpaceId),
          isAccepted: _acceptedSpaceHouseIds.contains(currentSpaceId),
          showDeleteSection:
              currentSpaceId != _selfSpaceHouseId && sharedSpace != null,
          canRequestDelete: currentSpaceId != _selfSpaceHouseId &&
              sharedSpace != null &&
              deleteRequest == null,
          canAcceptDelete: deleteRequest != null &&
              !deleteRequest.isRequestedBy(_selfSpaceHouseId),
          deleteStatusTitle: _deleteStatusTitle(currentSpaceId),
          deleteStatusDescription: _deleteStatusDescription(currentSpaceId),
          singleMode: _singleMode,
          anchorDate: _anchorDate,
          themeKey: _themeKey,
          styleKey: _countdownStyleKey,
          frameKey: _avatarFrameKey,
          fontKey: _fontKey,
          transparentMode: _transparentMode,
          sizePx: _countdownSizePx,
          topLabel: _topLabelText,
          bottomLabel: _bottomLabelText,
          nameU1: _nameU1,
          nameU2: _nameU2,
          avatarUrl1: _avatarUrl1,
          avatarUrl2: _avatarUrl2,
          customBackgroundUrl: _customBackgroundUrl,
          centerIconType: _centerIconType,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    if (result.action == _CountdownModeSettingsAction.requestDeleteSpace) {
      await _setSystemUiVisible(true);
      await _requestDeleteCurrentSpace(currentSpaceId);
      return;
    }

    if (result.action == _CountdownModeSettingsAction.acceptDeleteSpace) {
      await _setSystemUiVisible(true);
      await _acceptDeleteCurrentSpace(currentSpaceId);
      return;
    }

    if (result.action == _CountdownModeSettingsAction.save) {
      _safeSetState(() {
        _singleMode = result.singleMode;
        _anchorDate = result.anchorDate;
        _themeKey = result.themeKey;
        _countdownStyleKey = result.styleKey;
        _avatarFrameKey = result.frameKey;
        _fontKey = result.fontKey;
        _transparentMode = result.transparentMode;
        _countdownSizePx = result.sizePx;
        _topLabelText = result.topLabel;
        _bottomLabelText = result.bottomLabel;
        _nameU1 = result.nameU1;
        _nameU2 = result.nameU2;
        _avatarUrl1 = result.avatarUrl1;
        _avatarUrl2 = result.avatarUrl2;
        _customBackgroundUrl = result.customBackgroundUrl;
        _centerIconType = result.centerIconType;
        _spaceChromeVisible = true;
      });
      await _saveLocalSettings();
      if (mounted) _showMessage(context.tr('home_lukhnggian_5e7d0a'));
      return;
    }

    if (result.action == _CountdownModeSettingsAction.backToSpaces) {
      _safeSetState(() {
        _openedSpaceHouseId = null;
        _spaceChromeVisible = true;
        _applySnapshot(_spaceSnapshotFor(_selfSpaceHouseId));
      });
      await _setSystemUiVisible(true);
      return;
    }

    await _setSystemUiVisible(true);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _openSettingsSheetLegacy() async {
    final topCtrl = TextEditingController(text: _topLabelText);
    final bottomCtrl = TextEditingController(text: _bottomLabelText);
    final leftCtrl = TextEditingController(text: _nameU1);
    final rightCtrl = TextEditingController(text: _nameU2);
    final leftAvatarCtrl = TextEditingController(text: _avatarUrl1);
    final rightAvatarCtrl = TextEditingController(text: _avatarUrl2);

    var draftSingleMode = _singleMode;
    var draftDate = _anchorDate;
    var draftThemeKey = _themeKey;
    var draftStyleKey = _countdownStyleKey;
    var draftFrameKey = _avatarFrameKey;
    var draftFontKey = _fontKey;
    var draftTransparent = _transparentMode;
    var draftSize = _countdownSizePx;

    final result = await showModalBottomSheet<_CountdownModeSettingsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 12,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1A2D),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.of(sheetContext).size.width < 360 ? 14 : 18,
                      18,
                      MediaQuery.of(sheetContext).size.width < 360 ? 14 : 18,
                      18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.tr('home_citkhnggia_09f866'),
                                style: SLTheme.quicksand(
                                  fontSize:
                                      MediaQuery.of(sheetContext).size.width <
                                              360
                                          ? 16
                                          : 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: topCtrl,
                          decoration: _sheetDecoration(
                            label: context.tr('home_tiutrn_926a5b'),
                            hint: context.tr('home_yunhau_501102'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: bottomCtrl,
                          decoration: _sheetDecoration(
                            label: context.tr('home_tiudi_92fb84'),
                            hint: context.tr('home_ngy_41ec10'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: leftCtrl,
                          decoration: _sheetDecoration(
                            label: context.tr('home_tnbntri_538c6b'),
                            hint: context.tr('home_bn_1fd75b'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: rightCtrl,
                          decoration: _sheetDecoration(
                            label: context.tr('home_tnbnphi_855cc7'),
                            hint: context.tr('home_ngiy_5bab37'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: leftAvatarCtrl,
                          decoration: _sheetDecoration(
                            label: context.tr('home_avatartri_9d697b'),
                            hint: 'https://...',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: rightAvatarCtrl,
                          decoration: _sheetDecoration(
                            label: context.tr('home_avatarphi_12a053'),
                            hint: 'https://...',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                selected: draftSingleMode,
                                label: Text(context.tr('home_cnhn_9d6cf4')),
                                onSelected: (_) =>
                                    setSheetState(() => draftSingleMode = true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                selected: !draftSingleMode,
                                label: Text(context.tr('home_cpi_d525b0')),
                                onSelected: (_) => setSheetState(
                                    () => draftSingleMode = false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                draftDate == null
                                    ? context.tr('home_chachnngym_6f48a0')
                                    : 'Ngày mốc: ${DateInputUtils.formatDisplayDate(draftDate!)}',
                                style: SLTheme.quicksand(
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: sheetContext,
                                  initialDate: draftDate ?? now,
                                  firstDate: DateTime(1970, 1, 1),
                                  lastDate: DateTime(now.year + 5, 12, 31),
                                );
                                if (picked != null) {
                                  setSheetState(() => draftDate = picked);
                                }
                              },
                              icon: const Icon(Icons.event_rounded),
                              label: Text(context.tr('home_chnngy_d2cce5')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _CountdownModeSheetDropdown(
                          label: context.tr('home_ch_f5d6a5'),
                          value: draftThemeKey,
                          options: _CountdownModeIndependentScreenState
                              ._themeOptions,
                          onChanged: (value) =>
                              setSheetState(() => draftThemeKey = value),
                        ),
                        const SizedBox(height: 10),
                        _CountdownModeSheetDropdown(
                          label: context.tr('home_kiuvngm_96b8db'),
                          value: draftStyleKey,
                          options: _CountdownModeIndependentScreenState
                              ._countdownStyleOptions,
                          onChanged: (value) =>
                              setSheetState(() => draftStyleKey = value),
                        ),
                        const SizedBox(height: 10),
                        _CountdownModeSheetDropdown(
                          label: 'Khung avatar',
                          value: draftFrameKey,
                          options: _CountdownModeIndependentScreenState
                              ._avatarFrameOptions,
                          onChanged: (value) =>
                              setSheetState(() => draftFrameKey = value),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          value: draftTransparent,
                          onChanged: (value) =>
                              setSheetState(() => draftTransparent = value),
                          title: Text(context.tr('home_knhm_33b8ab')),
                        ),
                        Slider(
                          min: 200,
                          max: UiPrefs.maxCountdownSizePx,
                          value: draftSize.clamp(
                              200.0, UiPrefs.maxCountdownSizePx),
                          onChanged: (value) =>
                              setSheetState(() => draftSize = value),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(
                                _CountdownModeSettingsResult(
                                  action: _CountdownModeSettingsAction.save,
                                  singleMode: draftSingleMode,
                                  anchorDate: draftDate,
                                  themeKey: draftThemeKey,
                                  styleKey: draftStyleKey,
                                  frameKey: draftFrameKey,
                                  fontKey: draftFontKey,
                                  transparentMode: draftTransparent,
                                  sizePx: draftSize,
                                  topLabel: topCtrl.text.trim(),
                                  bottomLabel: bottomCtrl.text.trim(),
                                  nameU1: leftCtrl.text.trim(),
                                  nameU2: rightCtrl.text.trim(),
                                  avatarUrl1: leftAvatarCtrl.text.trim(),
                                  avatarUrl2: rightAvatarCtrl.text.trim(),
                                  customBackgroundUrl: _customBackgroundUrl,
                                  centerIconType: _centerIconType,
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_circle_rounded),
                            label: Text(context.tr('home_luthayi_0dc3cc')),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(
                                _CountdownModeSettingsResult(
                                  action:
                                      _CountdownModeSettingsAction.backToSpaces,
                                  singleMode: draftSingleMode,
                                  anchorDate: draftDate,
                                  themeKey: draftThemeKey,
                                  styleKey: draftStyleKey,
                                  frameKey: draftFrameKey,
                                  fontKey: draftFontKey,
                                  transparentMode: draftTransparent,
                                  sizePx: draftSize,
                                  topLabel: topCtrl.text.trim(),
                                  bottomLabel: bottomCtrl.text.trim(),
                                  nameU1: leftCtrl.text.trim(),
                                  nameU2: rightCtrl.text.trim(),
                                  avatarUrl1: leftAvatarCtrl.text.trim(),
                                  avatarUrl2: rightAvatarCtrl.text.trim(),
                                  customBackgroundUrl: _customBackgroundUrl,
                                  centerIconType: _centerIconType,
                                ),
                              );
                            },
                            icon: const Icon(Icons.grid_view_rounded),
                            label: Text(context.tr('home_vdanhschkh_0a2542')),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(
                                _CountdownModeSettingsResult(
                                  action: _CountdownModeSettingsAction.exit,
                                  singleMode: draftSingleMode,
                                  anchorDate: draftDate,
                                  themeKey: draftThemeKey,
                                  styleKey: draftStyleKey,
                                  frameKey: draftFrameKey,
                                  fontKey: draftFontKey,
                                  transparentMode: draftTransparent,
                                  sizePx: draftSize,
                                  topLabel: topCtrl.text.trim(),
                                  bottomLabel: bottomCtrl.text.trim(),
                                  nameU1: leftCtrl.text.trim(),
                                  nameU2: rightCtrl.text.trim(),
                                  avatarUrl1: leftAvatarCtrl.text.trim(),
                                  avatarUrl2: rightAvatarCtrl.text.trim(),
                                  customBackgroundUrl: _customBackgroundUrl,
                                  centerIconType: _centerIconType,
                                ),
                              );
                            },
                            icon: const Icon(Icons.close_rounded),
                            label:
                                Text(context.tr('home_thotkhnggi_4055ed')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    topCtrl.dispose();
    bottomCtrl.dispose();
    leftCtrl.dispose();
    rightCtrl.dispose();
    leftAvatarCtrl.dispose();
    rightAvatarCtrl.dispose();

    if (result == null || !mounted) {
      return;
    }

    if (result.action == _CountdownModeSettingsAction.save) {
      _safeSetState(() {
        _singleMode = result.singleMode;
        _anchorDate = result.anchorDate;
        _themeKey = result.themeKey;
        _countdownStyleKey = result.styleKey;
        _avatarFrameKey = result.frameKey;
        _fontKey = result.fontKey;
        _transparentMode = result.transparentMode;
        _countdownSizePx = result.sizePx;
        _topLabelText = result.topLabel;
        _bottomLabelText = result.bottomLabel;
        _nameU1 = result.nameU1;
        _nameU2 = result.nameU2;
        _avatarUrl1 = result.avatarUrl1;
        _avatarUrl2 = result.avatarUrl2;
      });
      await _saveLocalSettings();
      if (mounted) _showMessage(context.tr('home_lukhnggian_5e7d0a'));
      return;
    }

    if (result.action == _CountdownModeSettingsAction.backToSpaces) {
      _safeSetState(() {
        _openedSpaceHouseId = null;
        _spaceChromeVisible = true;
        _applySnapshot(_spaceSnapshotFor(_selfSpaceHouseId));
      });
      await _setSystemUiVisible(true);
      return;
    }

    await _setSystemUiVisible(true);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  IconData _spaceStatusIcon(String houseId) {
    if (_hasDeleteRequest(houseId)) {
      return Icons.timelapse_rounded;
    }
    if (houseId == _selfSpaceHouseId) {
      return Icons.lock_rounded;
    }
    if (_hasIncomingSpaceRequest(houseId)) {
      return Icons.mark_email_unread_rounded;
    }
    if (_isSharedSpace(houseId)) {
      return Icons.favorite_rounded;
    }
    if (_hasPendingSpaceRequest(houseId)) {
      return Icons.schedule_rounded;
    }
    return Icons.link_off_rounded;
  }

  String _spaceFooterLabel(
    String houseId,
    CountdownSpaceRequestInfo? incomingRequest,
  ) {
    if (_hasDeleteRequest(houseId)) {
      return context.tr('home_yucuxaangc_aa24f8');
    }
    if (incomingRequest != null) {
      return context.tr('home_chmxemyucu_85b6fa');
    }
    if (houseId == _selfSpaceHouseId) {
      return context.tr('home_giitnnhanh_26f83f');
    }
    if (_isSharedSpace(houseId)) {
      return context.tr('home_chmmkhnggi_ab7267');
    }
    if (_hasPendingSpaceRequest(houseId)) {
      return context.tr('home_yucugiangc_8bfabb');
    }
    return context.tr('home_chmchnhrin_b3ba3e');
  }

  Widget _buildAddSpaceTile(_CountdownModeThemeData themeData) {
    final titleColor = _titleColor(themeData);
    final subtitleColor = _subtitleColor(themeData);
    final accent =
        _hasReachedSpaceLimit ? const Color(0xFFE27A66) : themeData.orbA;

    return InkWell(
      onTap: _isAddingSpace ? null : _showAddSpaceDialog,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: themeData.isDark ? 0.12 : 0.80),
              accent.withValues(alpha: themeData.isDark ? 0.18 : 0.20),
              themeData.orbB.withValues(alpha: themeData.isDark ? 0.12 : 0.16),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: accent.withValues(alpha: 0.34),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: _surfaceShadowColor(themeData),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: accent.withValues(alpha: themeData.isDark ? 0.14 : 0.12),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -22,
              right: -12,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -18,
              left: -10,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeData.orbB.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: themeData.isDark ? 0.10 : 0.60,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: themeData.isDark ? 0.14 : 0.72,
                          ),
                        ),
                      ),
                      child: Text(
                        'Tối đa ${_CountdownModeIndependentScreenState._maxSpaces}',
                        style: SLTheme.quicksand(
                          fontSize: 9.6,
                          fontWeight: FontWeight.w800,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: _isAddingSpace
                        ? CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(titleColor),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(
                                    alpha: themeData.isDark ? 0.10 : 0.58,
                                  ),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.30),
                                  ),
                                ),
                                child: Icon(
                                  _hasReachedSpaceLimit
                                      ? Icons.info_outline_rounded
                                      : Icons.add_rounded,
                                  size: 36,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                context.tr('home_thmkhnggia_f219b2'),
                                style: SLTheme.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _hasReachedSpaceLimit
                                    ? context.tr('home_slngchmxem_5af5e1')
                                    : context.tr('home_tothmmtnhp_6778de'),
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: 10.8,
                                  fontWeight: FontWeight.w700,
                                  color: subtitleColor,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpaceTile({
    required _CountdownModeThemeData themeData,
    required String houseId,
    required CountdownSpaceRequestInfo? incomingRequest,
    required bool isHandlingIncomingRequest,
    required _CountdownSpaceSnapshot snapshot,
    required Color accent,
    required String daysValue,
    required VoidCallback? openIncomingRequest,
  }) {
    final titleColor = _titleColor(themeData);
    final subtitleColor = _subtitleColor(themeData);
    final footerLabel = _spaceFooterLabel(houseId, incomingRequest);
    final statusLabel = _spaceConnectionStatusLabel(houseId);
    final previewStyleData = _CountdownModeStyleData.resolve(
      snapshot.styleKey,
      snapshot.transparentMode,
    );

    return InkWell(
      onTap: isHandlingIncomingRequest
          ? null
          : (incomingRequest == null
              ? () => unawaited(_openSpace(houseId))
              : openIncomingRequest),
      onLongPress: () => unawaited(_showRenameSpaceDialog(houseId)),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: themeData.isDark ? 0.12 : 0.82),
              accent.withValues(alpha: themeData.isDark ? 0.14 : 0.14),
              themeData.orbB.withValues(alpha: themeData.isDark ? 0.08 : 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: accent.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _surfaceShadowColor(themeData),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: accent.withValues(alpha: themeData.isDark ? 0.14 : 0.10),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _spaceTitle(houseId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.18)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _spaceStatusIcon(houseId),
                              size: 12,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: 9.8,
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: themeData.isDark ? 0.08 : 0.62,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: themeData.isDark ? 0.12 : 0.74,
                      ),
                    ),
                  ),
                  child: isHandlingIncomingRequest
                      ? Padding(
                          padding: const EdgeInsets.all(9),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        )
                      : InkWell(
                          onTap: incomingRequest == null
                              ? () => unawaited(
                                    _showRenameSpaceDialog(houseId),
                                  )
                              : openIncomingRequest,
                          borderRadius: BorderRadius.circular(999),
                          child: Icon(
                            incomingRequest == null
                                ? Icons.edit_rounded
                                : Icons.mark_email_unread_rounded,
                            size: 17,
                            color:
                                incomingRequest == null ? titleColor : accent,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, previewConstraints) {
                  final widthSize = previewConstraints.maxWidth * 0.56;
                  final heightSize = previewConstraints.maxHeight - 32;
                  final rawSize =
                      widthSize < heightSize ? widthSize : heightSize;
                  final previewSize = rawSize.clamp(64.0, 104.0).toDouble();
                  final bgUrl = snapshot.customBackgroundUrl.trim();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.18),
                          Colors.white.withValues(
                              alpha: themeData.isDark ? 0.08 : 0.46),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.24)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (bgUrl.isNotEmpty)
                            Positioned.fill(
                              child: CachedNetworkImage(
                                imageUrl: bgUrl,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                fadeInDuration:
                                    const Duration(milliseconds: 180),
                                memCacheWidth: 720,
                                placeholder: (_, __) => DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent.withValues(alpha: 0.16),
                                        Colors.white.withValues(
                                          alpha: themeData.isDark ? 0.06 : 0.34,
                                        ),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                accent),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent.withValues(alpha: 0.14),
                                        Colors.white.withValues(
                                          alpha: themeData.isDark ? 0.06 : 0.24,
                                        ),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: accent.withValues(alpha: 0.76),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: bgUrl.isEmpty
                                          ? 0.00
                                          : (themeData.isDark ? 0.10 : 0.32),
                                    ),
                                    accent.withValues(
                                      alpha: themeData.isDark ? 0.08 : 0.14,
                                    ),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: previewSize,
                            height: previewSize,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: previewStyleData.outerGradient,
                                border: previewStyleData.outerBorder,
                                boxShadow: previewStyleData.shadows,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: previewStyleData.innerGradient,
                                    border: previewStyleData.innerBorder,
                                  ),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: previewStyleData.numberGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        daysValue,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: SLTheme.textStyleForKey(
                                          snapshot.fontKey,
                                          fontSize: previewSize * 0.36,
                                          fontWeight: FontWeight.w900,
                                          height: 1.0,
                                          color: Colors.white,
                                          shadows:
                                              previewStyleData.numberShadows,
                                        ),
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
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  incomingRequest == null
                      ? Icons.touch_app_rounded
                      : Icons.campaign_rounded,
                  size: 13,
                  color: subtitleColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    footerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 10.3,
                      fontWeight: FontWeight.w800,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpacesGrid(BuildContext context) {
    final selfSnapshot = _spaceSnapshotFor(_selfSpaceHouseId);
    final themeData = _CountdownModeThemeData.resolve(
      _resolveThemeKey(selfSnapshot.themeKey),
    );
    final titleColor = _titleColor(themeData);
    final subtitleColor = _subtitleColor(themeData);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: themeData.background,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeData.overlay,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          top: -46,
          right: -12,
          child: IgnorePointer(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    themeData.orbB
                        .withValues(alpha: themeData.isDark ? 0.18 : 0.24),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -38,
          child: IgnorePointer(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    themeData.orbA
                        .withValues(alpha: themeData.isDark ? 0.14 : 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: themeData.isDark ? 0.10 : 0.58,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: themeData.isDark ? 0.14 : 0.72,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _surfaceShadowColor(themeData),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 17,
                          color: titleColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        context.tr('home_khnggianri_e16da8'),
                        style: SLTheme.quicksand(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          height: 1.02,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('home_nhpmnhuser_1f2686'),
                  style: SLTheme.quicksand(
                    fontSize: 12.4,
                    fontWeight: FontWeight.w700,
                    color: subtitleColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 760
                          ? 4
                          : constraints.maxWidth >= 520
                              ? 3
                              : 2;
                      final childAspectRatio = crossAxisCount >= 4
                          ? 0.82
                          : crossAxisCount == 3
                              ? 0.80
                              : 0.76;

                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 6),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _spaceHouseIds.length + 1,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          if (index == _spaceHouseIds.length) {
                            return _buildAddSpaceTile(themeData);
                          }

                          final houseId = _spaceHouseIds[index];
                          final incomingRequest = _incomingRequestFor(houseId);
                          final isHandlingIncomingRequest =
                              incomingRequest != null &&
                                  _isHandlingSpaceRequest(
                                    incomingRequest.requestId,
                                  );
                          final snapshot = _spaceSnapshotFor(houseId);
                          final accent = _spaceAccentColorResolved(houseId);
                          final daysValue = snapshot.anchorDate == null
                              ? '--'
                              : _daysSince(snapshot.anchorDate!).toString();
                          final openIncomingRequest = incomingRequest == null
                              ? null
                              : () => unawaited(
                                    _showIncomingSpaceRequestDialog(houseId),
                                  );

                          return _buildSpaceTile(
                            themeData: themeData,
                            houseId: houseId,
                            incomingRequest: incomingRequest,
                            isHandlingIncomingRequest:
                                isHandlingIncomingRequest,
                            snapshot: snapshot,
                            accent: accent,
                            daysValue: daysValue,
                            openIncomingRequest: openIncomingRequest,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
