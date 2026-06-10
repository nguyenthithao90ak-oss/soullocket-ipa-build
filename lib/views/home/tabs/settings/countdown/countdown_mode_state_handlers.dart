part of '../../settings_tab.dart';
// ignore_for_file: dead_code, unused_element

extension _CountdownModeIndependentScreenStatePart
    on _CountdownModeIndependentScreenState {
  DateTime? _resolveInitialAnchorDate(bool singleMode) {
    final primary =
        DateInputUtils.parse(singleMode ? widget.birthDate : widget.loveDate);
    if (primary != null) {
      return primary;
    }
    return DateInputUtils.parse(
      singleMode ? widget.loveDate : widget.birthDate,
    );
  }

  Future<void> _loadSpaces() async {
    final prefs = await SharedPreferences.getInstance();
    final storedNames =
        prefs.getStringList(_spaceNamesPrefKey) ?? const <String>[];

    final names = <String, String>{};
    for (final raw in storedNames) {
      final parts = raw.split('\t');
      if (parts.length < 2) continue;
      final key = parts.first.trim();
      final value = parts.sublist(1).join('\t').trim();
      if (key.isEmpty || value.isEmpty) continue;
      names[key] = value;
    }
    final selfSnapshot = _snapshotFromPrefs(prefs, scope: _selfSpaceHouseId);

    if (!mounted) {
      return;
    }
    _safeSetState(() {
      _spaceDisplayNames = names;
      _spaceSnapshots[_selfSpaceHouseId] = selfSnapshot;
      if (_openedSpaceHouseId == null ||
          _openedSpaceHouseId == _selfSpaceHouseId) {
        _applySnapshot(selfSnapshot);
      }
      _rebuildVisibleSpaces();
    });
  }

  Future<void> _saveSpaceRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _spacesPrefKey,
      _spaceHouseIds.where((id) => id != _selfSpaceHouseId).toList(),
    );
    await prefs.setStringList(
      _spaceNamesPrefKey,
      _spaceDisplayNames.entries
          .map((entry) => '${entry.key}\t${entry.value}')
          .toList(),
    );
  }

  void _listenCountdownSpaces() {
    if (_selfSpaceHouseId == 'local_self') {
      _countdownDeleteEvaluationTimer?.cancel();
      if (!mounted) {
        return;
      }
      _safeSetState(() {
        _rebuildVisibleSpaces();
      });
      return;
    }
    _countdownRequestsSub?.cancel();
    _countdownSpacesSub?.cancel();
    _countdownDeleteRequestsSub?.cancel();
    _countdownRequestsSub = _countdownSpaceService
        .watchRequestsForHouse(_selfSpaceHouseId)
        .listen(_handleCountdownRequestsChanged);
    _countdownSpacesSub = _countdownSpaceService
        .watchSpacesForHouse(_selfSpaceHouseId)
        .listen(_handleCountdownSpacesChanged);
    _countdownDeleteRequestsSub = _countdownSpaceService
        .watchDeleteRequestsForHouse(_selfSpaceHouseId)
        .listen(_handleCountdownDeleteRequestsChanged);
  }

  void _handleCountdownRequestsChanged(
    List<CountdownSpaceRequestInfo> requests,
  ) {
    if (!mounted) {
      return;
    }

    final nextPending = <String, CountdownSpaceRequestInfo>{};
    final nextIncoming = <String, CountdownSpaceRequestInfo>{};
    final outgoingStatuses = <String, String>{};
    final nextSnapshots = <String, _CountdownSpaceSnapshot>{};
    final pendingSnapshotsToSync =
        <CountdownSpaceRequestInfo, _CountdownSpaceSnapshot>{};
    final activeRequestIds =
        requests.map((request) => request.requestId).toSet();
    final sortedRequests = requests.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final request in sortedRequests) {
      final otherHouseId = request.otherHouseIdFor(_selfSpaceHouseId);
      if (otherHouseId.isEmpty) {
        continue;
      }

      if (request.isOutgoingFor(_selfSpaceHouseId)) {
        if (outgoingStatuses.containsKey(otherHouseId)) {
          continue;
        }
        outgoingStatuses[otherHouseId] = request.status;
        if (request.status != 'pending') {
          continue;
        }
        nextPending[otherHouseId] = request;
        final localSnapshot = _spaceSnapshots[otherHouseId];
        if (_optimisticPendingSpaceHouseIds.contains(otherHouseId) &&
            localSnapshot != null) {
          nextSnapshots[otherHouseId] = localSnapshot;
          pendingSnapshotsToSync[request] = localSnapshot;
          continue;
        }
        nextSnapshots[otherHouseId] = _snapshotFromSerializedMap(
          request.snapshot,
          scope: otherHouseId,
        );
        continue;
      }

      if (request.status != 'pending' ||
          nextIncoming.containsKey(otherHouseId)) {
        continue;
      }

      nextIncoming[otherHouseId] = request;
      nextSnapshots[otherHouseId] = _snapshotFromSerializedMap(
        request.snapshot,
        scope: otherHouseId,
      );
    }

    _safeSetState(() {
      _pendingSpaceRequests
        ..clear()
        ..addAll(nextPending);
      _incomingSpaceRequests
        ..clear()
        ..addAll(nextIncoming);
      nextSnapshots.forEach((houseId, snapshot) {
        if (_isIncomingSnapshotNewer(houseId, snapshot)) {
          _spaceSnapshots[houseId] = snapshot;
        }
      });
      _optimisticPendingSpaceHouseIds.removeWhere(
        outgoingStatuses.containsKey,
      );
      _spaceRequestActionIds.removeWhere(
        (requestId) => !activeRequestIds.contains(requestId),
      );
      final openedSpaceId = _openedSpaceHouseId;
      if (openedSpaceId != null &&
          openedSpaceId != _selfSpaceHouseId &&
          !_sharedSpaces.containsKey(openedSpaceId) &&
          nextSnapshots.containsKey(openedSpaceId)) {
        final nextSnapshot = nextSnapshots[openedSpaceId]!;
        if (_isIncomingSnapshotNewer(openedSpaceId, nextSnapshot)) {
          _applySnapshot(nextSnapshot);
        }
      }
      _rebuildVisibleSpaces();
    });

    for (final entry in pendingSnapshotsToSync.entries) {
      unawaited(
        _countdownSpaceService.updatePendingRequestSnapshot(
          requestId: entry.key.requestId,
          fromHouseId: _selfSpaceHouseId,
          snapshot: _snapshotToSerializedMap(entry.value),
        ),
      );
    }
  }

  void _handleCountdownSpacesChanged(List<CountdownSpaceInfo> spaces) {
    if (!mounted) {
      return;
    }

    final nextSharedSpaces = <String, CountdownSpaceInfo>{};
    final nextSnapshots = <String, _CountdownSpaceSnapshot>{};
    var didCloseRemovedSpace = false;

    for (final space in spaces) {
      if (space.status != 'active') {
        continue;
      }
      final otherHouseId = space.otherHouseIdFor(_selfSpaceHouseId);
      if (otherHouseId.isEmpty) {
        continue;
      }
      nextSharedSpaces[otherHouseId] = space;
      nextSnapshots[otherHouseId] = _snapshotFromSerializedMap(
        space.snapshot,
        scope: otherHouseId,
      );
    }

    _safeSetState(() {
      _sharedSpaces
        ..clear()
        ..addAll(nextSharedSpaces);
      nextSnapshots.forEach((houseId, snapshot) {
        if (_isIncomingSnapshotNewer(houseId, snapshot)) {
          _spaceSnapshots[houseId] = snapshot;
        }
      });
      _optimisticPendingSpaceHouseIds.removeWhere(
        nextSharedSpaces.containsKey,
      );
      final openedSpaceId = _openedSpaceHouseId;
      if (openedSpaceId != null && openedSpaceId != _selfSpaceHouseId) {
        if (nextSnapshots.containsKey(openedSpaceId)) {
          final nextSnapshot = nextSnapshots[openedSpaceId]!;
          if (_isIncomingSnapshotNewer(openedSpaceId, nextSnapshot)) {
            _applySnapshot(nextSnapshot);
          }
        } else if (!nextSharedSpaces.containsKey(openedSpaceId)) {
          didCloseRemovedSpace = true;
          _openedSpaceHouseId = null;
          _spaceChromeVisible = true;
          _applySnapshot(_spaceSnapshotFor(_selfSpaceHouseId));
        }
      }
      _rebuildVisibleSpaces();
    });
    if (didCloseRemovedSpace) {
      _showMessage(context.tr('home_khnggianny_538f43'));
    }
  }

  void _handleCountdownDeleteRequestsChanged(
    List<CountdownSpaceDeleteRequestInfo> requests,
  ) {
    if (!mounted) {
      return;
    }

    final nextDeleteRequests = <String, CountdownSpaceDeleteRequestInfo>{};
    final expiredSpaceIds = <String>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    final sortedRequests = requests.toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    for (final request in sortedRequests) {
      if (!request.isPending) {
        continue;
      }
      final otherHouseId = request.otherHouseIdFor(_selfSpaceHouseId);
      if (otherHouseId.isEmpty ||
          nextDeleteRequests.containsKey(otherHouseId)) {
        continue;
      }
      nextDeleteRequests[otherHouseId] = request;
      if (request.deleteAt > 0 && now >= request.deleteAt) {
        expiredSpaceIds.add(request.spaceId);
      }
    }

    _safeSetState(() {
      _deleteSpaceRequests
        ..clear()
        ..addAll(nextDeleteRequests);
    });

    _scheduleCountdownDeleteEvaluation(nextDeleteRequests.values);
    for (final spaceId in expiredSpaceIds) {
      unawaited(
        _countdownSpaceService.evaluateDeleteRequest(
          spaceId: spaceId,
          currentHouseId: _selfSpaceHouseId,
        ),
      );
    }
  }

  void _scheduleCountdownDeleteEvaluation(
    Iterable<CountdownSpaceDeleteRequestInfo> requests,
  ) {
    _countdownDeleteEvaluationTimer?.cancel();
    _countdownDeleteEvaluationTimer = null;

    var targetAt = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final request in requests) {
      if (!request.isPending || request.deleteAt <= 0) {
        continue;
      }
      if (request.deleteAt <= now) {
        unawaited(_evaluateCountdownDeleteRequests());
        return;
      }
      if (targetAt == 0 || request.deleteAt < targetAt) {
        targetAt = request.deleteAt;
      }
    }
    if (targetAt <= 0) {
      return;
    }

    final delayMs = (targetAt - now).clamp(0, 2147483647);
    _countdownDeleteEvaluationTimer = Timer(
      Duration(milliseconds: delayMs),
      () => unawaited(_evaluateCountdownDeleteRequests()),
    );
  }

  Future<void> _evaluateCountdownDeleteRequests() async {
    final spaceIds = _deleteSpaceRequests.values
        .map((request) => request.spaceId)
        .toList(growable: false);
    for (final spaceId in spaceIds) {
      await _countdownSpaceService.evaluateDeleteRequest(
        spaceId: spaceId,
        currentHouseId: _selfSpaceHouseId,
      );
    }
  }

  void _rebuildVisibleSpaces() {
    final ids = <String>[_selfSpaceHouseId];
    void addId(String houseId) {
      final normalized = houseId.trim();
      if (normalized.isEmpty || ids.contains(normalized)) {
        return;
      }
      ids.add(normalized);
    }

    final incomingEntries = _incomingSpaceRequests.entries.toList()
      ..sort((a, b) => b.value.createdAt.compareTo(a.value.createdAt));
    for (final entry in incomingEntries) {
      addId(entry.key);
    }

    final activeEntries = _sharedSpaces.entries.toList()
      ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    for (final entry in activeEntries) {
      addId(entry.key);
    }

    final pendingEntries = _pendingSpaceRequests.entries.toList()
      ..sort((a, b) => b.value.createdAt.compareTo(a.value.createdAt));
    for (final entry in pendingEntries) {
      addId(entry.key);
    }

    final optimisticIds = _optimisticPendingSpaceHouseIds.toList()..sort();
    for (final houseId in optimisticIds) {
      addId(houseId);
    }

    _spaceHouseIds = ids;
    _acceptedSpaceHouseIds = <String>{_selfSpaceHouseId, ..._sharedSpaces.keys};
  }

  Future<void> _loadLocalSettings({required String scope}) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = _snapshotFromPrefs(prefs, scope: scope);
    if (!mounted) return;
    _safeSetState(() {
      _spaceSnapshots[scope] = snapshot;
      _applySnapshot(snapshot);
    });
    return;
    final ui = UiPrefs.notifier.value;
    final defaultSingleMode = widget.relationshipMode.trim() == 'single';
    final defaultTopLabel = defaultSingleMode
        ? (ui.countdownTopLabel.trim().isNotEmpty
            ? ui.countdownTopLabel.trim()
            : context.tr('home_tuicati_5c654c'))
        : (widget.fallbackTopLabel.trim().isNotEmpty
            ? widget.fallbackTopLabel.trim()
            : context.tr('home_yunhau_501102'));
    final defaultBottomLabel = defaultSingleMode
        ? (ui.countdownBottomLabel.trim().isNotEmpty
            ? ui.countdownBottomLabel.trim()
            : context.tr('home_ngytui_22bed4'))
        : (widget.fallbackBottomLabel.trim().isNotEmpty
            ? widget.fallbackBottomLabel.trim()
            : context.tr('home_ngy_41ec10'));
    final defaultNameU1 =
        widget.nameU1.trim().isEmpty ? context.tr('home_bn_1fd75b') : widget.nameU1.trim();
    final defaultNameU2 =
        widget.nameU2.trim().isEmpty ? context.tr('home_ngiy_5bab37') : widget.nameU2.trim();
    final defaultThemeKey =
        ui.themeKey.trim().isEmpty ? 'theme-auto' : ui.themeKey.trim();
    final defaultStyleKey = ui.countdownStyleKey.trim().isEmpty
        ? 'default'
        : ui.countdownStyleKey.trim();
    final defaultFrameKey =
        ui.avatarFrameKey.trim().isEmpty ? 'circle' : ui.avatarFrameKey.trim();
    final rawDate =
        prefs.getString(_prefKey('anchor_date', scope: scope)) ?? '';
    final parsedDate = DateInputUtils.parse(rawDate) ??
        _resolveInitialAnchorDate(defaultSingleMode);
    if (!mounted) return;
    _safeSetState(() {
      _singleMode = prefs.getBool(_prefKey('single_mode', scope: scope)) ??
          defaultSingleMode;
      _themeKey = prefs.getString(_prefKey('theme_key', scope: scope)) ??
          defaultThemeKey;
      _countdownStyleKey =
          prefs.getString(_prefKey('style_key', scope: scope)) ??
              defaultStyleKey;
      _fontKey = prefs.getString(_prefKey('font_key', scope: scope)) ??
          SLTheme.normalizeFontKey(ui.fontKey);
      _avatarFrameKey =
          prefs.getString(_prefKey('avatar_frame_key', scope: scope)) ??
              defaultFrameKey;
      _transparentMode = prefs.getBool(
            _prefKey('transparent_mode', scope: scope),
          ) ??
          ui.transparentMode;
      _countdownSizePx = (prefs.getDouble(_prefKey('size_px', scope: scope)) ??
              ui.countdownSizePx)
          .clamp(200.0, UiPrefs.maxCountdownSizePx)
          .toDouble();
      _customBackgroundUrl =
          prefs.getString(_prefKey('bg_url', scope: scope)) ??
              ui.customBackgroundUrl.trim();
      _centerIconType =
          prefs.getString(_prefKey('center_icon_type', scope: scope)) ??
              'heart';
      _topLabelText = prefs.getString(_prefKey('top_label', scope: scope)) ??
          defaultTopLabel;
      _bottomLabelText =
          prefs.getString(_prefKey('bottom_label', scope: scope)) ??
              defaultBottomLabel;
      _nameU1 =
          prefs.getString(_prefKey('name_u1', scope: scope)) ?? defaultNameU1;
      _nameU2 =
          prefs.getString(_prefKey('name_u2', scope: scope)) ?? defaultNameU2;
      _avatarUrl1 = prefs.getString(_prefKey('avatar_1', scope: scope)) ??
          widget.avatarUrl1.trim();
      _avatarUrl2 = prefs.getString(_prefKey('avatar_2', scope: scope)) ??
          widget.avatarUrl2.trim();
      _anchorDate = parsedDate;
    });
  }

  Future<void> _saveLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _scopeKey;
    final snapshot = _sanitizeSnapshot(_captureCurrentSnapshot());
    await prefs.setBool(_prefKey('single_mode', scope: scope), _singleMode);
    await prefs.setString(_prefKey('theme_key', scope: scope), _themeKey);
    await prefs.setString(
      _prefKey('style_key', scope: scope),
      snapshot.styleKey,
    );
    await prefs.setString(_prefKey('font_key', scope: scope), _fontKey);
    await prefs.setString(
      _prefKey('avatar_frame_key', scope: scope),
      _avatarFrameKey,
    );
    await prefs.setBool(
      _prefKey('transparent_mode', scope: scope),
      _transparentMode,
    );
    await prefs.setDouble(_prefKey('size_px', scope: scope), _countdownSizePx);
    await prefs.setString(
      _prefKey('bg_url', scope: scope),
      _customBackgroundUrl,
    );
    await prefs.setString(
      _prefKey('center_icon_type', scope: scope),
      _centerIconType,
    );
    await prefs.setString(_prefKey('top_label', scope: scope), _topLabelText);
    await prefs.setString(
      _prefKey('bottom_label', scope: scope),
      _bottomLabelText,
    );
    await prefs.setString(_prefKey('name_u1', scope: scope), _nameU1);
    await prefs.setString(_prefKey('name_u2', scope: scope), _nameU2);
    await prefs.setString(_prefKey('avatar_1', scope: scope), _avatarUrl1);
    await prefs.setString(_prefKey('avatar_2', scope: scope), _avatarUrl2);
    await prefs.setString(
      _prefKey('anchor_date', scope: scope),
      _anchorDate == null ? '' : DateInputUtils.formatIsoDate(_anchorDate!),
    );
    await prefs.setInt(
      _prefKey('updated_at_ms', scope: scope),
      snapshot.updatedAtMs,
    );
    if (mounted) {
      _safeSetState(() {
        _spaceSnapshots[scope] = snapshot;
      });
    }
    if (scope == _selfSpaceHouseId || _selfSpaceHouseId == 'local_self') {
      return;
    }

    final serializedSnapshot = _snapshotToSerializedMap(snapshot);
    if (_isSharedSpace(scope)) {
      await _countdownSpaceService.updateSpaceSnapshot(
        selfHouseId: _selfSpaceHouseId,
        otherHouseId: scope,
        snapshot: serializedSnapshot,
      );
      return;
    }

    final pendingRequest = _pendingRequestFor(scope);
    if (pendingRequest == null) {
      return;
    }
    await _countdownSpaceService.updatePendingRequestSnapshot(
      requestId: pendingRequest.requestId,
      fromHouseId: _selfSpaceHouseId,
      snapshot: serializedSnapshot,
    );
  }

  Future<void> _openSpace(String houseId) async {
    final trimmed = houseId.trim();
    if (trimmed.isEmpty) return;
    final cachedSnapshot =
        _spaceSnapshots[trimmed] ?? _spaceSnapshotFor(trimmed);
    _safeSetState(() {
      _openedSpaceHouseId = trimmed;
      _spaceChromeVisible = true;
      _applySnapshot(cachedSnapshot);
    });
    await _setSystemUiVisible(true);
  }

  Future<void> _closeOpenedSpace() async {
    if (_openedSpaceHouseId == null) {
      return;
    }
    _safeSetState(() {
      _openedSpaceHouseId = null;
      _spaceChromeVisible = true;
      _applySnapshot(_spaceSnapshotFor(_selfSpaceHouseId));
    });
    await _setSystemUiVisible(true);
  }

  Future<void> _pickAnchorDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(1970, 1, 1);
    final lastDate = DateTime(now.year + 5, 12, 31);
    final initialDate = _anchorDate ?? now;
    final picked = await _showAnchorDateInputDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    _safeSetState(() {
      _anchorDate = picked;
    });
    await _saveLocalSettings();
  }

  Future<DateTime?> _showAnchorDateInputDialog({
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
                    child: const Text('OK'),
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

  Future<void> _editCountdownLabel({
    required bool editTopLabel,
  }) async {
    final controller = TextEditingController(
      text: editTopLabel ? _topLabelText : _bottomLabelText,
    );
    final nextValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(editTopLabel ? context.tr('home_sachtrn_a2d51f') : context.tr('home_sachdi_744600')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 22,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('home_hy_1e4050')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(context.tr('home_lu_49fac1')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || nextValue == null) {
      return;
    }
    _safeSetState(() {
      if (editTopLabel) {
        _topLabelText = nextValue;
      } else {
        _bottomLabelText = nextValue;
      }
    });
    await _saveLocalSettings();
  }

  String? get _uploadHouseId {
    final houseId = (widget.currentHouseId ?? '').trim();
    return houseId.isEmpty ? null : houseId;
  }

  String get _pendingSpaceAvatarUploadKey =>
      '${_CountdownModeIndependentScreenState._pendingSpaceAvatarUploadKeyPrefix}${_selfSpaceHouseId.trim()}';

  Future<void> _promptPendingSpaceAvatarRetryIfNeeded() async {
    if (_didPromptPendingSpaceAvatarRetry || !mounted) {
      return;
    }
    final pending =
        await PendingUploadService.instance.load(_pendingSpaceAvatarUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    _didPromptPendingSpaceAvatarRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('home_lnuploadav_949b24'),
          ),
          action: SnackBarAction(
            label: context.tr('home_thli_4dffdf'),
            onPressed: () {
              unawaited(_retryPendingSpaceAvatarUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingSpaceAvatarUpload() async {
    final pending =
        await PendingUploadService.instance.load(_pendingSpaceAvatarUploadKey);
    if (pending == null || !mounted) {
      return;
    }
    final filePath = pending['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      await PendingUploadService.instance.clear(_pendingSpaceAvatarUploadKey);
      return;
    }
    final file = XFile(filePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(_pendingSpaceAvatarUploadKey);
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(_pendingSpaceAvatarUploadKey);
      return;
    }
    await _changeSpaceAvatar(
      isLeft: pending['role']?.toString() != 'right',
      presetFile: file,
    );
  }

  Future<void> _changeSpaceAvatar({
    required bool isLeft,
    XFile? presetFile,
  }) async {
    final houseId = _uploadHouseId;
    if (houseId == null) {
      _showMessage(context.tr('home_khngtmthym_b7eeff'));
      return;
    }
    final role = isLeft ? 'left' : 'right';
    if (_uploadingAvatarRole != null) {
      return;
    }
    XFile? file = presetFile ?? await _storageService.pickImage();
    if (file == null || !mounted) {
      return;
    }

    _safeSetState(() {
      _uploadingAvatarRole = role;
    });

    try {
      if (presetFile == null) {
        file = await _cropCountdownModeAvatarFile(file);
      }
      if (file == null) {
        return;
      }
      await PendingUploadService.instance.save(
        _pendingSpaceAvatarUploadKey,
        <String, dynamic>{
          'role': role,
          'filePath': file.path,
        },
      );
      final url = await _storageService.uploadImage(
        houseId,
        'avatars',
        file,
        quality: 88,
        minWidth: 720,
        minHeight: 720,
      );
      if (!mounted || url == null || url.trim().isEmpty) {
        if (mounted) {
          _showMessage(context.tr('home_khngticava_73ea14'));
        }
        return;
      }

      _safeSetState(() {
        if (isLeft) {
          _avatarUrl1 = url.trim();
        } else {
          _avatarUrl2 = url.trim();
        }
      });
      await _saveLocalSettings();
      await PendingUploadService.instance.clear(_pendingSpaceAvatarUploadKey);
    } catch (e) {
      _showMessage('Không thể đổi avatar: $e');
    } finally {
      if (mounted) {
        _safeSetState(() {
          _uploadingAvatarRole = null;
        });
      }
    }
  }

  Future<void> _updateCenterIconType(String type) async {
    final nextType = _normalizeCountdownModeCenterIconType(type);
    if (_centerIconType == nextType) {
      return;
    }
    _safeSetState(() {
      _centerIconType = nextType;
    });
    await _saveLocalSettings();
  }

  Future<void> _showAddSpaceDialog() async {
    if (_hasReachedSpaceLimit) {
      _showMessage(_spaceLimitMessage());
      return;
    }
    await _showAddSpaceDialogV2();
  }

  Future<void> _addSpaceByCode(String rawCode) async {
    await _addSpaceByCodeV2(rawCode);
  }

  Future<void> _showAddSpaceDialogV2() async {
    if (_hasReachedSpaceLimit) {
      _showMessage(_spaceLimitMessage());
      return;
    }
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CountdownSpaceAddDialog(
        decorationBuilder: _sheetDecoration,
        normalizeCode: _normalizeSpaceCode,
        validateLocalCode: _validateSpaceLookupLocally,
        onSubmitCode: (code) => _addSpaceByCodeV2(code, showFeedback: false),
      ),
    );
    if (message == null || !mounted) {
      return;
    }
    _showMessage(message);
  }

  String _normalizeSpaceCode(String rawCode) {
    return rawCode.trim();
  }

  String _normalizeResolvedSpaceHouseId(String rawHouseId) {
    return rawHouseId.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _normalizeSpaceLookupQuery(String rawInput) {
    final extracted = QRPayloadCodec.extractHouseId(rawInput) ?? rawInput;
    return extracted.replaceAll('@', '').trim();
  }

  Future<bool> _countdownSpaceHouseExists(String houseId) async {
    final normalized = _normalizeResolvedSpaceHouseId(houseId);
    if (normalized.isEmpty) {
      return false;
    }

    final publicSnap =
        await _countdownSpaceDbRef.child('houses_public/$normalized').get();
    return publicSnap.exists;
  }

  Future<String?> _resolveSpaceTargetHouseId(String rawInput) async {
    final directCandidate = QRPayloadCodec.extractHouseId(rawInput);
    if (directCandidate != null && directCandidate.trim().isNotEmpty) {
      final normalizedDirect = _normalizeResolvedSpaceHouseId(directCandidate);
      if (normalizedDirect.isNotEmpty &&
          await _countdownSpaceHouseExists(normalizedDirect)) {
        return normalizedDirect;
      }
    }

    final normalizedQuery = _normalizeSpaceLookupQuery(rawInput);
    if (normalizedQuery.isEmpty) {
      return null;
    }

    final results = await _spaceLookupService.searchHouses(
      normalizedQuery,
      limit: 8,
    );

    for (final item in results) {
      final id = item['id']?.toString().trim() ?? '';
      final username = item['username']?.toString().trim().toLowerCase() ?? '';
      if (id.isEmpty) {
        continue;
      }

      if (id.toLowerCase() == normalizedQuery.toLowerCase() ||
          username == normalizedQuery.toLowerCase()) {
        return _normalizeResolvedSpaceHouseId(id);
      }
    }

    return null;
  }

  String? _validateSpaceCodeLocally(String code) {
    if (code.isEmpty) {
      return context.tr('home_bnchanhpmn_f6c560');
    }
    if (!RegExp(r'^[A-Z0-9_-]{4,40}$').hasMatch(code)) {
      return 'Mã nhà chỉ gồm chữ, số, "_" hoặc "-". Ví dụ: NH_ABC123.';
    }
    if (_selfSpaceHouseId == 'local_self') {
      return context.tr('home_chaxcnhcmn_8d40ef');
    }
    if (code == _selfSpaceHouseId) {
      return context.tr('home_khngthghpv_ac8b30');
    }
    if (_spaceHouseIds
        .any((existing) => _normalizeSpaceCode(existing) == code)) {
      return 'Không gian với mã nhà "$code" đã có trong danh sách.';
    }
    return null;
  }

  String? _validateSpaceLookupLocally(String value) {
    if (value.trim().isEmpty) {
      return context.tr('home_bnchanhpmn_f6c560');
    }
    if (_selfSpaceHouseId == 'local_self') {
      return context.tr('home_chaxcnhcmn_8d40ef');
    }
    return null;
  }

  Future<_CountdownSpaceAddResult> _addSpaceByCodeV2(
    String rawCode, {
    bool showFeedback = true,
  }) async {
    final busyMessage = context.tr('home_angxlyucut_edb2fd');
    final notFoundMessage = context.tr('home_khngtmthyn_55dd98');
    final selfMessage = context.tr('home_khngthghpv_ac8b30');
    final successRequestMessage = context.tr('home_giyucughpn_d6a258');
    final fallbackMessage = context.tr('home_khngththmk_0bb09e');

    if (_isAddingSpace) {
      return _CountdownSpaceAddResult(
        success: false,
        message: busyMessage,
      );
    }

    final lookupValue = _normalizeSpaceCode(rawCode);
    final localError = _validateSpaceLookupLocally(lookupValue);
    if (localError != null) {
      if (showFeedback) {
        _showMessage(localError);
      }
      return _CountdownSpaceAddResult(success: false, message: localError);
    }

    if (_hasReachedSpaceLimit) {
      final limitMessage = _spaceLimitMessage();
      if (showFeedback) {
        _showMessage(limitMessage);
      }
      return _CountdownSpaceAddResult(
        success: false,
        message: limitMessage,
      );
    }

    _safeSetState(() => _isAddingSpace = true);
    try {
      final resolvedTargetHouseId =
          await _resolveSpaceTargetHouseId(lookupValue);
      if (resolvedTargetHouseId == null) {
        if (showFeedback) {
          _showMessage(notFoundMessage);
        }
        return _CountdownSpaceAddResult(
          success: false,
          message: notFoundMessage,
        );
      }

      if (resolvedTargetHouseId ==
          _normalizeResolvedSpaceHouseId(_selfSpaceHouseId)) {
        if (showFeedback) {
          _showMessage(selfMessage);
        }
        return _CountdownSpaceAddResult(
          success: false,
          message: selfMessage,
        );
      }

      if (_spaceHouseIds.any(
        (existing) =>
            _normalizeResolvedSpaceHouseId(existing) == resolvedTargetHouseId,
      )) {
        final duplicateMessage =
            'Không gian với mã nhà "$resolvedTargetHouseId" đã có trong danh sách.';
        if (showFeedback) {
          _showMessage(duplicateMessage);
        }
        return _CountdownSpaceAddResult(
          success: false,
          message: duplicateMessage,
        );
      }

      final requestResult = await _countdownSpaceService.sendRequest(
        fromHouseId: _selfSpaceHouseId,
        fromHouseName: _nameU1,
        toHouseId: resolvedTargetHouseId,
        initialSnapshot: _snapshotToSerializedMap(
          _spaceSnapshots[_selfSpaceHouseId] ?? _captureCurrentSnapshot(),
        ),
      );

      if (!requestResult.success) {
        if (showFeedback) {
          _showMessage(requestResult.message);
        }
        return _CountdownSpaceAddResult(
          success: false,
          message: requestResult.message,
        );
      }

      if (!mounted) {
        return _CountdownSpaceAddResult(
          success: true,
          message: successRequestMessage,
        );
      }

      _safeSetState(() {
        _optimisticPendingSpaceHouseIds.add(resolvedTargetHouseId);
        _spaceSnapshots[resolvedTargetHouseId] =
            _spaceSnapshots[_selfSpaceHouseId] ?? _captureCurrentSnapshot();
        _rebuildVisibleSpaces();
      });
      await _saveSpaceRegistry();

      final code = resolvedTargetHouseId;
      final successMessage =
          'Đã gửi yêu cầu ghép nối tới $code. Khi người kia chấp nhận, không gian này sẽ đồng bộ với bạn.';
      if (showFeedback) {
        _showMessage(successMessage);
      }
      return _CountdownSpaceAddResult(
        success: true,
        message: successMessage,
      );
    } catch (_) {
      if (showFeedback) {
        _showMessage(fallbackMessage);
      }
      return _CountdownSpaceAddResult(
        success: false,
        message: fallbackMessage,
      );
    } finally {
      if (mounted) {
        _safeSetState(() => _isAddingSpace = false);
      }
    }
  }

  Future<void> _showRenameSpaceDialog(String houseId) async {
    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _CountdownSpaceRenameDialog(
        initialName: _spaceDisplayNames[houseId] ?? '',
        decorationBuilder: _sheetDecoration,
      ),
    );
    if (nextName == null) {
      return;
    }
    await _renameSpace(houseId, nextName);
  }

  Future<void> _renameSpace(String houseId, String name) async {
    if (!mounted) return;
    _safeSetState(() {
      if (name.isEmpty) {
        _spaceDisplayNames.remove(houseId);
      } else {
        _spaceDisplayNames[houseId] = name;
      }
    });
    await _saveSpaceRegistry();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isHandlingSpaceRequest(String requestId) {
    return _spaceRequestActionIds.contains(requestId.trim());
  }

  Future<void> _showIncomingSpaceRequestDialog(String houseId) async {
    final request = _incomingRequestFor(houseId);
    if (request == null || _isHandlingSpaceRequest(request.requestId)) {
      return;
    }

    final senderLabel = request.fromHouseName.trim().isNotEmpty
        ? request.fromHouseName.trim()
        : request.fromHouseId;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('home_yucughpni_6a3807')),
        content: Text(
          '$senderLabel đang muốn ghép nối không gian đếm với nhà của bạn.\n\n'
          'Mã nhà: ${request.fromHouseId}\n\n${context.tr('home_nuchpnhnha_5e7057')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('home_tchi_2119d8')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('home_chpnhn_6ca558')),
          ),
        ],
      ),
    );
    if (accepted == null) {
      return;
    }
    await _respondToIncomingSpaceRequest(request, accept: accepted);
  }

  Future<void> _respondToIncomingSpaceRequest(
    CountdownSpaceRequestInfo request, {
    required bool accept,
  }) async {
    if (_isHandlingSpaceRequest(request.requestId)) {
      return;
    }

    _safeSetState(() {
      _spaceRequestActionIds.add(request.requestId);
    });

    try {
      final result = accept
          ? await _countdownSpaceService.acceptRequest(
              requestId: request.requestId,
              currentHouseId: _selfSpaceHouseId,
              myHouseName: _nameU1,
            )
          : await _countdownSpaceService.declineRequest(
              requestId: request.requestId,
              currentHouseId: _selfSpaceHouseId,
            );

      if (!mounted) {
        return;
      }

      if (!result.success) {
        _showMessage(result.message);
        return;
      }

      _showMessage(
        accept
            ? context.tr('home_chpnhnghpn_3a4753')
            : context.tr('home_tchiyucugh_13e5c2'),
      );
    } finally {
      if (mounted) {
        _safeSetState(() {
          _spaceRequestActionIds.remove(request.requestId);
        });
      }
    }
  }

  Future<void> _requestDeleteCurrentSpace(String houseId) async {
    final sharedSpace = _sharedSpaceFor(houseId);
    if (houseId == _selfSpaceHouseId || sharedSpace == null) {
      _showMessage(context.tr('home_chkhnggian_13d818'));
      return;
    }
    if (_deleteRequestFor(houseId) != null) {
      _showMessage(_deleteStatusDescription(houseId));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('home_giyucuxa_d2e564')),
        content: Text(
          'Yêu cầu này sẽ được gửi tới ${_spaceTitle(houseId)}.\n\n${context.tr('home_nubnkiaxcn_9458c0')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('home_hy_1e4050')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('home_giyucu_576885')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final result = await _countdownSpaceService.requestDelete(
      spaceId: sharedSpace.spaceId,
      currentHouseId: _selfSpaceHouseId,
      currentHouseName: _nameU1,
    );
    if (!mounted) {
      return;
    }
    _showMessage(result.message);
  }

  Future<void> _acceptDeleteCurrentSpace(String houseId) async {
    final request = _deleteRequestFor(houseId);
    if (request == null) {
      _showMessage(context.tr('home_yucuxakhng_da2f6d'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('home_xcnhnxakhn_2ac5a7')),
        content: Text(
          'Không gian ${_spaceTitle(houseId)} sẽ bị xóa cho cả hai bên ngay sau khi bạn xác nhận.\n\n${context.tr('home_nubnchamun_57d743')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('home_sau_8a3721')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: Text(context.tr('home_xangay_dc07fa')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final result = await _countdownSpaceService.acceptDelete(
      spaceId: request.spaceId,
      currentHouseId: _selfSpaceHouseId,
    );
    if (!mounted) {
      return;
    }
    if (result.success && _openedSpaceHouseId == houseId) {
      _safeSetState(() {
        _openedSpaceHouseId = null;
        _spaceChromeVisible = true;
        _applySnapshot(_spaceSnapshotFor(_selfSpaceHouseId));
      });
    }
    _showMessage(result.message);
  }

  InputDecoration _sheetDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      labelStyle: SLTheme.quicksand(
        color: Colors.white70,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: SLTheme.quicksand(
        color: Colors.white38,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4BA7FF), width: 1.5),
      ),
    );
  }

  String _spaceTitle(String houseId) {
    final alias = (_spaceDisplayNames[houseId] ?? '').trim();
    if (alias.isNotEmpty) return alias;
    final incomingLabel =
        (_incomingSpaceRequests[houseId.trim()]?.fromHouseName ?? '').trim();
    if (incomingLabel.isNotEmpty) return incomingLabel;
    if (houseId == _selfSpaceHouseId) {
      return _nameU1.trim().isEmpty ? context.tr('home_khnggianca_3f6e45') : _nameU1.trim();
    }
    return houseId.length > 14 ? '${houseId.substring(0, 14)}…' : houseId;
  }

  CountdownSpaceRequestInfo? _pendingRequestFor(String houseId) {
    return _pendingSpaceRequests[houseId.trim()];
  }

  CountdownSpaceRequestInfo? _incomingRequestFor(String houseId) {
    return _incomingSpaceRequests[houseId.trim()];
  }

  CountdownSpaceInfo? _sharedSpaceFor(String houseId) {
    return _sharedSpaces[houseId.trim()];
  }

  CountdownSpaceDeleteRequestInfo? _deleteRequestFor(String houseId) {
    return _deleteSpaceRequests[houseId.trim()];
  }

  bool get _hasReachedSpaceLimit =>
      _spaceHouseIds.length >= _CountdownModeIndependentScreenState._maxSpaces;

  String _spaceLimitMessage() {
    return 'Bạn chỉ có thể dùng tối đa ${_CountdownModeIndependentScreenState._maxSpaces} không gian. Hãy mở Cài đặt của một không gian đã ghép để gửi yêu cầu xóa. Không gian sẽ xóa ngay khi bên kia chấp nhận hoặc tự xóa sau 15 ngày.';
  }

  bool _hasDeleteRequest(String houseId) {
    return _deleteRequestFor(houseId) != null;
  }

  String _formatSpaceDeleteDateTime(int value) {
    if (value <= 0) {
      return context.tr('home_khngxcnh_fb806e');
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(value);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} lúc $hour:$minute';
  }

  String _deleteStatusTitle(String houseId) {
    final request = _deleteRequestFor(houseId);
    if (request == null) {
      return '';
    }
    if (request.isRequestedBy(_selfSpaceHouseId)) {
      return context.tr('home_angchxakhn_f26cbb');
    }
    return context.tr('home_bnkiaangch_b287d3');
  }

  String _deleteStatusDescription(String houseId) {
    final request = _deleteRequestFor(houseId);
    if (request == null) {
      return '';
    }
    final deadlineLabel = _formatSpaceDeleteDateTime(request.deleteAt);
    if (request.isRequestedBy(_selfSpaceHouseId)) {
      return 'Yêu cầu đã được gửi. Nếu bên kia chưa xác nhận, không gian sẽ tự xóa vào $deadlineLabel.';
    }
    return 'Bạn có thể xác nhận xóa ngay trong phần cài đặt. Nếu chưa xác nhận, không gian sẽ tự xóa vào $deadlineLabel.';
  }

  bool _hasIncomingSpaceRequest(String houseId) {
    return _incomingRequestFor(houseId) != null;
  }

  bool _hasPendingSpaceRequest(String houseId) {
    return _pendingRequestFor(houseId) != null ||
        _optimisticPendingSpaceHouseIds.contains(houseId.trim());
  }

  bool _isSharedSpace(String houseId) {
    return _sharedSpaceFor(houseId) != null;
  }

  String _spaceConnectionStatusText(String houseId) {
    if (houseId == _selfSpaceHouseId) {
      return context.tr('home_khnggianri_5aa2fb');
    }
    if (_hasIncomingSpaceRequest(houseId)) {
      return context.tr('home_chbnchpnhn_ea7846');
    }
    if (_isSharedSpace(houseId)) {
      return context.tr('home_ghpni_369328');
    }
    if (_hasPendingSpaceRequest(houseId)) {
      return context.tr('home_giangch_2628ca');
    }
    return context.tr('home_chaghpni_70d9cc');
  }

  Color _spaceAccentColor(String houseId) {
    if (_isSharedSpace(houseId) || houseId == _selfSpaceHouseId) {
      return const Color(0xFF4BA7FF);
    }
    if (_hasIncomingSpaceRequest(houseId) || _hasPendingSpaceRequest(houseId)) {
      return const Color(0xFFFFB74D);
    }
    return const Color(0xFF94A3B8);
  }

  String _spaceStatusText(String houseId) {
    if (houseId == _selfSpaceHouseId) {
      return context.tr('home_ccb_60e080');
    }
    return _acceptedSpaceHouseIds.contains(houseId) ? context.tr('home_ghp_835f82') : context.tr('home_chghp_6e894c');
  }

  String _spaceConnectionStatusLabel(String houseId) {
    if (houseId == _selfSpaceHouseId) {
      return context.tr('home_khnggianri_5aa2fb');
    }
    if (_hasDeleteRequest(houseId)) {
      final request = _deleteRequestFor(houseId)!;
      return request.isRequestedBy(_selfSpaceHouseId)
          ? context.tr('home_angchxa_313854')
          : context.tr('home_chbnxcnhnx_2a7e54');
    }
    if (_hasIncomingSpaceRequest(houseId)) {
      return context.tr('home_chbnchpnhn_ea7846');
    }
    if (_isSharedSpace(houseId)) {
      return context.tr('home_ghpni_369328');
    }
    if (_hasPendingSpaceRequest(houseId)) {
      return context.tr('home_giangch_2628ca');
    }
    return context.tr('home_chaghpni_70d9cc');
  }

  Color _spaceAccentColorResolved(String houseId) {
    if (_hasDeleteRequest(houseId)) {
      return const Color(0xFFE85D75);
    }
    if (_isSharedSpace(houseId) || houseId == _selfSpaceHouseId) {
      return const Color(0xFF4BA7FF);
    }
    if (_hasIncomingSpaceRequest(houseId) || _hasPendingSpaceRequest(houseId)) {
      return const Color(0xFFFFB74D);
    }
    return const Color(0xFF94A3B8);
  }

  String _topLabel() {
    return _topLabelText.trim().isEmpty
        ? (_singleMode ? context.tr('home_tuicati_5c654c') : context.tr('home_yunhau_501102'))
        : _topLabelText.trim();
  }

  String _bottomLabel() {
    return _bottomLabelText.trim().isEmpty
        ? (_singleMode ? context.tr('home_ngytui_22bed4') : context.tr('home_ngy_41ec10'))
        : _bottomLabelText.trim();
  }

  String _previewTopLabel(_CountdownSpaceSnapshot snapshot) {
    return snapshot.topLabel.trim().isEmpty
        ? (snapshot.singleMode ? context.tr('home_tuicati_5c654c') : context.tr('home_yunhau_501102'))
        : snapshot.topLabel.trim();
  }

  String _previewBottomLabel(_CountdownSpaceSnapshot snapshot) {
    return snapshot.bottomLabel.trim().isEmpty
        ? (snapshot.singleMode ? context.tr('home_ngytui_22bed4') : context.tr('home_ngy_41ec10'))
        : snapshot.bottomLabel.trim();
  }

  String _previewCaption(DateTime? anchorDate) {
    if (anchorDate == null) {
      return context.tr('home_chmvothchn_6b1d87');
    }
    return 'Từ ${DateInputUtils.formatDisplayDate(anchorDate)}';
  }

  int _daysSince(DateTime startDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalized = DateTime(startDate.year, startDate.month, startDate.day);
    final days = today.difference(normalized).inDays;
    return days < 0 ? 0 : days;
  }

  String _caption(BuildContext context) {
    if (_anchorDate == null) {
      return context.tr('home_chmvothchn_6b1d87');
    }
    return 'Từ ${DateInputUtils.formatDisplayDate(_anchorDate!)}';
  }
}
