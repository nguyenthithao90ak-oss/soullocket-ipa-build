// ignore_for_file: unused_element

part of '../../main_home_tab.dart';

extension _MainHomeTabDialogs on _MainHomeTabState {
  Future<void> _maybeShowFirstSetupGuide() async {
    final houseId = _houseId?.trim() ?? '';
    if (houseId.isEmpty || _firstSetupGuidePrompting || !_isTabActive) return;

    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final pendingKey = '$_firstSetupGuidePendingPrefsPrefix$houseId';
    final seenKey = '$_firstSetupGuideSeenPrefsPrefix$houseId';
    final isPending = (prefs.getString(pendingKey) ?? '').trim() == '1';
    final isSeen = (prefs.getString(seenKey) ?? '').trim() == '1' ||
        (prefs.getBool(seenKey) ?? false);
    if (!isPending || isSeen || !mounted) return;

    _firstSetupGuidePrompting = true;
    try {
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted || !_isTabActive) return;
      await _showFirstSetupGuideDialog(houseId: houseId);
    } finally {
      _firstSetupGuidePrompting = false;
    }
  }

  Future<void> _markFirstSetupGuideSeen(String houseId) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString('$_firstSetupGuideSeenPrefsPrefix$houseId', '1');
    await prefs.remove('$_firstSetupGuidePendingPrefsPrefix$houseId');
  }

  Future<void> _showFirstSetupGuideDialog({required String houseId}) async {
    final guideSteps = <({IconData icon, String title, String body})>[
      (
        icon: Icons.favorite_rounded,
        title: 'Chào mừng bạn đến với ngôi nhà mới',
        body:
            'Đây là hướng dẫn nhanh cho lần đầu dùng app. Bạn có thể bỏ qua hoặc xem từng bước.',
      ),
      (
        icon: Icons.track_changes_rounded,
        title: 'Vòng đếm ngày yêu',
        body:
            'Vùng được khoanh là nơi hiển thị số ngày bên nhau. Ví dụ: 520 ngày yêu.',
      ),
      (
        icon: Icons.edit_calendar_rounded,
        title: 'Bấm vào để chỉnh chữ và ngày',
        body:
            'Bấm số ngày để chỉnh ngày bắt đầu. Bấm chữ phía trên hoặc phía dưới để đổi “bên nhau”, “ngày yêu”.',
      ),
      (
        icon: Icons.apps_rounded,
        title: 'Các khu vực chính',
        body:
            'Nhật ký, album/kỷ niệm, cài đặt và bảo mật nằm ở các tab/chức năng bên dưới. Bạn có thể mở lại tài liệu hướng dẫn trong Cài đặt.',
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
                        color: SLTheme.primary.withOpacity(0.08),
                        border: Border.all(
                          color: SLTheme.primary.withOpacity(0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SLTheme.primary.withOpacity(0.12),
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
                                : SLTheme.primary.withOpacity(0.22),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await _markFirstSetupGuideSeen(houseId);
                    if (Navigator.of(dialogContext).canPop()) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(
                    'Bỏ qua',
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                ),
                if (stepIndex == 2)
                  FilledButton(
                    onPressed: () async {
                      await _markFirstSetupGuideSeen(houseId);
                      if (Navigator.of(dialogContext).canPop()) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (mounted) {
                        _showCountdownQuickCustomizeSheet();
                      }
                    },
                    child: Text(
                      'Thử chỉnh',
                      style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: () async {
                      if (isLastStep) {
                        await _markFirstSetupGuideSeen(houseId);
                        if (Navigator.of(dialogContext).canPop()) {
                          Navigator.of(dialogContext).pop();
                        }
                        return;
                      }
                      setDialogState(() => stepIndex += 1);
                    },
                    child: Text(
                      isLastStep ? 'Xong' : 'Tiếp tục',
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
          'Tính năng đang phát triển',
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
                'Hệ thống ghép đôi gọi video ngẫu nhiên',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SLSpacing.h12,
              Text(
                'Tính năng này sẽ giúp bạn ghép nối ngẫu nhiên và an toàn với những người dùng độc thân khác phù hợp về độ tuổi và sở thích. Sẽ ra mắt trong phiên bản sắp tới, hãy cùng chờ đón nhé!',
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
                'Đã hiểu',
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
    final preset = selectedType == null
        ? null
        : _maybePresetForInteractionType(selectedType);
    _hideInteractionDragOverlay();
    if (preset != null) {
      _setManualInteractionPreset(preset.type);
      _handleSendInteraction(preset.type, preset.emoji);
    }
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

    _interactionDragOverlayEntry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.14),
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
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                20,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBFC).withOpacity(
                                  0.98,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1F2937)
                                        .withOpacity(0.08),
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
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount:
                                        _interactionDragMenuOptions.length,
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
                                      );
                                    },
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
    for (final preset in _interactionDragMenuOptions) {
      final rect = _interactionDragOptionHitRects[preset.type];
      if (rect != null && rect.contains(globalPosition)) {
        hoveredType = preset.type;
        break;
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
  }) {
    return RepaintBoundary(
      child: SizedBox(
        key: key,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileSize = constraints.biggest.shortestSide;
            final visualSize =
                (tileSize * (highlighted ? 0.94 : 0.88)).clamp(56.0, 72.0);
            final emojiSize =
                (visualSize * (highlighted ? 0.62 : 0.58)).clamp(28.0, 36.0);
            final padding = highlighted ? 8.0 : 10.0;

            return Center(
              child: AnimatedScale(
                scale: highlighted ? 1.06 : 1.0,
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
                          ? preset.accent.withOpacity(0.78)
                          : const Color(0xFFF3E6EC),
                      width: highlighted ? 2.1 : 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: preset.accent.withOpacity(
                          highlighted ? 0.18 : 0.08,
                        ),
                        blurRadius: highlighted ? 16 : 10,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.all(padding),
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
            bottom: MediaQuery.of(context).size.height -
                (MediaQuery.of(context).padding.top + 168),
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  preset.gradient.last.withOpacity(0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: preset.accent.withOpacity(0.18),
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
                    color: preset.accent.withOpacity(0.12),
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

  void _showMissYouScreen(_MissYouAlertPayload payload) {
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
              ? 'Bạn cần chờ đủ 3 ngày mới có thể đổi ngày yêu tiếp.'
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
                  title: const Text('Lưu ý'),
                  content: const Text(
                    'Nếu bạn đổi tiếp, bạn sẽ phải đợi 3 ngày nữa mới có thể đổi ngày yêu lần sau.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Đổi tiếp'),
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
        scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ngày bắt đầu yêu!')),
        );
      } catch (e) {
        if (!mounted) return;
        final message = _shortErrorMessage(
          e,
          'Không cập nhật được ngày yêu: chưa xác định được lỗi từ hệ thống.',
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
    final dialogTitle =
        editTopLabel ? 'Đổi chữ phía trên' : 'Đổi chữ phía dưới';
    final hintText = editTopLabel ? 'VD: BÊN NHAU' : 'VD: ngày yêu';

    showDialog(
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
                'Để trống sẽ quay về chữ mặc định.',
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
              'Hủy',
              style: SLTheme.quicksand(
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newLabel = controller.text.trim();
              Navigator.pop(ctx);

              try {
                await _houseSettingsService.updateCountdownLabels(
                  houseId: _houseId!,
                  topLabel: editTopLabel ? newLabel : null,
                  bottomLabel: editTopLabel ? null : newLabel,
                );
              } catch (e) {
                if (!mounted) return;
                final message = _shortErrorMessage(
                  e,
                  'Không lưu được nhãn đếm ngày: chưa xác định được lỗi từ hệ thống.',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SLTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Lưu',
              style: SLTheme.quicksand(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(
      {required bool isUser1, required String currentName}) {
    if (_houseId == null) return;
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
        title: Text(
          'Đổi biệt danh',
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
            hintText: 'Nhập tên mới...',
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
            child: Text('Hủy',
                style: SLTheme.quicksand(
                    color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                final field = isUser1 ? 'nameU1' : 'nameU2';
                final updates = {
                  'houses/$_houseId/settings/$field': newName,
                  'house_profiles/$_houseId/$field': newName,
                  'house_profiles/$_houseId/settings/$field': newName,
                  'houses/$_houseId/updatedAt': ServerValue.timestamp,
                };
                await _dbRef.update(updates);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SLTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Lưu',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
