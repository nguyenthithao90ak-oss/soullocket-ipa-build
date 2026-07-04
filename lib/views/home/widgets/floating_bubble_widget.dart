import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FloatingBubbleWidget extends StatefulWidget {
  const FloatingBubbleWidget({
    super.key,
    this.initialHouseId,
    this.initialRole,
    this.initialPartnerName,
  });

  final String? initialHouseId;
  final String? initialRole;
  final String? initialPartnerName;

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
  String? _houseId;
  StreamSubscription<DatabaseEvent>? _soulMessagesSub;

  // Anti-spam state variables
  final List<int> _msgTimestamps = [];
  final List<int> _warningTimestamps = [];
  int _tempBlockSecondsLeft = 0;
  Timer? _tempBlockTimer;
  String? _spamWarning;

  @override
  void initState() {
    super.initState();
    _myRole = widget.initialRole ?? 'user1';
    _partnerName = widget.initialPartnerName ?? 'Người ấy';
    _houseId = widget.initialHouseId;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();

    _startListeningFirebaseChat();

    // Listen to data from the main app
    _overlayListenerSub = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is String && event.isNotEmpty) {
        if (event == 'launch_app') return;
        
        try {
          if (event.startsWith('{')) {
            final data = jsonDecode(event);
            final type = data['type'];
            if (type == 'sync_credentials') {
              final hId = data['houseId']?.toString() ?? '';
              final r = data['role']?.toString() ?? 'user1';
              final pName = data['partnerName']?.toString() ?? 'Người ấy';
              if (hId.isNotEmpty) {
                if (mounted) {
                  setState(() {
                    _houseId = hId;
                    _myRole = r;
                    _partnerName = pName;
                  });
                }
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setString('overlay_house_id', hId);
                  prefs.setString('overlay_role', r);
                  prefs.setString('overlay_partner_name', pName);
                });
                _startListeningFirebaseChat();
              }
            } else if (type == 'update_chat') {
              if (mounted) {
                setState(() {
                  _myRole = data['myRole'] ?? 'user1';
                  _partnerName = data['partnerName'] ?? 'Người ấy';
                });
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
    FlutterOverlayWindow.shareData('request_sync');
  }

  void _startListeningFirebaseChat() {
    _soulMessagesSub?.cancel();
    final hId = _houseId;
    if (hId == null || hId.isEmpty) {
      debugPrint('[Overlay] _houseId is null or empty, cannot start listening chat');
      return;
    }
    _soulMessagesSub = FirebaseDatabase.instance
        .ref('houses/$hId/soul_merge/chat')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      final list = <Map<String, dynamic>>[];
      if (data is Map) {
        data.forEach((key, val) {
          if (val is Map) {
            final msg = Map<String, dynamic>.from(val);
            msg['id'] = key.toString();
            list.add(msg);
          }
        });
        list.sort((a, b) {
          final t1 = a['timestamp'] as int? ?? 0;
          final t2 = b['timestamp'] as int? ?? 0;
          return t1.compareTo(t2);
        });
      }
      if (mounted) {
        setState(() {
          _chatHistory = list;
        });
        _scrollToBottom();
      }
    }, onError: (e) {
      debugPrint('[Overlay] watch messages error: $e');
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
    _soulMessagesSub?.cancel();
    _tempBlockTimer?.cancel();
    super.dispose();
  }

  void _onTapBubble() {
    setState(() {
      _isExpanded = true;
      _showPreview = false;
    });
    // Expand overlay to fit the chat box panel and enable keyboard focus
    FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, WindowSize.matchParent, true);
    FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
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
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final hId = _houseId;
    if (hId == null || hId.isEmpty) {
      debugPrint('[Overlay] houseId is empty, cannot send message');
      return;
    }

    if (await _checkSpamAndMaybeBlock()) return;

    _textController.clear();

    try {
      final ref = FirebaseDatabase.instance.ref('houses/$hId/soul_merge/chat');
      await ref.push().set({
        'text': text,
        'sender': _myRole,
        'timestamp': ServerValue.timestamp,
      });

      final payload = jsonEncode({
        'action': 'overlay_sent_msg',
        'text': text,
      });
      FlutterOverlayWindow.shareData(payload);
    } catch (e) {
      debugPrint('[Overlay] send message error: $e');
    }
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
          onDoubleTap: () {
            FlutterOverlayWindow.shareData('launch_app');
            FlutterOverlayWindow.closeOverlay();
          },
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
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xEE160B1F), Color(0xF20F0514)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF4F93).withValues(alpha: 0.2),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              offset: const Offset(0, 16),
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
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
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  onPressed: () {
                    setState(() {
                      _isExpanded = false;
                      _showPreview = false;
                    });
                    FlutterOverlayWindow.resizeOverlay(80, 80, true);
                    FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
                  },
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: (_houseId == null || _houseId!.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Đang đồng bộ dữ liệu...\nVui lòng mở lại ứng dụng nếu chờ lâu 💕',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
                      ),
                    ),
                  )
                : _chatHistory.isEmpty
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: _chatHistory.length,
                    itemBuilder: (context, index) {
                      final msg = _chatHistory[index];
                      final text = msg['text']?.toString() ?? '';
                      final sender = msg['sender']?.toString() ?? '';
                      final isSelf = (sender == _myRole);
                      
                      return Align(
                        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: const BoxConstraints(maxWidth: 270),
                          decoration: BoxDecoration(
                            gradient: isSelf
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF4F93), Color(0xFFE2528F)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF2C2C2E), Color(0xFF1E1E20)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(22),
                              topRight: const Radius.circular(22),
                              bottomLeft: isSelf ? const Radius.circular(22) : const Radius.circular(6),
                              bottomRight: isSelf ? const Radius.circular(6) : const Radius.circular(22),
                            ),
                          ),
                          child: Text(
                            text,
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          if (_spamWarning != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Footer Text Input
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1.0,
                ),
              ),
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, color: Colors.white.withValues(alpha: 0.5), size: 24),
                const SizedBox(width: 10),
                Icon(Icons.camera_alt_outlined, color: Colors.white.withValues(alpha: 0.5), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhắn tin...',
                        hintStyle: GoogleFonts.quicksand(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF4F93), Color(0xFFE2528F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}
