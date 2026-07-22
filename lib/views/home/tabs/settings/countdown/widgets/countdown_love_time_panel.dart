// ignore_for_file: library_private_types_in_public_api
part of '../../../settings_tab.dart';

extension CountdownLoveTimePanelExt on _CountdownModeIndependentScreenState {
  Widget _buildLoveTimeCounters() {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (tick) => tick),
      initialData: 0,
      builder: (context, snapshot) {
        final detail = _loveTimeDetail(_anchorDate);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLoveTimeCell(
                value: detail['h']!, label: context.tr('home_gi_770f40')),
            const SizedBox(width: 8),
            _buildLoveTimeCell(
              value: detail['m']!,
              label: context.tr('home_pht_06b001'),
              alternate: true,
            ),
            const SizedBox(width: 8),
            _buildLoveTimeCell(
                value: detail['s']!, label: context.tr('home_giy_392758')),
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

  // ignore: unused_element
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
                    physics: const ClampingScrollPhysics(),
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
                        StatefulBuilder(
                          builder: (sheetContext, setSliderState) {
                            return Slider(
                              min: 200,
                              max: UiPrefs.maxCountdownSizePx,
                              value: draftSize.clamp(
                                  200.0, UiPrefs.maxCountdownSizePx),
                              onChanged: (value) {
                                setSliderState(() {
                                  draftSize = value;
                                });
                                draftSize = value;
                              },
                            );
                          },
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
                            label: Text(context.tr('home_thotkhnggi_4055ed')),
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

  
}
