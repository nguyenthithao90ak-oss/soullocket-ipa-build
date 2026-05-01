// ignore_for_file: unused_element

part of '../../main_home_tab.dart';

extension _MainHomeTabDialogs on _MainHomeTabState {
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
          'TÃ­nh nÄƒng Ä‘ang phÃ¡t triá»ƒn',
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
                'Há»‡ thá»‘ng ghÃ©p Ä‘Ã´i gá»i video ngáº«u nhiÃªn',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SLSpacing.h12,
              Text(
                'TÃ­nh nÄƒng nÃ y sáº½ giÃºp báº¡n ghÃ©p ná»‘i ngáº«u nhiÃªn vÃ  an toÃ n vá»›i nhá»¯ng ngÆ°á»i dÃ¹ng Ä‘á»™c thÃ¢n khÃ¡c phÃ¹ há»£p vá» Ä‘á»™ tuá»•i vÃ  sá»Ÿ thÃ­ch. Sáº½ ra máº¯t trong phiÃªn báº£n sáº¯p tá»›i, hÃ£y cÃ¹ng chá» Ä‘Ã³n nhÃ©!',
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
                'ÄÃ£ hiá»ƒu',
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
                            ? '$partnerName sáº½ tháº¥y ngay'
                            : 'ÄÃ£ gá»­i cho $partnerName',
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

    // LÆ°u context-dependent objects trÆ°á»›c async gap
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
        var startCooldown = false;
        await _houseSettingsService.updateStartDate(
          _houseId!,
          newDateStr,
          startCooldown: startCooldown,
        );
        if (!mounted) return;
        scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text('ÄÃ£ cáº­p nháº­t ngÃ y báº¯t Ä‘áº§u yÃªu!')),
        );
      } catch (e) {
        if (!mounted) return;
        final message = _shortErrorMessage(
          e,
          'KhÃ´ng cáº­p nháº­t Ä‘Æ°á»£c ngÃ y yÃªu: chÆ°a xÃ¡c Ä‘á»‹nh Ä‘Æ°á»£c lá»—i tá»« há»‡ thá»‘ng.',
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
        editTopLabel ? 'Äá»•i chá»¯ phÃ­a trÃªn' : 'Äá»•i chá»¯ phÃ­a dÆ°á»›i';
    final hintText = editTopLabel ? 'VD: BÃŠN NHAU' : 'VD: ngÃ y yÃªu';

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
                'Äá»ƒ trá»‘ng sáº½ quay vá» chá»¯ máº·c Ä‘á»‹nh.',
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
              'Há»§y',
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
                  'KhÃ´ng lÆ°u Ä‘Æ°á»£c nhÃ£n Ä‘áº¿m ngÃ y: chÆ°a xÃ¡c Ä‘á»‹nh Ä‘Æ°á»£c lá»—i tá»« há»‡ thá»‘ng.',
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
              'LÆ°u',
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
          'Äá»•i biá»‡t danh',
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
            hintText: 'Nháº­p tÃªn má»›i...',
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
            child: Text('Há»§y',
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
            child: Text('LÆ°u',
                style: SLTheme.quicksand(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

