part of '../../settings_tab.dart';

extension _CountdownModeSpacesPart on _CountdownModeIndependentScreenState {
  Future<void> _openSettingsSheetImpl() async {
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
      unawaited(_refreshCountdownStyleUnlockState());
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
        _spaceChromeVisible = false;
      });
      await _saveLocalSettings();
      if (mounted) _showMessage('Đã lưu không gian đếm.');
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

  Future<void> _openSettingsSheetLegacyImpl() async {
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                                'Cài đặt không gian đếm',
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
                            label: 'Tiêu đề trên',
                            hint: 'Yêu nhau',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: bottomCtrl,
                          decoration: _sheetDecoration(
                            label: 'Tiêu đề dưới',
                            hint: 'ngày',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: leftCtrl,
                          decoration: _sheetDecoration(
                            label: 'Tên bên trái',
                            hint: 'Bạn',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: rightCtrl,
                          decoration: _sheetDecoration(
                            label: 'Tên bên phải',
                            hint: 'Người ấy',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: leftAvatarCtrl,
                          decoration: _sheetDecoration(
                            label: 'Avatar trái',
                            hint: 'https://...',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: rightAvatarCtrl,
                          decoration: _sheetDecoration(
                            label: 'Avatar phải',
                            hint: 'https://...',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                selected: draftSingleMode,
                                label: Text(context.tr('countdown_single_mode')),
                                onSelected: (_) =>
                                    setSheetState(() => draftSingleMode = true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                selected: !draftSingleMode,
                                label: Text(context.tr('countdown_couple_mode')),
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
                                    ? context.tr('countdown_no_date_selected')
                                    : '${context.tr('countdown_anchor_date')}: ${DateInputUtils.formatDisplayDate(draftDate!)}',
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
                              label: Text(context.tr('countdown_pick_date')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _CountdownModeSheetDropdown(
                          label: 'Chủ đề',
                          value: draftThemeKey,
                          options: _CountdownModeIndependentScreenState
                              ._themeOptions,
                          onChanged: (value) =>
                              setSheetState(() => draftThemeKey = value),
                        ),
                        const SizedBox(height: 10),
                        _CountdownModeSheetDropdown(
                          label: 'Giao diện vòng đếm',
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
                          title: Text(context.tr('countdown_transparent_mode')),
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
                            label: Text(context.tr('countdown_save_changes')),
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
                            label: Text(context.tr('countdown_back_to_spaces')),
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
                            label: Text(context.tr('countdown_exit_space')),
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
      if (mounted) _showMessage('Đã lưu không gian đếm.');
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

  Widget _buildSpacesGridImpl(BuildContext context) {
    final selfSnapshot = _spaceSnapshotFor(_selfSpaceHouseId);
    final themeData = _CountdownModeThemeData.resolve(
      _resolveThemeKey(selfSnapshot.themeKey),
    );
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
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không gian đếm',
                  style: SLTheme.quicksand(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: themeData.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhập mã nhà, @username hoặc link để gửi yêu cầu ghép nối. Mỗi không gian ở đây có cấu hình đếm riêng, không dùng chung dữ liệu với home.',
                  style: SLTheme.quicksand(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                    color: themeData.foreground
                        .withValues(alpha: themeData.isDark ? 0.82 : 0.68),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    itemCount: _spaceHouseIds.length + 1,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      if (index == _spaceHouseIds.length) {
                        return InkWell(
                          onTap: _isAddingSpace ? null : _showAddSpaceDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: themeData.isDark
                                    ? [
                                        themeData.orbA.withValues(alpha: 0.14),
                                        themeData.orbB.withValues(alpha: 0.10),
                                        Colors.white.withValues(alpha: 0.06),
                                      ]
                                    : [
                                        themeData.orbA.withValues(alpha: 0.12),
                                        themeData.orbB.withValues(alpha: 0.08),
                                        const Color(0xFFFFF5F8).withValues(alpha: 0.88),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: themeData.orbA.withValues(alpha: themeData.isDark ? 0.26 : 0.22),
                              ),
                            ),
                            child: Center(
                              child: _isAddingSpace
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 2.2)
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _hasReachedSpaceLimit
                                              ? Icons.info_outline_rounded
                                              : Icons.add_rounded,
                                          size: 40,
                                          color: themeData.foreground,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Thêm không gian',
                                          style: SLTheme.quicksand(
                                            fontWeight: FontWeight.w900,
                                            color: themeData.foreground,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      }

                      final houseId = _spaceHouseIds[index];
                      final incomingRequest = _incomingRequestFor(houseId);
                      final isHandlingIncomingRequest = incomingRequest !=
                              null &&
                          _isHandlingSpaceRequest(incomingRequest.requestId);
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

                      return InkWell(
                        onTap: isHandlingIncomingRequest
                            ? null
                            : (incomingRequest == null
                                ? () => unawaited(_openSpace(houseId))
                                : openIncomingRequest),
                        onLongPress: () =>
                            unawaited(_showRenameSpaceDialog(houseId)),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: themeData.isDark
                                  ? [
                                      Colors.white.withValues(alpha: 0.10),
                                      accent.withValues(alpha: 0.12),
                                    ]
                                  : [
                                      const Color(0xFFFFF5F8).withValues(alpha: 0.88),
                                      accent.withValues(alpha: 0.10),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: accent.withValues(alpha: themeData.isDark ? 0.24 : 0.20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _spaceTitle(houseId),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SLTheme.quicksand(
                                        fontSize: 13.8,
                                        fontWeight: FontWeight.w900,
                                        color: themeData.foreground,
                                      ),
                                    ),
                                  ),
                                  if (isHandlingIncomingRequest)
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          accent,
                                        ),
                                      ),
                                    )
                                  else
                                    InkWell(
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
                                        size: 16,
                                        color: incomingRequest == null
                                            ? themeData.foreground
                                                .withValues(alpha: 0.72)
                                            : accent,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _spaceConnectionStatusLabel(houseId),
                                style: SLTheme.quicksand(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                height: 92,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [
                                      accent.withValues(alpha: themeData.isDark ? 0.24 : 0.18),
                                      themeData.orbB.withValues(alpha: themeData.isDark ? 0.10 : 0.08),
                                    ],
                                  ),
                                  border: Border.all(
                                      color: accent.withValues(alpha: 0.28)),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _previewTopLabel(snapshot),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: SLTheme.textStyleForKey(
                                          snapshot.fontKey,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: themeData.foreground
                                              .withValues(alpha: 0.86),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        daysValue,
                                        style: SLTheme.textStyleForKey(
                                          snapshot.fontKey,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          color: themeData.foreground,
                                        ),
                                      ),
                                      Text(
                                        _previewBottomLabel(snapshot),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: SLTheme.textStyleForKey(
                                          snapshot.fontKey,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: themeData.foreground
                                              .withValues(alpha: 0.84),
                                        ),
                                      ),
                                    ],
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
