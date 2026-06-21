import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:soullocket_app/models/diary_post.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../utils/helpers/bump_detector.dart';
import '../../../utils/services/soul_merge_service.dart';
import '../../../utils/services/house_service.dart';
import '../../../utils/services/notification_service.dart';
import '../../../core/sl_theme.dart';
import 'package:soullocket_app/utils/services/purchase_service.dart';
import 'package:soullocket_app/views/premium/premium_store_screen.dart';

class SoulMergeScreen extends StatefulWidget {
  const SoulMergeScreen({super.key});

  @override
  State<SoulMergeScreen> createState() => _SoulMergeScreenState();
}

class _SoulMergeScreenState extends State<SoulMergeScreen>
    with SingleTickerProviderStateMixin {
  late BumpDetector _bumpDetector;
  final SoulMergeService _mergeService = SoulMergeService();
  StreamSubscription<Map<String, int>>? _mergeTimesSub;

  bool _isMerged = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Memory photos lists and timers
  List<Map<String, String>> _memoriesData = [];
  final List<ExplodingPhoto> _activePhotos = [];
  final List<({Offset position, UniqueKey id})> _activeParticleExplosions = [];
  Timer? _explosionTimer;
  final math.Random _random = math.Random();

  String? _houseId;
  String _partnerName = 'Người ấy';
  String _myName = 'Người ấy';
  bool _iHaveBumped = false;
  bool _partnerHasBumped = false;
  bool _notificationSent = false;
  final GlobalKey<_TapHeartsOverlayState> _heartsOverlayKey = GlobalKey<_TapHeartsOverlayState>();
  double _interactiveScale = 1.0;
  Timer? _continuousHeartsTimer;
  Offset _lastTapPosition = Offset.zero;
  Offset? _lastSpawnedPosition;
  bool _isDragging = false;
  Offset _heartOffset = Offset.zero;
  Offset _dragStartPos = Offset.zero;

  final TextEditingController _customMsgController = TextEditingController();
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub;
  final List<FloatingMessage> _floatingMessages = [];
  int _lastMsgTimestamp = 0;
  int _lastSeenMsgTimestamp = 0;
  String _myRole = 'user1';
  List<Map<String, dynamic>> _chatHistory = [];
  final ScrollController _chatScrollController = ScrollController();
  bool _overlayEnabled = false;
  StreamSubscription<dynamic>? _overlayListenerSub;

  // Anti-spam state variables
  final List<int> _msgTimestamps = [];
  final List<int> _warningTimestamps = [];
  int _tempBlockSecondsLeft = 0;
  Timer? _tempBlockTimer;
  String? _spamWarning;

  String _activeStyle = 'basic';
  bool _isVip = false;
  StreamSubscription<bool>? _vipSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bumpDetector = BumpDetector(
      threshold: 3.5, // Sensitive enough for a gentle bump
      onBump: _handleLocalBump,
    );
    _bumpDetector.start();

    // Clear previous bumps to start fresh
    unawaited(_mergeService.clearBumps());
    _vipSub = PurchaseService().vipStatusStream().listen((isVip) {
      if (mounted) {
        setState(() {
          _isVip = isVip;
        });
      }
    });
    _initUserInfo().then((_) {
      _listenSoulMessages();
    });

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _overlayListenerSub = FlutterOverlayWindow.overlayListener.listen((event) {
        if (event == 'launch_app') {
          const MethodChannel('soul_locket/app_control').invokeMethod('bringToForeground');
        } else if (event == 'request_sync') {
          _sendOverlaySyncPayload();
        } else if (event is String && event.startsWith('{')) {
          try {
            final data = jsonDecode(event);
            if (data['action'] == 'send_msg') {
              final txt = data['text']?.toString() ?? '';
              if (txt.isNotEmpty) {
                _sendSoulMessage(txt, bypassSpamCheck: true);
              }
            }
          } catch (e) {
            debugPrint('[SoulMergeScreen] overlayListener error: $e');
          }
        }
      });
      FlutterOverlayWindow.isActive().then((active) {
        if (mounted) {
          setState(() {
            _overlayEnabled = active;
          });
        }
      });
    }

    _mergeTimesSub = _mergeService.watchMergeTimes().listen((mergeTimes) {
      debugPrint('[SoulMergeScreen] watchMergeTimes update: $mergeTimes');

      // Dùng role ('user1'/'user2') làm key — không dùng uid vì 2 người chung 1 uid.
      final prefs = SharedPreferences.getInstance();
      prefs.then((p) {
        final myRole = p.getString('il_role')?.trim() == 'user2' ? 'user2' : 'user1';
        final partnerRole = myRole == 'user2' ? 'user1' : 'user2';
        final iBumped = mergeTimes.containsKey(myRole);
        final partnerBumped = mergeTimes.containsKey(partnerRole);

        if (mounted) {
          setState(() {
            _iHaveBumped = iBumped;
            _partnerHasBumped = partnerBumped;
          });
        }

        if (iBumped && partnerBumped) {
          final time1 = mergeTimes[myRole]!;
          final time2 = mergeTimes[partnerRole]!;
          final diff = (time1 - time2).abs();
          debugPrint('[SoulMergeScreen] Time diff between bumps: ${diff}ms');
          if (diff < 1500) {
            _triggerMerge();
          }
        }
      });
    });
  }

  void _handleLocalBump() {
    if (_isMerged) return;
    debugPrint('[SoulMergeScreen] _handleLocalBump triggered (bump or tap)');
    _mergeService.reportBump();
    HapticFeedback.mediumImpact();
    // NOTE: Heart spawning is handled exclusively by _onTapDown to avoid double-spawn.
  }

  Future<void> _initUserInfo() async {
    try {
      _houseId = await _mergeService.getCurrentHouseId();
      if (_houseId != null && _houseId!.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final myRole = prefs.getString('il_role') ?? 'user1';
        final partnerRole = myRole == 'user2' ? 'user1' : 'user2';
        
        final defaultMyName = myRole == 'user2' ? 'bạn nữ' : 'bạn nam';
        final defaultPartnerName = partnerRole == 'user2' ? 'bạn nữ' : 'bạn nam';
        
        final lastSeen = prefs.getInt('soul_merge_last_seen_msg_ts') ?? 0;
        
        final isUserVip = await PurchaseService().isVip();
        var savedStyle = prefs.getString('soul_merge_heart_style') ?? 'basic';
        // Tạm thời mở miễn phí để test
        // if (savedStyle != 'basic' && !isUserVip) {
        //   savedStyle = 'basic';
        //   await prefs.setString('soul_merge_heart_style', 'basic');
        // }

        setState(() {
          _myRole = myRole;
          _myName = defaultMyName;
          _partnerName = defaultPartnerName;
          _lastSeenMsgTimestamp = lastSeen;
          _isVip = isUserVip;
          _activeStyle = savedStyle;
        });

        final settings = await HouseService().getHouseSettings(_houseId!);
        if (settings != null) {
          final myNameKey = myRole == 'user2' ? 'nameU2' : 'nameU1';
          final myCustomName = settings[myNameKey]?.toString().trim() ?? '';
          if (myCustomName.isNotEmpty) {
            setState(() {
              _myName = myCustomName;
            });
          }

          final partnerNameKey = partnerRole == 'user2' ? 'nameU2' : 'nameU1';
          final name = settings[partnerNameKey]?.toString().trim() ?? '';
          if (name.isNotEmpty) {
            setState(() {
              _partnerName = name;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[SoulMergeScreen] _initUserInfo error: $e');
    }
  }

  // Tap hearts logic is now completely isolated within the _TapHeartsOverlay widget

  void _sendAutoNotification() async {
    if (_notificationSent) return;
    if (_partnerHasBumped) return;
    if (_houseId == null || _houseId!.isEmpty) return;
    
    _notificationSent = true;
    await NotificationService().sendPartnerNotification(
      houseId: _houseId!,
      title: '💕 $_myName đang nhớ bạn!',
      body: 'Mở Soul Locket để ghép đôi tâm hồn cùng $_myName ngay nhé! 💖',
      data: const {'screen': 'soul_merge', 'type': 'soul_merge'},
    );
    debugPrint('[SoulMergeScreen] Automatic partner notification sent.');
  }

  void _sendManualNudgeNotification() async {
    if (_houseId == null || _houseId!.isEmpty) return;
    
    await NotificationService().sendPartnerNotification(
      houseId: _houseId!,
      title: '💕 Bạn ơi, $_myName đang nhớ bạn!',
      body: '$_myName đang đợi bạn chạm vào trái tim để ghép đôi tâm hồn trong ứng dụng đó! 💖',
      data: const {'screen': 'soul_merge', 'type': 'soul_merge'},
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã gửi tín hiệu nhớ thương đến $_partnerName! 💕',
            style: SLTheme.quicksand(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFFF4F93),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onTapDown(Offset globalPosition) {
    setState(() {
      _interactiveScale = 0.9;
      _isDragging = true;
      _dragStartPos = globalPosition;
      _heartOffset = Offset.zero;
    });
    _lastTapPosition = globalPosition;
    _lastSpawnedPosition = globalPosition;
    _heartsOverlayKey.currentState?.spawnExplosion(globalPosition);
    _handleLocalBump();
    _sendAutoNotification();

    // Speed up heart beating pulse
    _pulseController.duration = const Duration(milliseconds: 400);
    _pulseController.repeat(reverse: true);

    // Continuous heart spawning & haptic feedback timer - 60ms for smooth dense stream following finger
    _continuousHeartsTimer?.cancel();
    _continuousHeartsTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted || _isMerged) {
        timer.cancel();
        return;
      }
      _heartsOverlayKey.currentState?.spawnExplosion(_lastTapPosition);
      HapticFeedback.lightImpact();
    });
  }

  void _onTapUp() {
    _continuousHeartsTimer?.cancel();
    _continuousHeartsTimer = null;
    setState(() {
      _interactiveScale = 1.0;
      _isDragging = false;
      _heartOffset = Offset.zero;
    });
    // Reset heart beating pulse to normal speed
    _pulseController.duration = const Duration(milliseconds: 1500);
    _pulseController.repeat(reverse: true);
  }

  void _onTapCancel() {
    _continuousHeartsTimer?.cancel();
    _continuousHeartsTimer = null;
    setState(() {
      _interactiveScale = 1.0;
      _isDragging = false;
      _heartOffset = Offset.zero;
    });
    // Reset heart beating pulse to normal speed
    _pulseController.duration = const Duration(milliseconds: 1500);
    _pulseController.repeat(reverse: true);
  }

  String _getConnectionStatusText() {
    if (!_iHaveBumped && !_partnerHasBumped) {
      return 'Đang chờ hai bạn chạm... 💫';
    } else if (_iHaveBumped && !_partnerHasBumped) {
      return 'Bạn đã chạm! Đang chờ $_partnerName chạm cùng lúc... 💕';
    } else if (!_iHaveBumped && _partnerHasBumped) {
      return '$_partnerName đã chạm! Chạm vào trái tim để kết nối ngay nhé! 💞';
    } else {
      return 'Đang kết nối... 💖';
    }
  }

  Color _getConnectionStatusColor() {
    if (_iHaveBumped || _partnerHasBumped) {
      return const Color(0xFFFF7FB2);
    }
    return Colors.white70;
  }

  List<Widget> _buildSparkles() {
    const double radius = 78;
    // Fixed sizes for each sparkle — do NOT change with pulse to avoid position jumping
    const fixedSizes = [6.0, 4.5, 6.0, 4.5, 6.0, 4.5];
    const sparkleColors = [
      Color(0xFFFF80B3),
      Color(0xFFD8A4FF),
      Color(0xFFFFD6EE),
      Color(0xFFA8C8FF),
      Color(0xFFFFEAA0),
      Color(0xFFFFB7D5),
    ];
    final sparkleAngles = [0.0, 60.0, 120.0, 180.0, 240.0, 300.0];
    final pulseVal = _pulseAnim.value; // 0.0 → 1.0
    return List.generate(sparkleAngles.length, (i) {
      final angleRad = sparkleAngles[i] * math.pi / 180;
      final dx = math.cos(angleRad) * radius;
      final dy = math.sin(angleRad) * radius;
      // Use FIXED size for position math — positions never shift
      final size = fixedSizes[i];
      // Alternate sparkles breathe in/out opposite phases
      final opacity = (i % 2 == 0 ? (0.3 + 0.65 * pulseVal) : (0.95 - 0.65 * pulseVal)).clamp(0.0, 1.0);
      return Positioned(
        // 100 = half of the 200px SizedBox — static center
        left: 100 + dx - size / 2,
        top: 100 + dy - size / 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sparkleColors[i % sparkleColors.length],
                boxShadow: [
                  BoxShadow(
                    color: sparkleColors[i % sparkleColors.length].withValues(alpha: 0.7),
                    blurRadius: size * 2.0,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<List<Map<String, String>>> _fetchMemoriesData() async {
    try {
      final houseId = await _mergeService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return const [];

      final dbRef = FirebaseDatabase.instance.ref();
      final memoriesSnap = await dbRef.child('houses/$houseId/memories').limitToLast(15).get();
      final diarySnap = await dbRef.child('houses/$houseId/diary').limitToLast(15).get();

      final List<Map<String, String>> items = [];

      if (memoriesSnap.value is Map) {
        final map = memoriesSnap.value as Map;
        map.forEach((key, val) {
          if (val is Map) {
            final imageUrl = (val['url'] ?? val['imageUrl'] ?? val['thumbUrl'] ?? '').toString().trim();
            final tsRaw = val['timestamp'] ?? val['ts'];
            String dateStr = '';
            if (tsRaw is int) {
              final dt = DateTime.fromMillisecondsSinceEpoch(tsRaw);
              dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
            }
            if (imageUrl.isNotEmpty) {
              items.add({
                'url': imageUrl,
                'text': '',
                'type': 'photo',
                'mood': '💖',
                'dateStr': dateStr,
              });
            }
          }
        });
      }

      if (diarySnap.value is Map) {
        final map = diarySnap.value as Map;
        map.forEach((key, val) {
          if (val is Map) {
            final post = DiaryPost.fromJson(key.toString(), val);
            final dt = post.timestamp;
            final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
            if (post.imageUrl.isNotEmpty) {
              items.add({
                'url': post.imageUrl,
                'text': post.content,
                'type': 'photo',
                'mood': post.mood,
                'dateStr': dateStr,
              });
            } else if (post.content.isNotEmpty) {
              items.add({
                'url': '',
                'text': post.content,
                'type': 'text',
                'mood': post.mood,
                'dateStr': dateStr,
              });
            }
          }
        });
      }

      if (items.isEmpty) {
        items.add({
          'url': '',
          'text': 'Hai tâm hồn hòa quyện cùng nhau 💕',
          'type': 'text',
          'mood': '💖',
          'dateStr': '',
        });
        items.add({
          'url': '',
          'text': 'Cùng nhau lưu giữ từng kỷ niệm ngọt ngào tại Soul Locket 🏡',
          'type': 'text',
          'mood': '🥰',
          'dateStr': '',
        });
      }

      return items;
    } catch (e) {
      debugPrint('[SoulMergeScreen] _fetchMemoriesData error: $e');
      return const [];
    }
  }

  void _triggerMerge() async {
    if (_isMerged) return;
    debugPrint('[SoulMergeScreen] Merging triggered!');
    setState(() {
      _isMerged = true;
    });
    _bumpDetector.stop();
    _pulseController.stop();
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      HapticFeedback.heavyImpact();
    });

    // Fetch memory fragments and start explosion loop
    final data = await _fetchMemoriesData();
    if (mounted) {
      setState(() {
        _memoriesData = data;
      });
      if (_memoriesData.isNotEmpty) {
        _startPhotoExplosions();
      }
    }
  }

  void _startPhotoExplosions() {
    _explosionTimer?.cancel();
    _spawnPhotoExplosion();
    _explosionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _spawnPhotoExplosion();
    });
  }

  void _spawnPhotoExplosion() {
    if (_memoriesData.isEmpty) return;
    final randomItem = _memoriesData[_random.nextInt(_memoriesData.length)];
    
    final size = MediaQuery.of(context).size;
    final double x = 30 + _random.nextDouble() * (size.width - 200);
    final double y = 140 + _random.nextDouble() * (size.height - 380);
    final position = Offset(x, y);

    final photo = ExplodingPhoto(
      url: randomItem['url'] ?? '',
      text: randomItem['text'] ?? '',
      type: randomItem['type'] ?? 'photo',
      mood: randomItem['mood'] ?? '💖',
      dateStr: randomItem['dateStr'] ?? '',
      position: position,
      angle: (_random.nextDouble() - 0.5) * 0.4, // Slight rotation
      targetScale: 0.8 + _random.nextDouble() * 0.4,
    );

    final particleId = UniqueKey();

    setState(() {
      _activePhotos.add(photo);
      _activeParticleExplosions.add((position: position, id: particleId));
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _activeParticleExplosions.removeWhere((item) => item.id == particleId);
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _activePhotos.removeWhere((p) => p.id == photo.id);
        });
      }
    });
  }

  @override
  void dispose() {
    _vipSub?.cancel();
    _customMsgController.dispose();
    _chatScrollController.dispose();
    _messagesSub?.cancel();
    _continuousHeartsTimer?.cancel();
    _bumpDetector.stop();
    _mergeTimesSub?.cancel();
    _overlayListenerSub?.cancel();
    _pulseController.dispose();
    _explosionTimer?.cancel();
    _tempBlockTimer?.cancel();
    unawaited(_mergeService.clearBumps());
    unawaited(_mergeService.clearChat());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0533),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _showHeartStyleSheet,
            icon: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
            ),
            tooltip: 'Chọn kiểu hiệu ứng',
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            IconButton(
              onPressed: _toggleOverlaySetting,
              icon: Icon(
                _overlayEnabled ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                color: _overlayEnabled ? const Color(0xFFFF4F93) : Colors.white,
              ),
              tooltip: 'Bong bóng nổi ngoài app',
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2C0B3E),
                  Color(0xFF611756),
                  Color(0xFF9C2A6F),
                  Color(0xFFE2528F),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),
          
          // Soft glowing orbs for cuteness
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7FB2).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            top: 350,
            right: 30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD81B60).withValues(alpha: 0.06),
              ),
            ),
          ),

          // Isolated tap hearts particle overlay
          _TapHeartsOverlay(
            key: _heartsOverlayKey,
            style: _activeStyle,
          ),
          
          // 4. Floating message bubbles
          for (final msg in _floatingMessages)
            FloatingMessageWidget(key: msg.id, message: msg),

          if (!_isMerged)
            Padding(
              padding: const EdgeInsets.only(bottom: 140.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Listener(
                      onPointerDown: (event) {
                        _onTapDown(event.position);
                      },
                      onPointerMove: (event) {
                        _lastTapPosition = event.position;
                        final lastPos = _lastSpawnedPosition;
                        if (lastPos == null || (event.position - lastPos).distance > 8.0) {
                          _lastSpawnedPosition = event.position;
                          _heartsOverlayKey.currentState?.spawnExplosion(event.position, count: 2);
                        }
                        setState(() {
                          final delta = event.position - _dragStartPos;
                          final distance = delta.distance;
                          // Limit drag distance to 180.0 pixels to stay within screen boundaries
                          if (distance > 180.0) {
                            _heartOffset = delta * (180.0 / distance);
                          } else {
                            _heartOffset = delta;
                          }
                        });
                      },
                      onPointerUp: (event) {
                        _onTapUp();
                      },
                      onPointerCancel: (event) {
                        _onTapCancel();
                      },
                      child: TweenAnimationBuilder<Offset>(
                        tween: Tween<Offset>(
                          begin: _heartOffset,
                          end: _isDragging ? _heartOffset : Offset.zero,
                        ),
                        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        builder: (context, offset, child) {
                          return Transform.translate(
                            offset: offset,
                            child: child,
                          );
                        },
                        child: AnimatedScale(
                          scale: _interactiveScale,
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOut,
                          child: ScaleTransition(
                            scale: _pulseAnim,
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outermost soft glow ring
                                Container(
                                  width: 190,
                                  height: 190,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE879A0).withValues(alpha: 0.12),
                                        blurRadius: 36,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFFBF70FF).withValues(alpha: 0.08),
                                        blurRadius: 60,
                                        spreadRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                // Subtle ring 1
                                Container(
                                  width: 162,
                                  height: 162,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFF80B3).withValues(alpha: 0.18),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                // Subtle ring 2
                                Container(
                                  width: 136,
                                  height: 136,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFF80B3).withValues(alpha: 0.10),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                // Cute sticker heart
                                Image.asset(
                                  'assets/images/interaction_stickers/custom/numbered/sticker_098.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                  isAntiAlias: true,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (_, __, ___) => ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFFF80B3), Color(0xFFD454A0)],
                                    ).createShader(bounds),
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.white,
                                      size: 90,
                                    ),
                                  ),
                                ),
                                // Sparkle dots around the heart - wrapped in AnimatedBuilder to ensure smooth continuous breathing opacity
                                AnimatedBuilder(
                                  animation: _pulseAnim,
                                  builder: (context, _) => Stack(
                                    children: _buildSparkles(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                    const SizedBox(height: 50),
                    Text(
                      'Soul Merge',
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          // Connection Status Line
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              _getConnectionStatusText(),
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                color: _getConnectionStatusColor(),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!_partnerHasBumped && _houseId != null && _houseId!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _sendManualNudgeNotification,
                              icon: const Icon(Icons.favorite_rounded, size: 14),
                              label: Text(
                                'Nhắc $_partnerName chạm',
                                style: SLTheme.quicksand(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  fontSize: 13,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF7FB2),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              ),
                            ),
                          ],
                          // Removed toggle card from bottom as it is now in the AppBar
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // 1. Particle explosions (behind photos)
            for (final explosion in _activeParticleExplosions)
              ParticleExplosionWidget(key: explosion.id, position: explosion.position),

            // 2. Popping Polaroids (foreground)
            for (final photo in _activePhotos)
              ExplodingPhotoWidget(key: photo.id, photo: photo),

            // 3. Merged Header Text
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Đã Kết Nối!',
                      style: SLTheme.quicksand(
                        color: const Color(0xFFFF4F93),
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: const Color(0xFFFF4F93).withValues(alpha: 0.5),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kỷ niệm đang tràn ngập tâm hồn hai bạn...',
                      style: SLTheme.quicksand(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Message / Preset Chat Input Bar at the bottom
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: _buildChatInputBar(),
          ),
        ],
      ),
    );
  }

  void _listenSoulMessages() {
    _messagesSub = _mergeService.watchSoulMessages().listen((list) {
      if (!mounted) return;

      final isFirstLoad = (_lastMsgTimestamp == 0);
      int maxTimestamp = _lastMsgTimestamp;

      if (isFirstLoad) {
        if (list.isNotEmpty) {
          final unreadMsgs = list.where((msg) {
            final t = msg['timestamp'] as int? ?? 0;
            final sender = (msg['sender'] ?? '').toString().trim();
            final isSelf = (sender == _myRole);
            return t > _lastSeenMsgTimestamp && !isSelf;
          }).toList();

          for (int i = 0; i < unreadMsgs.length; i++) {
            final msg = unreadMsgs[i];
            final text = (msg['text'] ?? '').toString().trim();
            if (text.isNotEmpty) {
              final delayMs = i * 800; // Staggered by 800ms
              Future.delayed(Duration(milliseconds: delayMs), () {
                if (mounted) {
                  _spawnFloatingMessage(text, false);
                }
              });
            }
          }

          for (final msg in list) {
            final t = msg['timestamp'] as int? ?? 0;
            if (t > maxTimestamp) maxTimestamp = t;
          }
        } else {
          maxTimestamp = DateTime.now().millisecondsSinceEpoch;
        }
      }

      for (final msg in list) {
        final t = msg['timestamp'] as int? ?? 0;
        if (t > _lastMsgTimestamp) {
          if (t > maxTimestamp) maxTimestamp = t;
          if (!isFirstLoad) {
            final text = (msg['text'] ?? '').toString().trim();
            final sender = (msg['sender'] ?? '').toString().trim();
            if (text.isNotEmpty && sender.isNotEmpty) {
              final isSelf = (sender == _myRole);
              _spawnFloatingMessage(text, isSelf);

              if (!isSelf && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                FlutterOverlayWindow.isActive().then((active) {
                  if (active) {
                    final payload = jsonEncode({
                      'type': 'new_msg_preview',
                      'text': text,
                    });
                    FlutterOverlayWindow.shareData(payload);
                  }
                });
              }
            }
          }
        }
      }

      setState(() {
        _chatHistory = list;
        _lastMsgTimestamp = maxTimestamp;
      });

      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('soul_merge_last_seen_msg_ts', maxTimestamp);
      });

      _sendOverlaySyncPayload();

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        FlutterOverlayWindow.isActive().then((active) {
          if (mounted && _overlayEnabled != active) {
            setState(() {
              _overlayEnabled = active;
            });
          }
        });
      }

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.jumpTo(_chatScrollController.position.maxScrollExtent);
        }
      });
    });
  }

  void _spawnFloatingMessage(String text, bool isSelf) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final double x = isSelf
        ? size.width * 0.25 + _random.nextDouble() * (size.width * 0.1)
        : size.width * 0.05 + _random.nextDouble() * (size.width * 0.13);
    final double y = isSelf
        ? size.height * 0.4 + _random.nextDouble() * 120.0
        : size.height * 0.2 + _random.nextDouble() * 150.0;

    final msg = FloatingMessage(
      text: text,
      isSelf: isSelf,
      position: Offset(x, y),
    );

    setState(() {
      _floatingMessages.add(msg);
    });

    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) {
        setState(() {
          _floatingMessages.removeWhere((m) => m.id == msg.id);
        });
      }
    });
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

  Future<void> _sendSoulMessage(String text, {bool bypassSpamCheck = false}) async {
    if (!bypassSpamCheck && await _checkSpamAndMaybeBlock()) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _mergeService.sendSoulMessage(trimmed);

    // Send push notification to partner's main home screen
    if (_houseId != null && _houseId!.isNotEmpty) {
      unawaited(
        NotificationService().sendPartnerNotification(
          houseId: _houseId!,
          title: '💬 Lời thì thầm từ $_myName',
          body: trimmed,
          data: const {'screen': 'soul_merge', 'type': 'soul_merge'},
        ),
      );
    }
  }

  void _sendCustomMessage() {
    final text = _customMsgController.text.trim();
    if (text.isEmpty) return;
    _customMsgController.clear();
    unawaited(_sendSoulMessage(text));
    FocusScope.of(context).unfocus();
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildChatInputBar() {
    final presetsBefore = ['Cụng đi! 📲', 'Chờ tí nhé ⏳', 'Nhớ thương 💕'];
    final presetsAfter = ['Yêu bạn 😘', 'Nhớ quá! 💖', 'Ú òa! 👻'];
    final presets = _isMerged ? presetsAfter : presetsBefore;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_spamWarning != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4F4F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF4F4F).withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF4F4F),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _spamWarning!,
                      style: SLTheme.quicksand(
                        color: const Color(0xFFFFD1D1),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Chat History List Container (Glassmorphic)
          Container(
            height: 160,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _chatHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.35),
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hãy gửi những lời thì thầm tâm hồn... 💕',
                            style: SLTheme.quicksand(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _chatHistory.length,
                      itemBuilder: (context, index) {
                        final msg = _chatHistory[index];
                        final sender = (msg['sender'] ?? '').toString();
                        final isSelf = (sender == _myRole);
                        final text = (msg['text'] ?? '').toString();
                        final timeStr = _formatTime(msg['timestamp'] as int?);

                        return Align(
                          alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.only(
                              top: 4,
                              bottom: 4,
                              left: isSelf ? 48 : 0,
                              right: isSelf ? 0 : 48,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelf
                                  ? const LinearGradient(
                                      colors: [Color(0xFFFF4F93), Color(0xFFE2528F)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: Radius.circular(isSelf ? 14 : 2),
                                bottomRight: Radius.circular(isSelf ? 2 : 14),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isSelf ? const Color(0xFFFF4F93) : const Color(0xFF8E2DE2))
                                      .withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  text,
                                  style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (timeStr.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    timeStr,
                                    style: SLTheme.quicksand(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((text) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _sendSoulMessage(text),
                    borderRadius: BorderRadius.circular(20),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        text,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _customMsgController,
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn tâm hồn...',
                        hintStyle: SLTheme.quicksand(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (_) => _sendCustomMessage(),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _sendCustomMessage,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF4F93), Color(0xFFE2528F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
  void _sendOverlaySyncPayload() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    FlutterOverlayWindow.isActive().then((active) {
      if (active) {
        final payload = jsonEncode({
          'type': 'update_chat',
          'history': _chatHistory,
          'myRole': _myRole,
          'partnerName': _partnerName,
        });
        FlutterOverlayWindow.shareData(payload);
      }
    });
  }

  Future<void> _toggleOverlaySetting() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!_overlayEnabled) {
      if (!granted) {
        final reqResult = await FlutterOverlayWindow.requestPermission();
        if (reqResult != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cần cấp quyền hiển thị trên ứng dụng khác để bật bong bóng nổi!',
                  style: SLTheme.quicksand(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          return;
        }
      }
      
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: 80,
        width: 80,
        alignment: OverlayAlignment.centerRight,
        overlayTitle: 'Bong bóng tâm hồn',
        overlayContent: 'Lời thì thầm đang kết nối...',
      );

      if (mounted) {
        setState(() {
          _overlayEnabled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã bật bong bóng nổi ngoài ứng dụng! 💬',
              style: SLTheme.quicksand(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFFF4F93),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      await FlutterOverlayWindow.closeOverlay();
      if (mounted) {
        setState(() {
          _overlayEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã tắt bong bóng nổi ngoài ứng dụng.',
              style: SLTheme.quicksand(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _selectHeartStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('soul_merge_heart_style', style);
    if (mounted) {
      setState(() {
        _activeStyle = style;
      });
    }
  }

  void _showHeartStyleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF2C0B3E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white12, width: 1.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kiểu hiệu ứng thả tim',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chọn phong cách tim bay cao cấp dành riêng cho bạn',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStyleItem(
                    title: 'Basic Pink',
                    desc: 'Hiệu ứng màu hồng pastel ngọt ngào cơ bản',
                    styleKey: 'basic',
                    isPremium: false,
                    color: const Color(0xFFFFB7D5),
                    setSheetState: setSheetState,
                  ),
                  const SizedBox(height: 12),
                  _buildStyleItem(
                    title: 'Neon Aurora 🌟',
                    desc: 'Tim phát sáng đổi màu neon lung linh kèm vệt sao lấp lánh',
                    styleKey: 'aurora',
                    isPremium: false,
                    color: const Color(0xFF00FFCC),
                    setSheetState: setSheetState,
                  ),
                  const SizedBox(height: 12),
                  _buildStyleItem(
                    title: 'Cosmic Sparkle ✨',
                    desc: 'Tim nhịp điệu vũ trụ bay lắc lư hình sin và vòng sáng tinh tú',
                    styleKey: 'cosmic',
                    isPremium: false,
                    color: const Color(0xFFFFD700),
                    setSheetState: setSheetState,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStyleItem({
    required String title,
    required String desc,
    required String styleKey,
    required bool isPremium,
    required Color color,
    required StateSetter setSheetState,
  }) {
    final bool isSelected = (_activeStyle == styleKey);
    final bool canUse = true; // Tạm thời mở miễn phí để test

    return InkWell(
      onTap: () {
        if (!canUse) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PremiumStoreScreen(
                houseId: _houseId ?? '',
                myName: _myName,
              ),
            ),
          );
          return;
        }
        
        _selectHeartStyle(styleKey);
        setSheetState(() {});
        setState(() {});
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : Colors.white24,
                  width: 2.0,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isPremium && !_isVip) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PRO (TEST) 🔓',
                            style: SLTheme.quicksand(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: SLTheme.quicksand(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class ExplodingPhoto {
  final String url;
  final String text;
  final String type; // 'photo' | 'text'
  final String mood;
  final String dateStr;
  final Offset position;
  final double angle;
  final double targetScale;
  final UniqueKey id = UniqueKey();
  
  ExplodingPhoto({
    required this.url,
    this.text = '',
    this.type = 'photo',
    this.mood = '💖',
    this.dateStr = '',
    required this.position,
    required this.angle,
    required this.targetScale,
  });
}

class ExplodingPhotoWidget extends StatefulWidget {
  final ExplodingPhoto photo;
  const ExplodingPhotoWidget({super.key, required this.photo});

  @override
  State<ExplodingPhotoWidget> createState() => _ExplodingPhotoWidgetState();
}

class _ExplodingPhotoWidgetState extends State<ExplodingPhotoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Popping entrance and fading exit
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: widget.photo.targetScale)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30, // Popping entrance in first 30% of time
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(widget.photo.targetScale),
        weight: 50, // Holds size
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.photo.targetScale, end: 0.5)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20, // Shrinks out at the end
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.photo.position.dx,
      top: widget.photo.position.dy,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: widget.photo.angle,
                child: child,
              ),
            ),
          );
        },
        child: widget.photo.type == 'text'
            ? Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFF4F93).withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.photo.mood, style: const TextStyle(fontSize: 14)),
                        if (widget.photo.dateStr.isNotEmpty)
                          Text(
                            widget.photo.dateStr,
                            style: SLTheme.quicksand(
                              color: Colors.black54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.photo.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                width: 140,
                height: 170,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.photo.url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.purple.shade50,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.purple.shade100,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF4F93),
                          size: 12,
                        ),
                        if (widget.photo.dateStr.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            widget.photo.dateStr,
                            style: SLTheme.quicksand(
                              color: Colors.black54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class Particle {
  final Offset velocity;
  final Color color;
  double scale;
  
  Particle({
    required this.velocity,
    required this.color,
    this.scale = 1.0,
  });
}

class ParticleExplosionWidget extends StatefulWidget {
  final Offset position;
  const ParticleExplosionWidget({super.key, required this.position});

  @override
  State<ParticleExplosionWidget> createState() => _ParticleExplosionWidgetState();
}

class _ParticleExplosionWidgetState extends State<ParticleExplosionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create 16 particles spreading outwards
    final colors = [
      const Color(0xFFFF4F93),
      const Color(0xFFFF8E53),
      const Color(0xFFFFEA79),
      const Color(0xFF84FF84),
      const Color(0xFF84D7FF),
    ];
    for (int i = 0; i < 16; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 2.0 + _random.nextDouble() * 4.0;
      _particles.add(
        Particle(
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          color: colors[_random.nextInt(colors.length)],
          scale: 3.0 + _random.nextDouble() * 4.0,
        ),
      );
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx + 70, // Center of the 140 width polaroid
      top: widget.position.dy + 85,  // Center of the 170 height polaroid
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          return CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              progress: progress,
            ),
          );
        },
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (final particle in particles) {
      final offset = particle.velocity * (progress * 40.0);
      final opacity = 1.0 - progress;
      paint.color = particle.color.withValues(alpha: opacity);
      
      final radius = particle.scale * (1.0 - progress * 0.5);
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TinyHeart {
  final double angle;
  final double speed;
  final double size;
  Color color;
  final UniqueKey id = UniqueKey();
  double x;
  double y;
  double opacity = 1.0;

  // New fields for premium styles
  final String style;
  final double startX;
  final double swayPhase;
  double lifeTimeProgress = 0.0;
  final List<Offset> trail = [];

  TinyHeart({
    required this.x,
    required this.y,
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.style,
  }) : startX = x,
       swayPhase = math.Random().nextDouble() * math.pi * 2;
}

class _TapHeartsOverlay extends StatefulWidget {
  final String style;
  const _TapHeartsOverlay({super.key, required this.style});

  @override
  State<_TapHeartsOverlay> createState() => _TapHeartsOverlayState();
}

class _TapHeartsOverlayState extends State<_TapHeartsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tickerController;
  final List<TinyHeart> _hearts = [];

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tickHearts);
  }

  void _tickHearts() {
    if (_hearts.isEmpty) {
      if (_tickerController.isAnimating) {
        _tickerController.stop();
      }
      return;
    }

    setState(() {
      const double dt = 0.016; // approximate delta time per frame
      for (int i = _hearts.length - 1; i >= 0; i--) {
        final heart = _hearts[i];
        heart.lifeTimeProgress += dt;

        if (heart.style == 'cosmic') {
          final double sway = math.sin(heart.lifeTimeProgress * 10.0 + heart.swayPhase) * 1.5;
          heart.x += math.cos(heart.angle) * heart.speed + sway;
          heart.y += math.sin(heart.angle) * heart.speed - 1.5;
        } else if (heart.style == 'aurora') {
          heart.trail.add(Offset(heart.x, heart.y));
          if (heart.trail.length > 10) {
            heart.trail.removeAt(0);
          }
          final double wave = math.sin(heart.lifeTimeProgress * 15.0 + heart.swayPhase) * 0.8;
          heart.x += math.cos(heart.angle) * heart.speed + wave;
          heart.y += math.sin(heart.angle) * heart.speed - 1.8;

          final hsl = HSLColor.fromColor(heart.color);
          final newHue = (hsl.hue + 2.5) % 360;
          heart.color = hsl.withHue(newHue).toColor();
        } else {
          heart.x += math.cos(heart.angle) * heart.speed;
          heart.y += math.sin(heart.angle) * heart.speed - 1.2;
        }

        final double fadeRate = heart.style == 'cosmic' ? 0.015 : 0.02;
        heart.opacity -= fadeRate;

        if (heart.opacity <= 0 || heart.y < -100 || heart.x < -100) {
          _hearts.removeAt(i);
        }
      }
    });
  }

  void spawnExplosion(Offset globalPosition, {int count = 8}) {
    if (!mounted) return;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) {
      return;
    }

    const palettes = [
      [Color(0xFFFFB7D5), Color(0xFFFF8FB7), Color(0xFFFFD6EE), Color(0xFFFF6BA8)],
      [Color(0xFFD8A4FF), Color(0xFFC680FF), Color(0xFFEDD5FF), Color(0xFFB85EFF)],
      [Color(0xFFA8C8FF), Color(0xFF7AABFF), Color(0xFFCCE0FF), Color(0xFF5591FF)],
      [Color(0xFFFFEAA0), Color(0xFFFFD966), Color(0xFFFFF3CC), Color(0xFFFFCB33)],
      [Color(0xFFA8F0D0), Color(0xFF6EDBB4), Color(0xFFCCF7E5), Color(0xFF3DC98E)],
      [Color(0xFFFFCBA4), Color(0xFFFFAA77), Color(0xFFFFE3CC), Color(0xFFFF8844)],
    ];

    try {
      final localPosition = renderBox.globalToLocal(globalPosition);
      final random = math.Random();
      final palette = palettes[random.nextInt(palettes.length)];
      
      setState(() {
        for (int i = 0; i < count; i++) {
          final angle = random.nextDouble() * math.pi * 2;
          final speed = 1.5 + random.nextDouble() * 3.0;
          final size = 12.0 + random.nextDouble() * 16.0;
          
          _hearts.add(
            TinyHeart(
              x: localPosition.dx,
              y: localPosition.dy,
              angle: angle,
              speed: speed,
              size: size,
              color: palette[random.nextInt(palette.length)],
              style: widget.style,
            ),
          );
        }
      });
      if (!_tickerController.isAnimating) {
        _tickerController.repeat();
      }
    } catch (e) {
      debugPrint('[_TapHeartsOverlay] spawnExplosion error: $e');
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hearts.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _HeartsPainter(hearts: _hearts),
        size: Size.infinite,
      ),
    );
  }
}

class _HeartsPainter extends CustomPainter {
  final List<TinyHeart> hearts;
  final Path _reusablePath = Path();
  final Path _reusableStarPath = Path();

  _HeartsPainter({required this.hearts});

  @override
  void paint(Canvas canvas, Size size) {
    for (final heart in hearts) {
      if (heart.opacity <= 0) continue;

      final double progress = heart.lifeTimeProgress;
      double drawSize = heart.size;
      final mainPaint = Paint()..style = PaintingStyle.fill;

      if (heart.style == 'cosmic') {
        drawSize = heart.size * (1.0 + 0.25 * math.sin(progress * 18.0));
        
        final trailPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFD700).withValues(alpha: heart.opacity * 0.4);
        
        for (int j = 0; j < 2; j++) {
          final double orbitAngle = progress * 8.0 + (j * math.pi);
          final double orbitRadius = drawSize * 0.8;
          final double sx = heart.x + math.cos(orbitAngle) * orbitRadius;
          final double sy = heart.y + math.sin(orbitAngle) * orbitRadius;
          _drawStar(canvas, trailPaint, sx, sy, drawSize * 0.25);
        }

        // Tối ưu hóa: Thay thế MaskFilter.blur bằng vẽ đa tầng độ mờ (concentric paths) cực kỳ mượt mà
        final glowColor = const Color(0xFFBF55EC).withValues(alpha: heart.opacity * 0.12);
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = glowColor;
        _drawHeartShape(canvas, glowPaint, heart.x, heart.y, drawSize * 1.5);
        _drawHeartShape(canvas, glowPaint, heart.x, heart.y, drawSize * 1.25);
        
        mainPaint.color = heart.color.withValues(alpha: heart.opacity);
        _drawHeartShape(canvas, mainPaint, heart.x, heart.y, drawSize);

        final corePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: heart.opacity * 0.8);
        _drawHeartShape(canvas, corePaint, heart.x, heart.y - (drawSize * 0.05), drawSize * 0.4);

      } else if (heart.style == 'aurora') {
        // Tối ưu hóa: Nhảy bước j += 2 để giảm 50% số lượng vẽ sao vệt đường (trail) nặng nề
        for (int j = 0; j < heart.trail.length; j += 2) {
          final double trailProgress = j / heart.trail.length;
          final Offset pos = heart.trail[j];
          final trailPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = heart.color.withValues(alpha: heart.opacity * 0.25 * trailProgress);
          
          _drawStar(canvas, trailPaint, pos.dx, pos.dy, drawSize * 0.35 * trailProgress);
        }

        // Tối ưu hóa: Thay thế MaskFilter.blur bằng vẽ đa tầng độ mờ cực kỳ mượt mà
        final glowColor = heart.color.withValues(alpha: heart.opacity * 0.15);
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = glowColor;
        _drawHeartShape(canvas, glowPaint, heart.x, heart.y, drawSize * 1.4);
        _drawHeartShape(canvas, glowPaint, heart.x, heart.y, drawSize * 1.2);

        mainPaint.color = heart.color.withValues(alpha: heart.opacity);
        _drawHeartShape(canvas, mainPaint, heart.x, heart.y, drawSize);

        final corePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: heart.opacity * 0.85);
        _drawHeartShape(canvas, corePaint, heart.x, heart.y, drawSize * 0.35);

      } else {
        mainPaint.color = heart.color.withValues(alpha: heart.opacity);
        _drawHeartShape(canvas, mainPaint, heart.x, heart.y, drawSize);
      }
    }
  }

  void _drawHeartShape(Canvas canvas, Paint paint, double x, double y, double size) {
    final width = size;
    final height = size * 0.9;
    
    _reusablePath.reset();
    _reusablePath.moveTo(x, y + height * 0.3);
    _reusablePath.cubicTo(x - width * 0.5, y - height * 0.2, x - width, y + height * 0.4, x, y + height);
    _reusablePath.moveTo(x, y + height * 0.3);
    _reusablePath.cubicTo(x + width * 0.5, y - height * 0.2, x + width, y + height * 0.4, x, y + height);

    canvas.drawPath(_reusablePath, paint);
  }

  void _drawStar(Canvas canvas, Paint paint, double x, double y, double radius) {
    _reusableStarPath.reset();
    _reusableStarPath.moveTo(x, y - radius);
    _reusableStarPath.quadraticBezierTo(x, y, x + radius, y);
    _reusableStarPath.quadraticBezierTo(x, y, x, y + radius);
    _reusableStarPath.quadraticBezierTo(x, y, x - radius, y);
    _reusableStarPath.quadraticBezierTo(x, y, x, y - radius);
    
    canvas.drawPath(_reusableStarPath, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartsPainter oldDelegate) => true;
}

class FloatingMessage {
  final String text;
  final bool isSelf;
  final Offset position;
  final UniqueKey id = UniqueKey();

  FloatingMessage({
    required this.text,
    required this.isSelf,
    required this.position,
  });
}

class FloatingMessageWidget extends StatefulWidget {
  final FloatingMessage message;
  const FloatingMessageWidget({super.key, required this.message});

  @override
  State<FloatingMessageWidget> createState() => _FloatingMessageWidgetState();
}

class _FloatingMessageWidgetState extends State<FloatingMessageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 75,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    _slideAnim = Tween<double>(begin: 0.0, end: -80.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.message.isSelf
        ? const Color(0xFFFF4F93)
        : const Color(0xFF9C2A6F);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.message.position.dx,
          top: widget.message.position.dy + _slideAnim.value,
          child: Opacity(
            opacity: _opacityAnim.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.message.isSelf ? 16 : 4),
            bottomRight: Radius.circular(widget.message.isSelf ? 4 : 16),
          ),
          border: Border.all(
            color: themeColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.25),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          widget.message.text,
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
