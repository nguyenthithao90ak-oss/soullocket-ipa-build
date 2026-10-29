import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/soul_message_content.dart';
import 'package:soullocket_app/utils/soul_bubble_overlay.dart';
import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:soullocket_app/widgets/soul_merge_mark.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';

import 'soul_merge/bubble_chat_controller.dart';
import 'soul_merge/bubble_window_controller.dart';
import 'soul_merge/soul_merge_design.dart';
import 'soul_merge/sticker_bottom_sheet.dart';

class FloatingBubbleWidget extends StatefulWidget {
  const FloatingBubbleWidget({
    super.key,
    required this.chatController,
    this.windowController,
    this.onOpenApp,
    this.onCloseOverlay,
  });

  final SoulBubbleChatController chatController;
  final SoulBubbleWindowController? windowController;
  final Future<void> Function()? onOpenApp;
  final Future<void> Function()? onCloseOverlay;

  @override
  State<FloatingBubbleWidget> createState() => _FloatingBubbleWidgetState();
}

class _FloatingBubbleWidgetState extends State<FloatingBubbleWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final SoulBubbleChatController _chat;
  late final SoulBubbleWindowController _window;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _composerFocus = FocusNode();

  double _touchScale = 1;
  String _messagePreview = '';
  bool _showPreview = false;
  bool _isExpanded = false;
  bool _opening = false;
  bool _closing = false;
  bool _sendingTap = false;
  bool _resumeMotion = true;
  bool _stickerPickerOpen = false;
  bool _scrollingMessages = false;
  int _previewGeneration = 0;
  int _incomingRevision = 0;
  String? _lastScope;
  String? _localError;
  String? _failedSticker;
  List<Map<String, dynamic>>? _lastMessages;
  Timer? _previewTimer;

  final List<int> _msgTimestamps = [];
  final List<int> _warningTimestamps = [];
  int _tempBlockSecondsLeft = 0;
  Timer? _tempBlockTimer;
  String? _spamWarning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat = widget.chatController;
    _window =
        widget.windowController ??
        SoulBubbleWindowController(AndroidSoulBubbleWindow());
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _breatheAnimation = Tween<double>(begin: 1, end: 1.06).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOutSine),
    );
    _animController.forward();
    _lastScope = _chat.scope?.key;
    _incomingRevision = _chat.incomingRevision;
    _chat.addListener(_onChatChanged);
    _chat.start();
  }

  Size get _displaySize {
    final display = View.of(context).display;
    final ratio = display.devicePixelRatio;
    return ratio > 0 && !display.size.isEmpty
        ? display.size / ratio
        : MediaQuery.sizeOf(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animController.value = 1;
      _breatheController.stop();
      _breatheController.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_resumeMotion != resumed) setState(() => _resumeMotion = resumed);
    if (!_resumeMotion) {
      _breatheController.stop();
      _previewTimer?.cancel();
      if (!_isExpanded && _showPreview) unawaited(_hidePreview());
    }
  }

  void _onChatChanged() {
    if (!mounted || _closing) return;
    if (_chat.shouldClose) {
      unawaited(_close());
      return;
    }
    if (_lastScope != _chat.scope?.key) {
      _lastScope = _chat.scope?.key;
      _textController.clear();
      _spamWarning = null;
      _tempBlockTimer?.cancel();
      _tempBlockSecondsLeft = 0;
      _msgTimestamps.clear();
      _warningTimestamps.clear();
      _previewTimer?.cancel();
      _previewGeneration++;
      _showPreview = false;
      _localError = null;
      _failedSticker = null;
      // Xóa nội dung ngay khi mất/đổi scope, trước khi listener mới trả về.
      setState(() {});
    }
    if (_chat.incomingRevision != _incomingRevision) {
      _incomingRevision = _chat.incomingRevision;
      final message = _chat.incomingMessage;
      if (message != null && !_isExpanded && !_opening) {
        unawaited(
          _showIncomingPreview(
            SoulMessageContent.preview(
              text: message['text']?.toString() ?? '',
              imageUrl: message['imageUrl']?.toString(),
            ),
          ),
        );
      }
    }
    final messagesChanged = !identical(_lastMessages, _chat.messages);
    _lastMessages = _chat.messages;
    if (_isExpanded) {
      final nearBottom =
          !_scrollController.hasClients ||
          _scrollController.position.extentAfter < 72;
      setState(() {});
      if (messagesChanged && nearBottom) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isExpanded && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _showIncomingPreview(String text) async {
    final generation = ++_previewGeneration;
    _previewTimer?.cancel();
    if (!_resumeMotion || text.isEmpty || _closing) return;
    try {
      final applied = await _window.show(
        SoulBubbleWindowMode.preview,
        _displaySize,
      );
      if (!applied ||
          !mounted ||
          generation != _previewGeneration ||
          _isExpanded ||
          _opening) {
        return;
      }
      setState(() {
        _messagePreview = text;
        _showPreview = true;
      });
      if (!MediaQuery.disableAnimationsOf(context)) {
        // Chỉ nảy nhẹ một lần khi có tin, không có ticker lặp cả ngày.
        _breatheController.forward(from: 0).then((_) {
          if (mounted) _breatheController.reverse();
        });
      }
      _previewTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && generation == _previewGeneration) {
          unawaited(_hidePreview());
        }
      });
    } catch (error) {
      debugPrint('[Overlay] Preview resize failed:  ${error.runtimeType}');
    }
  }

  Future<void> _hidePreview() async {
    _previewTimer?.cancel();
    _previewGeneration++;
    if (!mounted || _isExpanded || _opening) return;
    setState(() => _showPreview = false);
    try {
      await _window.show(SoulBubbleWindowMode.bubble, _displaySize);
    } catch (error) {
      debugPrint('[Overlay] Bubble resize failed:  ${error.runtimeType}');
    }
  }

  Future<void> _onTapBubble() async {
    if (_opening || _closing || _isExpanded) return;
    _opening = true;
    _previewGeneration++;
    _previewTimer?.cancel();
    _breatheController.stop();
    try {
      final applied = await _window.show(
        SoulBubbleWindowMode.chat,
        _displaySize,
      );
      if (!applied || !mounted || _closing) return;
      setState(() {
        _touchScale = 1;
        _isExpanded = true;
        _showPreview = false;
      });
      _scrollToBottom();
    } catch (error) {
      debugPrint('[Overlay] Chat resize failed:  ${error.runtimeType}');
      if (mounted) setState(() => _localError = context.tr('core_retry'));
    } finally {
      _opening = false;
    }
  }

  Future<void> _shrinkOverlay() async {
    if (_closing) return;
    _previewGeneration++;
    _previewTimer?.cancel();
    _composerFocus.unfocus();
    setState(() {
      _isExpanded = false;
      _showPreview = false;
      _scrollingMessages = false;
    });
    try {
      await _window.show(SoulBubbleWindowMode.bubble, _displaySize);
    } catch (error) {
      debugPrint('[Overlay] Minimize failed:  ${error.runtimeType}');
    }
  }

  Future<void> _openApp() async {
    try {
      await (widget.onOpenApp ?? SoulBubbleOverlay.openApp)();
      if (mounted) await _close();
    } catch (error) {
      if (mounted) {
        setState(() => _localError = context.tr('soul_bubble_open_failed'));
      }
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _previewTimer?.cancel();
    _composerFocus.unfocus();
    try {
      await (widget.onCloseOverlay ?? SoulBubbleOverlay.close)();
      _window.dispose();
    } catch (error) {
      _closing = false;
      debugPrint('[Overlay] Close failed:  ${error.runtimeType}');
    }
  }

  Future<bool> _checkSpamAndMaybeBlock(String? scope) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Check 1-hour block in SharedPreferences
    int blockUntil = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      blockUntil = prefs.getInt('soul_merge_chat_block_until') ?? 0;
    } catch (e) {
      debugPrint('[SpamCheck] Error reading prefs: $e');
    }
    if (!mounted || _closing || scope != _chat.scope?.key) return true;

    if (now < blockUntil) {
      final remainingMs = blockUntil - now;
      final remainingMin = (remainingMs / 60000).ceil();
      if (!mounted) return true;
      setState(() {
        _spamWarning = L10nService().format(
          'ui_home_action_too_fast_blocked_in_value1_minutes_900f32',
          {'value1': remainingMin},
        );
      });
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _spamWarning = null);
      });
      return true;
    }

    // 2. Check 5s countdown
    if (_tempBlockSecondsLeft > 0) {
      setState(() {
        _spamWarning = L10nService().format(
          'ui_home_action_too_fast_please_wait_for_value1_d70da2',
          {'value1': _tempBlockSecondsLeft},
        );
      });
      return true;
    }

    // 3. Check messages rate (3 messages within 2 seconds)
    _msgTimestamps.removeWhere((t) => now - t > 2000);
    if (_msgTimestamps.length >= 3) {
      _tempBlockSecondsLeft = 5;
      _tempBlockTimer?.cancel();

      setState(() {
        _spamWarning = L10nService().format(
          'ui_home_action_too_fast_counting_down_value1_seconds_e39a14',
          {'value1': _tempBlockSecondsLeft},
        );
      });

      _tempBlockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _tempBlockSecondsLeft--;
            if (_tempBlockSecondsLeft <= 0) {
              _spamWarning = null;
              timer.cancel();
            } else {
              _spamWarning = L10nService().format(
                'ui_home_action_too_fast_counting_down_value1_seconds_e39a14',
                {'value1': _tempBlockSecondsLeft},
              );
            }
          });
        } else {
          timer.cancel();
        }
      });

      _warningTimestamps.add(now);
      _warningTimestamps.removeWhere((t) => now - t > 60000);

      if (_warningTimestamps.length >= 5) {
        final targetBlockUntil = now + 3600000;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('soul_merge_chat_block_until', targetBlockUntil);
        } catch (e) {
          debugPrint('[SpamCheck] Error writing prefs: $e');
        }
        if (!mounted) return true;
        setState(() {
          _spamWarning = L10nService().translate(
            'ui_home_action_too_fast_blocked_texting_for_1_351b49',
          );
          _tempBlockSecondsLeft = 0;
          _tempBlockTimer?.cancel();
        });
      }

      return true;
    }

    _msgTimestamps.add(now);
    return false;
  }

  Future<void> _sendMessage() async {
    final text = _textController.text;
    if (_sendingTap || !_chat.canSend || text.trim().isEmpty) return;
    if (text.trim().length > 2000) {
      setState(() => _localError = context.tr('copy_44fdfcf1695b'));
      return;
    }
    setState(() {
      _localError = null;
      _failedSticker = null;
    });
    _sendingTap = true;
    final scope = _chat.scope?.key;
    try {
      if (await _checkSpamAndMaybeBlock(scope) ||
          !mounted ||
          _closing ||
          scope != _chat.scope?.key) {
        return;
      }
      final confirmed = await _chat.send(text);
      if (!mounted || scope != _chat.scope?.key) return;
      if (confirmed) {
        if (_textController.text == text) _textController.clear();
        _scrollToBottom();
      }
    } finally {
      _sendingTap = false;
    }
  }

  Future<void> _showStickerPicker() async {
    if (!_chat.canSend || _closing || _stickerPickerOpen) return;
    final scope = _chat.scope?.key;
    _composerFocus.unfocus();
    setState(() => _stickerPickerOpen = true);
    try {
      await StickerBottomSheet.show(
        context: context,
        onStickerSelected: (reference) {
          if (mounted && !_closing && scope == _chat.scope?.key) {
            unawaited(_sendSticker(reference));
          }
        },
      );
    } finally {
      if (mounted) setState(() => _stickerPickerOpen = false);
    }
  }

  Future<void> _sendSticker(String reference) async {
    if (_sendingTap || !_chat.canSend || reference.trim().isEmpty) return;
    _sendingTap = true;
    final scope = _chat.scope?.key;
    try {
      if (await _checkSpamAndMaybeBlock(scope) ||
          !mounted ||
          _closing ||
          scope != _chat.scope?.key) {
        return;
      }
      setState(() {
        _localError = null;
        _failedSticker = null;
      });
      final confirmed = await _chat.sendSticker(reference);
      if (!mounted || scope != _chat.scope?.key) return;
      setState(() => _failedSticker = confirmed ? null : reference);
      if (confirmed) _scrollToBottom();
    } finally {
      _sendingTap = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewGeneration++;
    _previewTimer?.cancel();
    _tempBlockTimer?.cancel();
    _chat.removeListener(_onChatChanged);
    _window.dispose();
    _animController.dispose();
    _breatheController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: LayoutBuilder(
      builder: (context, constraints) {
        // WindowManager và Flutter có thể nhận kích thước ở hai frame khác nhau.
        // Không dựng panel lớn vào frame 80dp khi đang thu/phóng cửa sổ.
        if (_isExpanded &&
            constraints.maxWidth >= 200 &&
            constraints.maxHeight >= 120) {
          return _buildExpandedChat();
        }
        return ScaleTransition(
          scale: _scaleAnimation,
          child: _buildCollapsedBubble(),
        );
      },
    ),
  );

  Widget _buildCollapsedBubble() => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: _showPreview ? MainAxisSize.max : MainAxisSize.min,
        textDirection: _window.bubbleOnLeft
            ? TextDirection.rtl
            : TextDirection.ltr,
        children: [
          if (_showPreview && _messagePreview.isNotEmpty)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  left: _window.bubbleOnLeft ? 8 : 0,
                  right: _window.bubbleOnLeft ? 0 : 8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF1251D2C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x55FF4F93)),
                ),
                child: Text(
                  _messagePreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.quicksand(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Semantics(
            button: true,
            label: context.tr('p4_soul_title'),
            child: GestureDetector(
              key: const ValueKey('soul-bubble-open'),
              onTapDown: (_) => setState(() => _touchScale = .92),
              onTapUp: (_) => setState(() => _touchScale = 1),
              onTapCancel: () => setState(() => _touchScale = 1),
              onTap: _onTapBubble,
              onLongPress: _close,
              child: AnimatedScale(
                scale: _touchScale,
                duration: const Duration(milliseconds: 100),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _FloatingBubblePainter(_breatheAnimation),
                    child: const SizedBox.square(
                      dimension: 58,
                      child: Center(child: SoulMergeMark(size: 48)),
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

  Widget _buildExpandedChat() => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_shrinkOverlay());
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          key: const ValueKey('soul-bubble-scrim'),
          behavior: HitTestBehavior.opaque,
          onTap: _shrinkOverlay,
          child: const ColoredBox(color: Color(0x44000000)),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 8,
              top: 8,
              right: 8,
              bottom: 8 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Cửa sổ native đã match-parent. Dùng toàn bộ phần còn lại để
                // bong bóng có trải nghiệm gần Zalo thay vì hộp 540dp cố định.
                final height = constraints.maxHeight;
                final compact = height < 320;
                final colors = SoulMergeColors(context);
                return RepaintBoundary(
                  child: DecoratedBox(
                    key: const ValueKey('soul-bubble-chat'),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.line),
                      boxShadow: const [
                        BoxShadow(color: Color(0x44000000), blurRadius: 24),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_chat.backgroundUrl.isNotEmpty)
                            RepaintBoundary(
                              child: CachedNetworkImage(
                                key: ValueKey(_chat.backgroundUrl),
                                imageUrl: _chat.backgroundUrl,
                                fit: BoxFit.cover,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                memCacheWidth:
                                    (_displaySize.width *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
                                        .ceil()
                                        .clamp(1, 1440)
                                        .toInt(),
                                errorWidget: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          const SoulMergeBackgroundScrim(),
                          if (compact)
                            SingleChildScrollView(
                              reverse: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildHeader(),
                                  SizedBox(
                                    height: math
                                        .max(120.0, height - 150)
                                        .toDouble(),
                                    child: _buildMessages(),
                                  ),
                                  _buildFeedback(),
                                  _buildComposer(compact: true),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: [
                                _buildHeader(),
                                Expanded(child: _buildMessages()),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 100,
                                  ),
                                  child: SingleChildScrollView(
                                    child: _buildFeedback(),
                                  ),
                                ),
                                _buildComposer(compact: height < 420),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildFeedback() {
    final colors = SoulMergeColors(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_spamWarning != null ||
            _chat.sendUnconfirmed ||
            _localError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              _spamWarning ??
                  _localError ??
                  context.tr('support_ui_send_failed'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.rose, fontSize: 12),
            ),
          ),
        if (_failedSticker != null && _chat.sendUnconfirmed)
          TextButton.icon(
            key: const ValueKey('soul-bubble-retry-sticker'),
            onPressed: _chat.canSend
                ? () => _sendSticker(_failedSticker!)
                : null,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.tr('core_retry')),
            style: TextButton.styleFrom(foregroundColor: colors.rose),
          ),
        if (_chat.loadFailed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              context.tr('p6_server_connection_error'),
              maxLines: 2,
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final colors = SoulMergeColors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .96),
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 4),
        child: Row(
          children: [
            const SoulMergeMark(size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chat.partnerName.isEmpty
                        ? UiCopy.text('copy_145933221191')
                        : _chat.partnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.quicksand(
                      color: colors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.tr('p4_soul_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.quicksand(
                      color: colors.rose,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('soul-bubble-open-app'),
              tooltip: context.tr('soul_bubble_open_app'),
              onPressed: _openApp,
              icon: Icon(
                Icons.open_in_new_rounded,
                color: colors.muted,
                size: 20,
              ),
            ),
            IconButton(
              key: const ValueKey('soul-bubble-minimize'),
              tooltip: context.tr('soul_bubble_minimize'),
              onPressed: _shrinkOverlay,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    final colors = SoulMergeColors(context);
    if (_chat.scope == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.tr('ui_home_syncing_data_please_reopen_the_app_if_6ba23c'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted),
          ),
        ),
      );
    }
    if (_chat.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.tr('soul_merge_message_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted),
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;
        if (notification is ScrollStartNotification && !_scrollingMessages) {
          setState(() => _scrollingMessages = true);
        } else if (notification is ScrollEndNotification &&
            _scrollingMessages) {
          setState(() => _scrollingMessages = false);
        }
        return false;
      },
      child: RepaintBoundary(
        child: TickerMode(
          enabled: _resumeMotion && !_stickerPickerOpen && !_scrollingMessages,
          child: ListView.builder(
            key: const ValueKey('soul-bubble-messages'),
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            itemCount: _chat.messages.length,
            itemBuilder: (context, index) {
              final message = _chat.messages[index];
              final isSelf = message['sender'] == _chat.scope?.role;
              final text = message['text']?.toString() ?? '';
              final image = message['imageUrl']?.toString() ?? '';
              final sticker = SoulMessageContent.isSticker(image);
              return RepaintBoundary(
                child: Align(
                  alignment: isSelf
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    key: ValueKey("soul-bubble-message-${message['id']}"),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: sticker
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(10),
                    constraints: BoxConstraints(
                      maxWidth: math.min(
                        340,
                        MediaQuery.sizeOf(context).width * .78,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: sticker
                          ? Colors.transparent
                          : isSelf
                          ? colors.sent
                          : colors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (image.isNotEmpty)
                          _buildMessageMedia(
                            image,
                            allowMotion: index >= _chat.messages.length - 3,
                          ),
                        if (text.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              top: image.isEmpty ? 0 : 6,
                            ),
                            child: Text(
                              text,
                              style: GoogleFonts.quicksand(
                                color: isSelf && !sticker
                                    ? Colors.white
                                    : colors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildMessageMedia(String reference, {required bool allowMotion}) {
    final sticker = SoulLocketStickerCatalog.find(reference);
    if (sticker != null) {
      return SoulLocketAnimatedSticker(
        sticker: sticker,
        size: 116,
        originalArtwork: reference.startsWith(
          SoulLocketStickerCatalog.originalPrefix,
        ),
        animate:
            _resumeMotion &&
            allowMotion &&
            !_scrollingMessages &&
            !_stickerPickerOpen &&
            !MediaQuery.disableAnimationsOf(context),
      );
    }
    if (reference.startsWith('assets/images/anhtomau_stickers/')) {
      return Image.asset(
        reference,
        width: 116,
        height: 116,
        fit: BoxFit.contain,
      );
    }
    final uri = Uri.tryParse(reference);
    if (uri?.scheme != 'https' && uri?.scheme != 'http') {
      return const SizedBox.square(
        dimension: 116,
        child: Icon(Icons.image_not_supported_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: reference,
        width: 220,
        height: 165,
        fit: BoxFit.cover,
        memCacheWidth: (220 * MediaQuery.devicePixelRatioOf(context)).ceil(),
        placeholder: (context, url) =>
            ColoredBox(color: SoulMergeColors(context).blush),
        errorWidget: (context, url, error) =>
            const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  Widget _buildComposer({required bool compact}) {
    final colors = SoulMergeColors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .96),
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, compact ? 2 : 8, 8, compact ? 2 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              key: const ValueKey('soul-bubble-sticker'),
              tooltip: context.tr('sticker'),
              onPressed: _chat.canSend ? _showStickerPicker : null,
              style: IconButton.styleFrom(
                backgroundColor: colors.blush,
                foregroundColor: colors.rose,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.emoji_emotions_rounded, size: 20),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                key: const ValueKey('soul-bubble-composer'),
                controller: _textController,
                focusNode: _composerFocus,
                enabled: _chat.scope != null,
                minLines: 1,
                maxLines: compact ? 1 : 3,
                maxLength: 2000,
                maxLengthEnforcement:
                    MaxLengthEnforcement.truncateAfterCompositionEnds,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                style: GoogleFonts.quicksand(
                  color: colors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('home_nhntin_3e833a'),
                  hintStyle: TextStyle(color: colors.muted),
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              key: const ValueKey('soul-bubble-send'),
              tooltip: context.tr('send'),
              style: IconButton.styleFrom(
                backgroundColor: colors.sent,
                minimumSize: const Size(48, 48),
              ),
              onPressed: _chat.canSend ? _sendMessage : null,
              icon: _chat.sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vẽ phần khung động bằng một layer raster riêng. Cách này giữ phần sticker
/// tĩnh không bị dựng lại theo từng frame của animation thở.
class _FloatingBubblePainter extends CustomPainter {
  _FloatingBubblePainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final center = ui.Offset(size.width / 2, size.height / 2);
    final scale = animation.value;
    final normalized = ((scale - 1.0) / 0.06).clamp(0.0, 1.0);

    final ringPaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(
        0xFFFF4F93,
      ).withValues(alpha: 0.6 * (1.0 - normalized));
    canvas.drawCircle(center, 29 * scale, ringPaint);

    final shadowPaint = ui.Paint()
      ..color = const Color(0x73FF4F93)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12);
    canvas.drawCircle(center, 25, shadowPaint);

    final corePaint = ui.Paint()..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, 25, corePaint);

    final borderPaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawCircle(center, 25, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _FloatingBubblePainter oldDelegate) => false;
}
