import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FloatingBubbleWidget extends StatefulWidget {
  const FloatingBubbleWidget({super.key});

  @override
  State<FloatingBubbleWidget> createState() => _FloatingBubbleWidgetState();
}

class _FloatingBubbleWidgetState extends State<FloatingBubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  
  String _messagePreview = '';
  bool _showPreview = false;
  bool _isExpanded = false;

  List<dynamic> _chatHistory = [];
  String _myRole = 'user1';
  String _partnerName = 'Người ấy';
  
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<dynamic>? _overlayListenerSub;

  // Anti-spam state variables
  final List<int> _msgTimestamps = [];
  final List<int> _warningTimestamps = [];
  int _tempBlockSecondsLeft = 0;
  Timer? _tempBlockTimer;
  String? _spamWarning;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();

    // Listen to data from the main app
    _overlayListenerSub = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is String && event.isNotEmpty) {
        if (event == 'launch_app') return;
        
        try {
          if (event.startsWith('{')) {
            final data = jsonDecode(event);
            final type = data['type'];
            if (type == 'update_chat') {
              if (mounted) {
                setState(() {
                  _chatHistory = data['history'] ?? [];
                  _myRole = data['myRole'] ?? 'user1';
                  _partnerName = data['partnerName'] ?? 'Người ấy';
                });
                _scrollToBottom();
              }
            } else if (type == 'new_msg_preview') {
              final text = data['text']?.toString() ?? '';
              if (text.isNotEmpty && !_isExpanded) {
                setState(() {
                  _messagePreview = text;
                  _showPreview = true;
                });
                // Resize for preview
                FlutterOverlayWindow.resizeOverlay(240, 80, true);
                
                // Shrink back after 4 seconds
                Future.delayed(const Duration(seconds: 4), () {
                  if (mounted && !_isExpanded) {
                    setState(() {
                      _showPreview = false;
                    });
                    FlutterOverlayWindow.resizeOverlay(80, 80, true);
                  }
                });
              }
            }
          }
        } catch (e) {
          debugPrint('[Overlay] error parsing event: $e');
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _overlayListenerSub?.cancel();
    _tempBlockTimer?.cancel();
    super.dispose();
  }

  void _onTapBubble() {
    setState(() {
      _isExpanded = true;
      _showPreview = false;
    });
    // Expand overlay to fit the chat box panel and enable keyboard focus
    FlutterOverlayWindow.resizeOverlay(320, 420, true);
    _scrollToBottom();
  }

  Future<bool> _checkSpamAndMaybeBlock() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Check 1-hour block in SharedPreferences
    int blockUntil = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      blockUntil = prefs.getInt('soul_merge_chat_block_until') ?? 0;
    } catch (e) {
      debugPrint('[SpamCheck] Error reading prefs: $e');
    }

    if (now < blockUntil) {
      final remainingMs = blockUntil - now;
      final remainingMin = (remainingMs / 60000).ceil();
      setState(() {
        _spamWarning = 'Thao tác quá nhanh! Bị chặn trong $remainingMin phút nữa.';
      });
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _spamWarning = null);
      });
      return true;
    }

    // 2. Check 5s countdown
    if (_tempBlockSecondsLeft > 0) {
      setState(() {
        _spamWarning = 'Thao tác quá nhanh! Vui lòng đợi $_tempBlockSecondsLeft giây đếm ngược.';
      });
      return true;
    }

    // 3. Check messages rate (3 messages within 2 seconds)
    _msgTimestamps.removeWhere((t) => now - t > 2000);
    if (_msgTimestamps.length >= 3) {
      _tempBlockSecondsLeft = 5;
      _tempBlockTimer?.cancel();
      
      setState(() {
        _spamWarning = 'Thao tác quá nhanh! Đang đếm ngược $_tempBlockSecondsLeft giây.';
      });

      _tempBlockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _tempBlockSecondsLeft--;
            if (_tempBlockSecondsLeft <= 0) {
              _spamWarning = null;
              timer.cancel();
            } else {
              _spamWarning = 'Thao tác quá nhanh! Đang đếm ngược $_tempBlockSecondsLeft giây.';
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
        setState(() {
          _spamWarning = 'Thao tác quá nhanh! Bị chặn nhắn tin trong 1 giờ.';
          _tempBlockSecondsLeft = 0;
          _tempBlockTimer?.cancel();
        });
      }

      return true;
    }

    _msgTimestamps.add(now);
    return false;
  }

  void _sendMessage() async {
    if (await _checkSpamAndMaybeBlock()) return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();

    final payload = jsonEncode({
      'action': 'send_msg',
      'text': text,
    });
    FlutterOverlayWindow.shareData(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _isExpanded ? _buildExpandedChat() : _buildCollapsedBubble(),
      ),
    );
  }

  Widget _buildCollapsedBubble() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preview message tooltip (if active)
        if (_showPreview && _messagePreview.isNotEmpty)
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFF4F93).withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _messagePreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Heart bubble icon
        GestureDetector(
          onTap: _onTapBubble,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4F93), Color(0xFFE2528F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4F93).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white,
                width: 2.0,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedChat() {
    return Container(
      width: 320,
      height: 420,
      decoration: BoxDecoration(
        color: const Color(0xFF1E0E2C).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFF4F93).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF4F93),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thì thầm với $_partnerName',
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Maximize / Open Main App
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
                  onPressed: () {
                    FlutterOverlayWindow.shareData('launch_app');
                    FlutterOverlayWindow.closeOverlay();
                  },
                ),
                // Collapse Back to Bubble
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  onPressed: () {
                    setState(() {
                      _isExpanded = false;
                      _showPreview = false;
                    });
                    FlutterOverlayWindow.resizeOverlay(80, 80, true);
                  },
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _chatHistory.isEmpty
                ? Center(
                    child: Text(
                      'Hãy gửi lời thì thầm tâm hồn... 💕',
                      style: GoogleFonts.quicksand(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _chatHistory.length,
                    itemBuilder: (context, index) {
                      final msg = _chatHistory[index];
                      final text = msg['text']?.toString() ?? '';
                      final sender = msg['sender']?.toString() ?? '';
                      final isSelf = (sender == _myRole);
                      
                      return Align(
                        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 200),
                          decoration: BoxDecoration(
                            gradient: isSelf
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF4F93), Color(0xFFE2528F)],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                                  ),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isSelf ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isSelf ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            text,
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          if (_spamWarning != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4F4F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF4F4F).withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF4F4F),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _spamWarning!,
                      style: GoogleFonts.quicksand(
                        color: const Color(0xFFFFD1D1),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Footer Text Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Thì thầm...',
                        hintStyle: GoogleFonts.quicksand(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4F93),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
