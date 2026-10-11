part of '../../main_home_tab.dart';

class SoulMergeSticker extends StatefulWidget {
  final int activeIndex;
  const SoulMergeSticker({super.key, this.activeIndex = 0});

  @override
  State<SoulMergeSticker> createState() => SoulMergeStickerState();
}

class SoulMergeStickerState extends State<SoulMergeSticker>
    with ScreenActivityMixin {
  Offset? _position;
  Offset _dragOffset = Offset.zero;
  bool _isSingle = true;

  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub;
  Timer? _tipsTimer;
  Timer? _bubbleHideTimer;
  String? _bubbleText;
  bool _showBubble = false;
  String _myRole = 'user1';
  final _random = Random();

  final GlobalKey<TapHeartsOverlayState> _globalHeartsKey =
      GlobalKey<TapHeartsOverlayState>();
  String _globalHeartStyle = 'basic';
  StreamSubscription<Map<String, dynamic>>? _interactiveEventsSub;

  bool _showHeartNotif = false;
  bool _listening = false;
  int _activityGeneration = 0;
  bool get _isStickerActive => isScreenActive && widget.activeIndex == 0;

  static const List<String> _appTips = [
    'copy_75353c695990',
    'copy_f5f5b2880efe',
    'copy_b616dcf44fe3',
    'copy_6068cc26e948',
    'copy_9741b65a9481',
    'copy_1b612cfbe367',
    'copy_3335271a5a71',
    'copy_3c3e1b430f73',
    'copy_89cda6d13ed6',
    'copy_b7cad573548e',
    'copy_24acfbb8320c',
    'copy_15777a06d375',
    'copy_0e157bd91e2f',
    'copy_c31c42beaed1',
    'copy_8f3e30302d6f',
    'copy_77d6bdb70457',
    'copy_77a581341ba7',
    'copy_8f56a347cf81',
    'copy_13fad8d5bc53',
    'copy_e4a7300ba130',
    'copy_f3bde32376b3',
    'copy_8c0903741085',
    'copy_5bcfef7dd617',
    'copy_c6dff6257033',
    'copy_1e124f6b324a',
    'copy_e493fb401e16',
    'copy_dcb6fd6665b4',
    'copy_18b2bf7cd138',
    'copy_ae6d99e5e8e2',
    'copy_2b41529af6cf',
    'copy_c4e7b5aee94d',
    'copy_5b261fc50242',
    'copy_76805291fbe1',
    'copy_402b9620b3c8',
  ];

  @override
  void initState() {
    super.initState();
    _checkSingleStatus();
    _loadPosition();
    _loadSettings();
  }

  @override
  void didUpdateWidget(covariant SoulMergeSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex) {
      if (widget.activeIndex == 0) unawaited(_loadSettings());
      _syncActiveWork();
    }
  }

  @override
  void onScreenActivityChanged(bool active) {
    _syncActiveWork();
    if (active) unawaited(_loadSettings());
  }

  void _syncActiveWork() {
    if (!_isStickerActive || _isSingle) {
      _activityGeneration++;
      _listening = false;
      unawaited(_messagesSub?.cancel());
      _messagesSub = null;
      unawaited(_interactiveEventsSub?.cancel());
      _interactiveEventsSub = null;
      _tipsTimer?.cancel();
      _tipsTimer = null;
      _bubbleHideTimer?.cancel();
      _bubbleHideTimer = null;
      _showBubble = false;
      return;
    }
    if (!_listening) {
      _listening = true;
      unawaited(_initChatListening(++_activityGeneration));
    }
    if (_showHeartNotif) {
      _startTipsTimer();
    } else {
      _tipsTimer?.cancel();
      _tipsTimer = null;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showHeartNotif = prefs.getBool('soul_merge_show_heart_notif') ?? false;
        if (!_showHeartNotif) {
          _showBubble = false;
        }
      });
      _syncActiveWork();
    }
  }

  @override
  void dispose() {
    _activityGeneration++;
    _messagesSub?.cancel();
    _interactiveEventsSub?.cancel();
    _tipsTimer?.cancel();
    _bubbleHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSingleStatus() async {
    final houseId = await HouseService().getCurrentHouseId();
    if (mounted) {
      setState(() {
        _isSingle = (houseId == null || houseId.isEmpty);
      });
      _syncActiveWork();
    }
  }

  void _initInteractiveEventsListening() {
    _interactiveEventsSub?.cancel();
    _interactiveEventsSub = SoulMergeService().watchInteractiveEvents().listen((
      event,
    ) async {
      if (event.isEmpty || _isSingle || !_isStickerActive) return;
      final generation = _activityGeneration;
      final sender = event['sender']?.toString();
      if (sender == _myRole) return; // ignore my own

      final type = event['type']?.toString();
      if (type == 'photo_shot') {
        // 1. Hiển thị thông báo bằng chữ nếu được bật
        if (_showHeartNotif) {
          _showFloatingMessage(
            context.tr('ui_home_he_just_gave_you_his_heart_460cf6'),
          );
        }

        // 2. Hiển thị hiệu ứng tim bay nếu:
        // - Chúng ta đang ở màn hình home (luôn bay ở home)
        if (widget.activeIndex == 0) {
          final prefs = await SharedPreferences.getInstance();
          final style = prefs.getString('soul_merge_heart_style') ?? 'basic';
          if (_isStickerActive && generation == _activityGeneration) {
            setState(() {
              _globalHeartStyle = style;
            });
            // Trì hoãn nhẹ 50ms để widget cập nhật style mới rồi bắn tim
            Future.delayed(const Duration(milliseconds: 50), () {
              if (!_isStickerActive || generation != _activityGeneration)
                return;
              _globalHeartsKey.currentState?.spawnLocalExplosion(
                const Offset(26, 26),
                count: 6,
              );
            });
          }
        }
      }
    });
  }

  Future<void> _initChatListening(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isStickerActive || _isSingle || generation != _activityGeneration)
      return;
    _myRole = prefs.getString('il_role') ?? 'user1';
    _initInteractiveEventsListening();

    _messagesSub = SoulMergeService().watchSoulMessages().listen((messages) {
      if (messages.isEmpty || _isSingle || !_isStickerActive) return;
      final isVisible = widget.activeIndex == 0;
      if (!isVisible) return;
      final lastMsg = messages.last;
      final sender = lastMsg['sender']?.toString();
      if (sender != _myRole) {
        final text = lastMsg['text']?.toString() ?? '';
        final imgUrl = lastMsg['imageUrl']?.toString() ?? '';
        final displayTxt = text.isNotEmpty
            ? text
            : (imgUrl.isNotEmpty ? UiCopy.text('copy_c306bf7c70f5') : '');
        if (displayTxt.isEmpty) return;

        final msgTime = lastMsg['timestamp'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        // Chỉ hiển thị tin nhắn mới trong vòng 10 giây gần nhất
        if ((now - msgTime).abs() < 10000) {
          _showFloatingMessage(displayTxt);
        }
      }
    });
  }

  void _startTipsTimer() {
    if (!_isStickerActive || _isSingle || !_showHeartNotif) return;
    _tipsTimer ??= Timer.periodic(const Duration(seconds: 20), (timer) {
      _showRandomTip();
    });
  }

  void _showRandomTip() {
    final isVisible = widget.activeIndex == 0;
    if (!isVisible) return;
    final tip = _appTips[_random.nextInt(_appTips.length)];
    _showFloatingMessage(UiCopy.text(tip));
  }

  void _showFloatingMessage(String text) {
    if (!_isStickerActive) return;
    if (!_showHeartNotif) return;

    // [Fix] Chỉ hiển thị thông báo bong bóng khi ở màn hình chính (tab 0)
    // theo yêu cầu của người dùng, tránh đè lên các tính năng ở tab khác.
    if (widget.activeIndex != 0) return;

    setState(() {
      _bubbleText = text;
      _showBubble = true;
    });
    _bubbleHideTimer?.cancel();
    _bubbleHideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showBubble = false;
        });
      }
    });
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble('soul_merge_x');
    final dy = prefs.getDouble('soul_merge_y');
    if (dx != null && dy != null && mounted) {
      setState(() => _position = Offset(dx, dy));
    }
  }

  Future<void> _savePosition(Offset pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('soul_merge_x', pos.dx);
    await prefs.setDouble('soul_merge_y', pos.dy);
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = widget.activeIndex == 0;
    if (!isVisible) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: UiPrefs.captureModeNotifier,
      builder: (context, captureMode, _) {
        if (captureMode) return const SizedBox.shrink();

        final defaultPos = Offset(14, MediaQuery.paddingOf(context).top + 4);
        final pos = _position ?? defaultPos;
        final screenWidth = MediaQuery.sizeOf(context).width;

        // Căn giữa sticker mặc định (52 - 212) / 2 = -80
        double tooltipLeft = -80;
        if (pos.dx + tooltipLeft < 8) {
          tooltipLeft = -pos.dx + 8;
        } else if (pos.dx + 52 + (tooltipLeft * -1) > screenWidth - 8) {
          tooltipLeft = screenWidth - pos.dx - 212 - 8;
        }

        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bong bóng chat hiển thị tin nhắn / mẹo dạng viên nang Glassmorphic lơ lửng cực sang trọng
              Positioned(
                bottom: 60,
                left: tooltipLeft,
                child: AnimatedOpacity(
                  opacity: _showBubble ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _showBubble && _bubbleText != null
                      ? Container(
                          width: 212,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFFFFC0D3,
                              ).withValues(alpha: 0.65),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFB3CA,
                                ).withValues(alpha: 0.22),
                                blurRadius: 16,
                                spreadRadius: 1,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            _bubbleText!,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF4A3445),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                width: 52,
                height: 52,
                child: IgnorePointer(
                  child: TapHeartsOverlay(
                    key: _globalHeartsKey,
                    style: _globalHeartStyle,
                  ),
                ),
              ),
              GestureDetector(
                onPanStart: (details) {
                  _dragOffset = details.globalPosition - pos;
                },
                onPanUpdate: (details) {
                  setState(() {
                    final targetPos = details.globalPosition - _dragOffset;
                    _position = Offset(
                      targetPos.dx.clamp(
                        0.0,
                        MediaQuery.sizeOf(context).width - 52,
                      ),
                      targetPos.dy.clamp(
                        0.0,
                        MediaQuery.sizeOf(context).height - 150,
                      ),
                    );
                  });
                },
                onPanEnd: (_) {
                  if (_position != null) _savePosition(_position!);
                },
                onTap: () async {
                  if (_isSingle) {
                    _showPairingBottomSheet(context);
                  } else {
                    await slPush(
                      context,
                      const SoulMergeScreen(),
                      fullscreenDialog: true,
                    );
                    _loadSettings();
                  }
                },
                child: Tooltip(
                  message: context.tr('p4_soul_title'),
                  child: const SoulMergeMark(size: 52, framed: true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPairingBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark =
            UiPrefs.notifier.value.themeKey.contains('dark') ||
            UiPrefs.notifier.value.themeKey.contains('night');
        final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF243041);

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCE4EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFF06292),
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('ui_home_features_for_couples_df1238'),
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'ui_home_please_pair_with_your_other_half_to_680016',
                ),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  unawaited(slPush(context, const PairingDashboardScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15BB5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  context.tr('p6_pair_now'),
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
