// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../main_home_tab.dart';

extension _MainHomeTabDialogs on _MainHomeTabState {
  Future<void> _maybeShowFirstSetupGuide() async {}

  Future<void> _markFirstSetupGuideSeen(String houseId) async {}

  Future<void> _showFirstSetupGuideDialog({required String houseId}) async {
    final guideSteps = <({IconData icon, String title, String body})>[
      (
        icon: Icons.favorite_rounded,
        title: context.tr('home_chomngbnnv_7ffc51'),
        body: context.tr('home_ylhngdnnha_b558ac'),
      ),
      (
        icon: Icons.track_changes_rounded,
        title: context.tr('home_vngmngyyu_68e244'),
        body: context.tr('home_vngckhoanh_623126'),
      ),
      (
        icon: Icons.edit_calendar_rounded,
        title: context.tr('home_bmvochnhch_0d6ef0'),
        body: context.tr('home_bmsngychnh_cf2261'),
      ),
      (
        icon: Icons.apps_rounded,
        title: context.tr('home_cckhuvcchn_6df4cf'),
        body: context.tr('home_nhtkalbumk_6c939f'),
      ),
    ];
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        var stepIndex = 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final step = guideSteps[stepIndex];
            final isLastStep = stepIndex == guideSteps.length - 1;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
              title: Text(
                step.title,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  color: SLTheme.primary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SLTheme.primary.withValues(alpha: 0.08),
                        border: Border.all(
                          color: SLTheme.primary.withValues(alpha: 0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SLTheme.primary.withValues(alpha: 0.12),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: stepIndex == 1
                            ? Text(
                                '520\nngày yêu',
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900,
                                  color: SLTheme.primary,
                                ),
                              )
                            : Icon(
                                step.icon,
                                size: 44,
                                color: SLTheme.primary,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    step.body,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w700,
                      color: SLColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < guideSteps.length; index++)
                        Container(
                          width: index == stepIndex ? 18 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: index == stepIndex
                                ? SLTheme.primary
                                : SLTheme.primary.withValues(alpha: 0.22),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(dialogContext);
                    await _markFirstSetupGuideSeen(houseId);
                    if (navigator.canPop()) {
                      navigator.pop();
                    }
                  },
                  child: Text(
                    context.tr('home_bqua_a3b533'),
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                ),
                if (stepIndex == 2)
                  FilledButton(
                    onPressed: () async {
                      final navigator = Navigator.of(dialogContext);
                      await _markFirstSetupGuideSeen(houseId);
                      if (navigator.canPop()) {
                        navigator.pop();
                      }
                      if (mounted) {
                        _showCountdownQuickCustomizeSheet();
                      }
                    },
                    child: Text(
                      context.tr('home_thchnh_5c36f2'),
                      style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: () async {
                      if (isLastStep) {
                        final navigator = Navigator.of(dialogContext);
                        await _markFirstSetupGuideSeen(houseId);
                        if (navigator.canPop()) {
                          navigator.pop();
                        }
                        return;
                      }
                      setDialogState(() => stepIndex += 1);
                    },
                    child: Text(
                      isLastStep ? 'Xong' : context.tr('home_tiptc_555f1f'),
                      style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _shortErrorMessage(dynamic error, String fallbackMessage) {
    if (kDebugMode) {
      final rawMessage = AppErrorMapper.cleanMessage(error);
      if (rawMessage.isNotEmpty) {
        return rawMessage;
      }
    }
    final info = AppErrorMapper.resolve(
      error,
      fallbackMessage: fallbackMessage,
    );
    final message = info.message.trim();
    return message.isEmpty ? fallbackMessage : message;
  }

  Future<void> _showUpcomingDatingFeature() async {
    _showUpcomingDatingFeatureLegacy();
  }

  void _showUpcomingDatingFeatureLegacy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        title: Text(
          context.tr('home_tnhnngangp_4c4164'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: SLTheme.primary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_chat_rounded,
                  size: 64, color: SLTheme.primary),
              SLSpacing.h16,
              Text(
                context.tr('home_hthngghpig_fe040c'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SLSpacing.h12,
              Text(
                context.tr('home_tnhnngnysg_2c2ec5'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: SLTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: SLRadius.lgAll,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                context.tr('home_hiu_93c4c0'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleInteractionLongPressStart(LongPressStartDetails details) {
    _showInteractionDragOverlay(details.globalPosition);
  }

  void _handleInteractionLongPressMoveUpdate(
    LongPressMoveUpdateDetails details,
  ) {
    _updateInteractionDragSelection(details.globalPosition);
  }

  void _handleInteractionLongPressEnd(LongPressEndDetails details) {
    final selectedType = _interactionDragHoveredType;
    _hideInteractionDragOverlay();
    
    if (selectedType == 'edit_stickers') {
      _openStickerCustomization();
      return;
    }
    
    final preset = selectedType == null
        ? null
        : _maybePresetForInteractionType(selectedType);
    if (preset != null) {
      _setManualInteractionPreset(preset.type);
      _handleSendInteraction(preset.type, preset.emoji);
    }
  }

  void _openStickerCustomization() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const InteractionStickerEditorScreen(),
      ),
    ).then((updated) async {
      if (updated == true && mounted) {
        await _loadCustomStickers();
        setState(() {});
      }
    });
  }

  void _handleInteractionLongPressCancel() {
    _hideInteractionDragOverlay();
  }

  void _showInteractionDragOverlay(Offset globalPosition) {
    _hideInteractionDragOverlay();
    final overlay = Overlay.of(context, rootOverlay: true);

    _interactionDragMenuOptions = List<_PartnerInteractionPreset>.from(
      _kPartnerInteractionPresets,
    );
    _interactionDragPointerGlobal = globalPosition;
    _interactionDragHoveredType = null;
    _interactionDragHoveredNotifier.value = null;
    _interactionDragOptionRects.clear();
    _interactionDragOptionHitRects.clear();
    _interactionDragOptionKeys
      ..clear()
      ..addEntries(
        _interactionDragMenuOptions.map(
          (preset) => MapEntry(preset.type, GlobalKey()),
        ),
      );
    _interactionDragOptionKeys['edit_stickers'] = GlobalKey();

    _interactionDragOverlayEntry = OverlayEntry(
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Nền mờ – chạm vào để đóng menu
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _hideInteractionDragOverlay,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, 56),
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<String?>(
                        valueListenable: _interactionDragHoveredNotifier,
                        builder: (context, hoveredType, _) {
                          return Container(
                            constraints: const BoxConstraints(
                              maxWidth: 404,
                              minHeight: 224,
                            ),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.fromLTRB(
                              20,
                              20,
                              20,
                              20,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBFC).withValues(
                                alpha: 0.98,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1F2937)
                                      .withValues(alpha: 0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFFF1DDE5),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _interactionDragMenuOptions.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.92,
                                      ),
                                      itemBuilder: (context, index) {
                                        final preset =
                                            _interactionDragMenuOptions[index];
                                        final isHovered =
                                            hoveredType == preset.type;
                                        return _buildInteractionDragOption(
                                          preset,
                                          key: _interactionDragOptionKeys[
                                              preset.type],
                                          highlighted: isHovered,
                                          onTap: () {
                                            _setManualInteractionPreset(
                                                preset.type);
                                            _hideInteractionDragOverlay();
                                            _handleSendInteraction(
                                                preset.type, preset.emoji);
                                          },
                                        );
                                      },
                                    ),
                                    FutureBuilder<bool>(
                                      future: kDebugMode ? Future.value(true) : PurchaseService().isVip(),
                                      initialData: kDebugMode,
                                      builder: (context, snapshot) {
                                        if (snapshot.data != true) return const SizedBox.shrink();
                                        return ValueListenableBuilder<String?>(
                                          valueListenable: _interactionDragHoveredNotifier,
                                          builder: (context, hoveredVal, _) {
                                            final isHovered = hoveredVal == 'edit_stickers';
                                            return GestureDetector(
                                              onTap: () {
                                                _hideInteractionDragOverlay();
                                                _openStickerCustomization();
                                              },
                                              child: AnimatedScale(
                                                scale: isHovered ? 1.2 : 1.0,
                                                duration: const Duration(milliseconds: 200),
                                                curve: Curves.easeOutBack,
                                                child: Container(
                                                  key: _interactionDragOptionKeys['edit_stickers'],
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF4CAF50),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                    border: Border.all(color: Colors.white, width: 1.5),
                                                  ),
                                                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_interactionDragOverlayEntry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheInteractionDragOptionRects();
      if (_interactionDragPointerGlobal != null) {
        _updateInteractionDragSelection(
          _interactionDragPointerGlobal!,
          triggerHaptic: false,
        );
      }
    });
  }

  void _cacheInteractionDragOptionRects() {
    _interactionDragOptionRects.clear();
    _interactionDragOptionHitRects.clear();
    for (final entry in _interactionDragOptionKeys.entries) {
      final ctx = entry.value.currentContext;
      final renderObject = ctx?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final offset = renderObject.localToGlobal(Offset.zero);
      final rect = offset & renderObject.size;
      _interactionDragOptionRects[entry.key] = rect;
      _interactionDragOptionHitRects[entry.key] = rect.inflate(18);
    }
  }

  void _updateInteractionDragSelection(
    Offset globalPosition, {
    bool triggerHaptic = true,
  }) {
    _interactionDragPointerGlobal = globalPosition;
    if (_interactionDragOverlayEntry == null) return;
    if (_interactionDragOptionHitRects.isEmpty) {
      _cacheInteractionDragOptionRects();
    }

    String? hoveredType;
    final editRect = _interactionDragOptionHitRects['edit_stickers'];
    if (editRect != null && editRect.contains(globalPosition)) {
      hoveredType = 'edit_stickers';
    } else {
      for (final preset in _interactionDragMenuOptions) {
        final rect = _interactionDragOptionHitRects[preset.type];
        if (rect != null && rect.contains(globalPosition)) {
          hoveredType = preset.type;
          break;
        }
      }
    }

    if (_interactionDragHoveredType == hoveredType) return;
    _interactionDragHoveredType = hoveredType;
    _interactionDragHoveredNotifier.value = hoveredType;
    if (triggerHaptic && hoveredType != null) {
      HapticFeedback.selectionClick();
    }
  }

  void _hideInteractionDragOverlay() {
    _interactionDragOverlayEntry?.remove();
    _interactionDragOverlayEntry = null;
    _interactionDragOptionKeys.clear();
    _interactionDragOptionRects.clear();
    _interactionDragOptionHitRects.clear();
    _interactionDragMenuOptions = const <_PartnerInteractionPreset>[];
    _interactionDragHoveredType = null;
    _interactionDragHoveredNotifier.value = null;
    _interactionDragPointerGlobal = null;
  }

  Widget _buildInteractionDragOption(
    _PartnerInteractionPreset preset, {
    required Key? key,
    required bool highlighted,
    VoidCallback? onTap,
  }) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          key: key,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tileSize = constraints.biggest.shortestSide;
              final visualSize = (tileSize * 0.88).clamp(56.0, 72.0);
              final emojiSize = (visualSize * 0.58).clamp(28.0, 36.0);
              const padding = 10.0;

              return Center(
                child: AnimatedScale(
                  scale: highlighted ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: visualSize,
                    height: visualSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: preset.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: highlighted
                            ? preset.accent.withValues(alpha: 0.78)
                            : const Color(0xFFF3E6EC),
                        width: highlighted ? 2.1 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: preset.accent.withValues(
                            alpha: highlighted ? 0.18 : 0.08,
                          ),
                          blurRadius: highlighted ? 16 : 10,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(padding),
                      child: _buildInteractionVisual(
                        visual: preset.emoji,
                        assetPath: preset.assetPath,
                        size: visualSize,
                        emojiSize: emojiSize,
                        preferAsset: true,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showOutgoingInteractionNotice({
    required String interactionType,
    required String title,
    required String body,
    required String partnerName,
    required bool partnerOnline,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final preset = _presetForInteractionType(interactionType);
    messenger
      ..clearSnackBars()
      ..removeCurrentSnackBar()
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          duration: const Duration(milliseconds: 2200),
          backgroundColor: Colors.transparent,
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.sizeOf(context).height -
                (MediaQuery.paddingOf(context).top + 168),
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  preset.gradient.last.withValues(alpha: 0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: preset.accent.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: preset.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: _buildInteractionVisual(
                      visual: preset.emoji,
                      assetPath: preset.assetPath,
                      size: 24,
                      emojiSize: 22,
                      preferAsset: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: preset.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        partnerOnline
                            ? '$partnerName sẽ thấy ngay'
                            : 'Đã gửi cho $partnerName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B7280),
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
  }

  void _showMissYouScreen(_MissYouAlertPayload payload) async {
    final prefs = await OfflineCacheService.getPrefs();
    final lastTimeMs = prefs.getInt('il_last_missyou_time_v2') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    
    if (nowMs - lastTimeMs < 3600000) {
      return;
    }
    
    await prefs.setInt('il_last_missyou_time_v2', nowMs);
    if (!mounted) return;

    if (_incomingInteractionDialogVisible) {
      _incomingInteractionQueue.add(payload);
      return;
    }

    _presentMissYouScreen(payload);
  }

  void _presentMissYouScreen(_MissYouAlertPayload payload) {
    _incomingInteractionDialogTimer?.cancel();
    _incomingInteractionDialogVisible = true;
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black87,
      builder: (context) => _MissYouScreen(payload: payload),
    ).whenComplete(() {
      _incomingInteractionDialogTimer?.cancel();
      _incomingInteractionDialogTimer = null;
      _incomingInteractionDialogVisible = false;
      if (!mounted || !_isTabActive) {
        _incomingInteractionQueue.clear();
        return;
      }
      if (_incomingInteractionQueue.isEmpty) return;
      final nextPayload = _incomingInteractionQueue.removeAt(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isTabActive) return;
        _presentMissYouScreen(nextPayload);
      });
    });
    _incomingInteractionDialogTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !_incomingInteractionDialogVisible) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  Future<void> _showEditStartDateDialog() async {
    final msgDatingCooldown = context.tr('home_bncnch3ngy_4b578b');
    final msgConfirmTitle = context.tr('home_lu_3b8e18');
    final msgConfirmBody = context.tr('home_nubnitipbn_4888b3');
    final msgCancel = context.tr('home_hy_1e4050');
    final msgContinue = context.tr('home_itip_ed5193');
    final msgUpdated = context.tr('home_cpnhtngybt_e362b6');
    final msgUpdateFailed = context.tr('home_khngcpnhtc_f5e2a0');

    if (_houseId == null) return;
    final curStartDate = _houseSettings?['startDate']?.toString() ?? '';
    DateTime initialDate = DateTime.now();
    if (curStartDate.isNotEmpty) {
      initialDate = DateTime.tryParse(curStartDate) ?? DateTime.now();
    }

    // Lưu context-dependent objects trước async gap
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFD81B60),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (!mounted) return;
    if (picked != null) {
      final newDateStr = picked.toIso8601String().split('T')[0];
      try {
        final policy =
            await _houseSettingsService.getStartDateChangePolicy(_houseId!);
        final cooldownUntil = policy['cooldownUntil'] as int?;
        if (policy['isLocked'] == true) {
          final unlockAt = cooldownUntil == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(cooldownUntil);
          final message = unlockAt == null
              ? msgDatingCooldown
              : 'Bạn cần chờ đến ${unlockAt.day}/${unlockAt.month}/${unlockAt.year} mới có thể đổi ngày yêu tiếp.';
          scaffoldMessenger?.showSnackBar(SnackBar(content: Text(message)));
          return;
        }

        var startCooldown = false;
        if (policy['shouldWarn'] == true) {
          if (!mounted) return;
          final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(msgConfirmTitle),
                  content: Text(
                    msgConfirmBody,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(msgCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(msgContinue),
                    ),
                  ],
                ),
              ) ??
              false;
          if (!confirmed) return;
          startCooldown = true;
        }
        await _houseSettingsService.updateStartDate(
          _houseId!,
          newDateStr,
          startCooldown: startCooldown,
        );
        if (!mounted) return;

        // Optimistic UI update
        _safeSetState(() {
          if (_houseSettings != null) {
            _houseSettings!['startDate'] = newDateStr;
          }
        });

        scaffoldMessenger?.showSnackBar(
          SnackBar(content: Text(msgUpdated)),
        );
      } catch (e) {
        if (!mounted) return;
        final message = _shortErrorMessage(
          e,
          msgUpdateFailed,
        );
        scaffoldMessenger?.showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _showEditCountdownLabelDialog({
    required bool editTopLabel,
    required String currentLabel,
  }) {
    if (_houseId == null) return;

    final controller = TextEditingController(text: currentLabel);
    final dialogTitle = editTopLabel
        ? context.tr('home_ichphatrn_2b9989')
        : context.tr('home_ichphadi_5a1c20');
    final hintText = editTopLabel
        ? context.tr('home_vdbnnhau_998f24')
        : context.tr('home_vdngyyu_f3c8aa');

    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        title: Text(
          dialogTitle,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: SLTheme.primary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ctx.tr('home_trngsquayv_97516b'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 22,
                textAlign: TextAlign.center,
                textCapitalization: editTopLabel
                    ? TextCapitalization.characters
                    : TextCapitalization.sentences,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: SLTheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              ctx.tr('home_hy_1e4050'),
              style: SLTheme.quicksand(
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newLabel = controller.text.trim();
              Navigator.pop(ctx, newLabel);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SLTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              ctx.tr('home_lu_49fac1'),
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ).then((newLabel) async {
      if (newLabel == null || newLabel.isEmpty || !mounted) {
        return;
      }

      try {
        await _houseSettingsService.updateCountdownLabels(
          houseId: _houseId!,
          topLabel: editTopLabel ? newLabel : null,
          bottomLabel: editTopLabel ? null : newLabel,
        );

        // Optimistic UI update
        _safeSetState(() {
          if (_houseSettings != null) {
            if (editTopLabel) {
              _houseSettings!['countdownTopLabel'] = newLabel;
              _houseSettings!['greetingQuote'] = newLabel;
            } else {
              _houseSettings!['countdownBottomLabel'] = newLabel;
              _houseSettings!['dayUnit'] = newLabel;
            }
          }
        });
      } catch (e) {
        if (!mounted) return;
        final message = _shortErrorMessage(
          e,
          context.tr('home_khnglucnhn_0689c8'),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }).whenComplete(controller.dispose);
  }

  void _showEditNameDialog(
      {required bool isUser1, required String currentName}) {
    if (_houseId == null) return;
    final controller = TextEditingController(text: currentName);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        title: Text(
          ctx.tr('home_ibitdanh_345585'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: SLTheme.primary,
          ),
        ),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 18),
          decoration: InputDecoration(
            hintText: ctx.tr('home_nhptnmi_1b6bb3'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: SLTheme.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('home_hy_1e4050'),
                style: SLTheme.quicksand(
                    color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              Navigator.pop(ctx, newName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SLTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(ctx.tr('home_lu_49fac1'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ).then((newName) async {
      if (newName == null || newName.isEmpty || !mounted) return;
      final field = isUser1 ? 'nameU1' : 'nameU2';
      final updates = {
        'houses/$_houseId/settings/$field': newName,
        'house_profiles/$_houseId/$field': newName,
        'house_profiles/$_houseId/settings/$field': newName,
        'houses/$_houseId/updatedAt': ServerValue.timestamp,
      };
      await _dbRef.update(updates);
    }).whenComplete(controller.dispose);
  }
}
