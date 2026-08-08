import 'dart:async';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:soullocket_app/models/diary_post.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:soullocket_app/utils/services/storage/storage_service.dart';
import 'package:soullocket_app/utils/helpers/bump_detector.dart';
import 'package:soullocket_app/utils/services/soul_merge_service.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/purchase_service.dart';
import 'package:soullocket_app/utils/services/giftcode_service.dart';
import 'package:soullocket_app/utils/sl_notice.dart';

part 'soul_merge/exploding_photo_part.dart';
part 'soul_merge/particle_explosion_part.dart';
part 'soul_merge/tap_hearts_overlay_part.dart';
part 'soul_merge/floating_message_part.dart';
part 'soul_merge/persistent_floating_photo_part.dart';
part 'soul_merge/soul_merge_painters_part.dart';

Stream<dynamic>? _sharedOverlayStream;

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
  final GlobalKey<TapHeartsOverlayState> _heartsOverlayKey =
      GlobalKey<TapHeartsOverlayState>();
  final ValueNotifier<double> _interactiveScaleNotifier = ValueNotifier(1.0);
  Timer? _continuousHeartsTimer;
  Offset _lastTapPosition = Offset.zero;
  Offset? _lastSpawnedPosition;
  DateTime? _lastManualNudgeTime;

  final TextEditingController _customMsgController = TextEditingController();
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub;
  StreamSubscription<Map<String, dynamic>>? _interactiveEventsSub;
  final List<FloatingMessage> _floatingMessages = [];
  final List<String> _persistentPhotos = [];
  bool _isUploadingPhoto = false;
  int _lastMsgTimestamp = 0;
  int _lastSeenMsgTimestamp = 0;
  int _lastAnyMsgTimestamp = 0;
  bool _hasProcessedFirstMessages = false;
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
  bool _showHeartNotif = false;
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
      _listenInteractiveEvents();
      _fetchMemoriesData().then((data) {
        if (mounted) setState(() => _memoriesData = data);
      });
    });

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _sharedOverlayStream ??=
          FlutterOverlayWindow.overlayListener.asBroadcastStream();
      _overlayListenerSub = _sharedOverlayStream!.listen((event) {
        if (event == 'launch_app') {
          const MethodChannel('soul_locket/app_control')
              .invokeMethod('bringToForeground');
        } else if (event == 'request_sync') {
          _sendOverlaySyncPayload();
        } else if (event is String && event.startsWith('{')) {
          try {
            final data = jsonDecode(event);
            if (data['action'] == 'send_msg') {
              // Overlay now sends messages directly to Firebase, no action needed here.
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
        final myRole =
            p.getString('il_role')?.trim() == 'user2' ? 'user2' : 'user1';
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

        final defaultMyName = myRole == 'user2'
            ? L10nService().translate('female_role_default')
            : L10nService().translate('male_role_default');
        final defaultPartnerName = partnerRole == 'user2'
            ? L10nService().translate('female_role_default')
            : L10nService().translate('male_role_default');

        final localLastSeen = prefs.getInt('soul_merge_last_seen_msg_ts') ?? 0;
        final remoteLastSeen = await _mergeService.getLastSeenTimestamp();
        final lastSeen = math.max(localLastSeen, remoteLastSeen);

        final isUserVip = await PurchaseService().isVip();
        var savedStyle = prefs.getString('soul_merge_heart_style') ?? 'basic';
        // Tạm thời mở miễn phí để test
        // if (savedStyle != 'basic' && !isUserVip) {
        //   savedStyle = 'basic';
        //   await prefs.setString('soul_merge_heart_style', 'basic');
        // }

        final showNotif = prefs.getBool('soul_merge_show_heart_notif') ?? false;

        setState(() {
          _myRole = myRole;
          _myName = defaultMyName;
          _partnerName = defaultPartnerName;
          _lastSeenMsgTimestamp = lastSeen;
          _isVip = isUserVip;
          _activeStyle = savedStyle;
          _showHeartNotif = showNotif;
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
        _sendOverlaySyncPayload();
      }
    } catch (e) {
      debugPrint('[SoulMergeScreen] _initUserInfo error: $e');
    }
  }

  // Tap hearts logic is now completely isolated within the _TapHeartsOverlay widget

  void _sendManualNudgeNotification() async {
    if (_houseId == null || _houseId!.isEmpty) return;

    final size = MediaQuery.of(context).size;
    _heartsOverlayKey.currentState
        ?.spawnExplosion(Offset(size.width / 2, size.height / 2), count: 8);

    await NotificationService().sendPartnerNotification(
      houseId: _houseId!,
      title: '💕 Bạn ơi, $_myName đang nhớ bạn!',
      body:
          '$_myName đang đợi bạn chạm vào trái tim để ghép đôi tâm hồn trong ứng dụng đó! 💖',
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickAndSendChatImage() async {
    if (_isUploadingPhoto) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';

      final savedDate = prefs.getString('il_sm_photo_date');
      int currentCount = prefs.getInt('il_sm_photo_count') ?? 0;

      if (savedDate != todayStr) {
        currentCount = 0;
        await prefs.setString('il_sm_photo_date', todayStr);
      }

      final maxPhotos = _isVip ? 50 : 20;
      if (currentCount >= maxPhotos) {
        if (mounted) {
          SLNotice.showError(
            context,
            _isVip
                ? 'Oops! 😢 Cậu đã hết lượt gửi $maxPhotos ảnh hôm nay. Hẹn cậu quay lại vào ngày mai nhé! 💕'
                : 'Oops! 😢 Tài khoản thường gửi tối đa $maxPhotos ảnh/ngày. Nâng cấp PRO để tha hồ gửi 50 ảnh/ngày nha! 💕',
          );
        }
        return;
      }

      final picker = ImagePicker();
      final image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      final houseId = _houseId ?? '';
      final uploadResult = await StorageService.instance.uploadPublicImage(
        houseId,
        'soul_merge_chat',
        XFile(image.path),
        quality: 50,
      );

      final url = uploadResult?.downloadUrl;
      if (url != null && url.isNotEmpty) {
        _mergeService.sendSoulMessage('', imageUrl: url);
        await prefs.setInt('il_sm_photo_count', currentCount + 1);
      }
    } catch (e) {
      debugPrint('Error uploading chat photo: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _onTapDown(Offset globalPosition) {
    _interactiveScaleNotifier.value = 0.9;
    _lastTapPosition = globalPosition;
    _lastSpawnedPosition = globalPosition;
    _heartsOverlayKey.currentState?.spawnExplosion(globalPosition);
    _handleLocalBump();

    final now = DateTime.now();
    if (_showHeartNotif &&
        (_lastManualNudgeTime == null ||
            now.difference(_lastManualNudgeTime!).inMinutes >= 10)) {
      _lastManualNudgeTime = now;
      _sendManualNudgeNotification();
    }

    if (_memoriesData.isNotEmpty) {
      final randomItem = _memoriesData[_random.nextInt(_memoriesData.length)];
      if (randomItem['url'] != null && randomItem['url']!.isNotEmpty) {
        _mergeService.sendInteractiveEvent(
          type: 'photo_shot',
          url: randomItem['url'],
          x: globalPosition.dx,
          y: globalPosition.dy,
        );
        _spawnPhotoExplosion(
            specificItem: randomItem,
            specificPosition:
                Offset(globalPosition.dx, globalPosition.dy - 100));
      }
    }

    // Speed up heart beating pulse
    _pulseController.duration = const Duration(milliseconds: 400);
    _pulseController.repeat(reverse: true);

    // Continuous heart spawning & haptic feedback timer - optimized for performance
    _continuousHeartsTimer?.cancel();
    int tickCount = 0;
    _continuousHeartsTimer =
        Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted || _isMerged) {
        timer.cancel();
        return;
      }
      _heartsOverlayKey.currentState
          ?.spawnExplosion(_lastTapPosition, count: 5);
      tickCount++;
      if (tickCount % 5 == 0) {
        // Limit haptics to every ~450ms
        HapticFeedback.lightImpact();
      }
    });
  }

  void _onTapUp() {
    _continuousHeartsTimer?.cancel();
    _continuousHeartsTimer = null;
    _interactiveScaleNotifier.value = 1.0;
    // Reset heart beating pulse to normal speed
    _pulseController.duration = const Duration(milliseconds: 1500);
    _pulseController.repeat(reverse: true);
  }

  void _onTapCancel() {
    _continuousHeartsTimer?.cancel();
    _continuousHeartsTimer = null;
    _interactiveScaleNotifier.value = 1.0;
    // Reset heart beating pulse to normal speed
    _pulseController.duration = const Duration(milliseconds: 1500);
    _pulseController.repeat(reverse: true);
  }

  // ignore: unused_element
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

  // ignore: unused_element
  Color _getConnectionStatusColor() {
    if (_iHaveBumped || _partnerHasBumped) {
      return const Color(0xFFFF7FB2);
    }
    return Colors.white70;
  }

  List<Widget> _buildSparkles() {
    const double radius = 45;
    // 4 sparkles thay vì 6 — tiết kiệm render
    const fixedSizes = [6.0, 4.5, 6.0, 4.5];
    const sparkleColors = [
      Color(0xFFFF80B3),
      Color(0xFFD8A4FF),
      Color(0xFFFFEAA0),
      Color(0xFFFFB7D5),
    ];
    final sparkleAngles = [0.0, 90.0, 180.0, 270.0];
    final pulseVal = _pulseAnim.value; // 0.0 → 1.0
    return List.generate(sparkleAngles.length, (i) {
      final angleRad = sparkleAngles[i] * math.pi / 180;
      final dx = math.cos(angleRad) * radius;
      final dy = math.sin(angleRad) * radius;
      // Use FIXED size for position math — positions never shift
      final size = fixedSizes[i];
      // Alternate sparkles breathe in/out opposite phases
      final opacity =
          (i % 2 == 0 ? (0.3 + 0.65 * pulseVal) : (0.95 - 0.65 * pulseVal))
              .clamp(0.0, 1.0);
      return Positioned(
        // 80 = half of the 160px Container — static center
        left: 80 + dx - size / 2,
        top: 80 + dy - size / 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sparkleColors[i % sparkleColors.length],
                // BoxShadow removed for Flat performance
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

      final memoriesSnap = await FirebaseFirestore.instance
          .collection('houses')
          .doc(houseId)
          .collection('album')
          .orderBy('ts', descending: true)
          .limit(15)
          .get();

      final diarySnap = await FirebaseFirestore.instance
          .collection('houses')
          .doc(houseId)
          .collection('diaries')
          .orderBy('ts', descending: true)
          .limit(15)
          .get();

      final List<Map<String, String>> items = [];

      for (var doc in memoriesSnap.docs) {
        final val = doc.data();
        final imageUrl =
            (val['url'] ?? val['imageUrl'] ?? val['thumbUrl'] ?? '')
                .toString()
                .trim();
        final tsRaw = val['timestamp'] ?? val['ts'];
        String dateStr = '';
        if (tsRaw is int) {
          final dt = DateTime.fromMillisecondsSinceEpoch(tsRaw);
          dateStr =
              '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
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

      for (var doc in diarySnap.docs) {
        final val = doc.data();
        final post = DiaryPost.fromJson(doc.id, val);
        final dt = post.timestamp;
        final dateStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

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

  void _spawnPhotoExplosion(
      {Map<String, String>? specificItem, Offset? specificPosition}) {
    if (_memoriesData.isEmpty && specificItem == null) return;
    final randomItem =
        specificItem ?? _memoriesData[_random.nextInt(_memoriesData.length)];

    final size = MediaQuery.of(context).size;
    final double x = 30 + _random.nextDouble() * (size.width - 200);
    final double y = 140 + _random.nextDouble() * (size.height - 380);
    final position = specificPosition ?? Offset(x, y);

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
          _activeParticleExplosions
              .removeWhere((item) => item.id == particleId);
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
    _interactiveEventsSub?.cancel();
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
    final photoMessages = _chatHistory
        .where((m) {
          final url = (m['imageUrl']?.toString() ?? '').trim();
          return url.startsWith('http://') || url.startsWith('https://');
        })
        .toList();
    final latestPhotos = photoMessages.length > 3
        ? photoMessages.sublist(photoMessages.length - 3)
        : photoMessages;

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
                _overlayEnabled
                    ? Icons.chat_bubble_rounded
                    : Icons.chat_bubble_outline_rounded,
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
          // Background Gradient — super cute pastel pink
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF0F5), // Lavender blush
                  Color(0xFFFFE4E1), // Misty rose
                  Color(0xFFFFD1DC), // Pastel pink
                  Color(0xFFFFC0CB), // Pink
                  Color(0xFFFFB6C1), // Light pink
                ],
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),

          // Lớp họa tiết dễ thương — emoji tim & hoa rải toàn màn hình
          Positioned.fill(
            child: RepaintBoundary(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CuteBgPatternPainter(),
                ),
              ),
            ),
          ),

          // Orb trên cùng bên phải — hồng sáng
          Positioned(
            top: -40,
            right: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF80BB).withValues(alpha: 0.30),
                    const Color(0xFFFF80BB).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Orb giữa trái — tím mộng mơ
          Positioned(
            top: 220,
            left: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFBF55EC).withValues(alpha: 0.22),
                    const Color(0xFFBF55EC).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Orb dưới phải — đào nhạt
          Positioned(
            bottom: 100,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFA0C0).withValues(alpha: 0.25),
                    const Color(0xFFFFA0C0).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Orb nhỏ trên trái — vàng ánh nhẹ
          Positioned(
            top: 80,
            left: 20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD580).withValues(alpha: 0.18),
                    const Color(0xFFFFD580).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Isolated tap hearts particle overlay
          TapHeartsOverlay(
            key: _heartsOverlayKey,
            style: _activeStyle,
          ),

          // 4. Floating message bubbles
          for (final msg in _floatingMessages)
            FloatingMessageWidget(key: msg.id, message: msg),

          for (int i = 0; i < latestPhotos.length; i++)
            PersistentFloatingPhotoWidget(
                key: ValueKey(latestPhotos[i]['id']?.toString() ??
                    latestPhotos[i]['timestamp'].toString()),
                url: latestPhotos[i]['imageUrl'].toString(),
                index: i),

          if (!_isMerged)
            Align(
              alignment: const Alignment(0, -0.70),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      _onTapDown(event.position);
                    },
                    onPointerMove: (event) {
                      _lastTapPosition = event.position;
                      final lastPos = _lastSpawnedPosition;
                      if (lastPos == null ||
                          (event.position - lastPos).distance > 18.0) {
                        _lastSpawnedPosition = event.position;
                        _heartsOverlayKey.currentState
                            ?.spawnExplosion(event.position, count: 3);
                      }
                    },
                    onPointerUp: (event) {
                      _onTapUp();
                    },
                    onPointerCancel: (event) {
                      _onTapCancel();
                    },
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _interactiveScaleNotifier,
                        builder: (context, scale, child) {
                          return AnimatedScale(
                            scale: scale,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeOut,
                            child: child,
                          );
                        },
                        child: ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            width: 160,
                            height: 160,
                            color: Colors.transparent,
                            child: RepaintBoundary(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Vòng neon thở bên ngoài (Breathing neon ring)
                                  AnimatedBuilder(
                                    animation: _pulseAnim,
                                    builder: (context, _) {
                                      final scale = _pulseAnim
                                          .value; // dao động từ 1.0 -> 1.15
                                      // Chuyển đổi thành tỉ lệ từ 0.0 -> 1.0 để làm mờ dần khi mở rộng
                                      final normalized = (scale - 1.0) / 0.15;
                                      return Container(
                                        width: 120 * scale,
                                        height: 120 * scale,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFFF9A9E)
                                                  .withValues(
                                                alpha:
                                                    (0.8 * (1.0 - normalized))
                                                        .clamp(0.0, 1.0),
                                              ),
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFFF9A9E)
                                                    .withValues(
                                                  alpha:
                                                      (0.3 * (1.0 - normalized))
                                                          .clamp(0.0, 1.0),
                                                ),
                                                blurRadius: 16,
                                                spreadRadius: 4,
                                              )
                                            ]),
                                      );
                                    },
                                  ),
                                  // Bong bóng xà phòng trung tâm (Soap bubble glass core)
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                          alpha: 0.35), // Frosted white
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        width: 2.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFFB6C1)
                                              .withValues(
                                                  alpha: 0.5), // Soft pink glow
                                          blurRadius: 20,
                                          spreadRadius: 4,
                                        ),
                                        // Highlight shadow for bubble effect
                                        BoxShadow(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          blurRadius: 10,
                                          spreadRadius: -2,
                                          offset: const Offset(-2, -2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(55),
                                        child: Lottie.asset(
                                          'assets/images/soul_merge_sticker.json',
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.contain,
                                          options: LottieOptions(
                                              enableMergePaths: true),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Sparkle dots
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
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        SizedBox(height: 24),
                        // Connection status line removed as per user request
                        // Nudge button removed, integrated into cat tap
                        // Removed toggle card from bottom as it is now in the AppBar
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 1. Particle explosions (behind photos)
            for (final explosion in _activeParticleExplosions)
              ParticleExplosionWidget(
                  key: explosion.id, position: explosion.position),

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
                            color:
                                const Color(0xFFFF4F93).withValues(alpha: 0.5),
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
            left: 4,
            right: 4,
            child: _buildChatInputBar(),
          ),
        ],
      ),
    );
  }

  void _listenInteractiveEvents() {
    _interactiveEventsSub?.cancel();
    _interactiveEventsSub =
        _mergeService.watchInteractiveEvents().listen((event) {
      if (!mounted) return;
      if (event.isEmpty) return;
      final sender = event['sender']?.toString();
      if (sender == _myRole) return; // ignore my own

      final type = event['type']?.toString();
      if (type == 'photo_shot') {
        final url = event['url']?.toString() ?? '';
        final x = (event['x'] as num?)?.toDouble() ?? 0.0;
        final y = (event['y'] as num?)?.toDouble() ?? 0.0;

        final pos = Offset(x > 0 ? x : MediaQuery.of(context).size.width / 2,
            y > 0 ? y : MediaQuery.of(context).size.height / 2);
        _heartsOverlayKey.currentState?.spawnExplosion(pos, count: 5);
        if (url.isNotEmpty) {
          _spawnPhotoExplosion(
            specificItem: {
              'url': url,
              'type': 'photo',
              'mood': '💖',
              'text': '',
              'dateStr': ''
            },
            specificPosition: Offset(pos.dx, pos.dy - 100),
          );
        }
      } else if (type == 'persistent_photo') {
        final url = event['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          setState(() {
            _persistentPhotos.add(url);
            if (_persistentPhotos.length > 3) {
              _persistentPhotos.removeAt(0);
            }
          });
        }
      }
    });
  }

  void _listenSoulMessages() {
    _messagesSub = _mergeService.watchSoulMessages().listen((list) {
      if (!mounted) return;

      if (list.isNotEmpty) {
        int highestT = 0;
        for (final msg in list) {
          final t = msg['timestamp'] as int? ?? 0;
          if (t > highestT) highestT = t;
        }
        if (highestT != _lastAnyMsgTimestamp) {
          setState(() => _lastAnyMsgTimestamp = highestT);
        }
      }

      final isFirstLoad = !_hasProcessedFirstMessages;
      int maxTimestamp = _lastMsgTimestamp;

      if (isFirstLoad && list.isNotEmpty) {
        _hasProcessedFirstMessages = true;
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
              if (!isSelf) {
                _spawnFloatingMessage(text, false);

                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android) {
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
      }

      setState(() {
        _chatHistory = list;
        _lastMsgTimestamp = maxTimestamp;
        _lastSeenMsgTimestamp = maxTimestamp;
      });

      unawaited(_mergeService.updateLastSeenTimestamp(maxTimestamp));
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
          _chatScrollController
              .jumpTo(_chatScrollController.position.maxScrollExtent);
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
        _spamWarning =
            'Thao tác quá nhanh! Bị chặn trong $remainingMin phút nữa.';
      });
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _spamWarning = null);
      });
      return true;
    }

    // 2. Check 5s countdown
    if (_tempBlockSecondsLeft > 0) {
      setState(() {
        _spamWarning =
            'Thao tác quá nhanh! Vui lòng đợi $_tempBlockSecondsLeft giây đếm ngược.';
      });
      return true;
    }

    // 3. Check messages rate (3 messages within 2 seconds)
    _msgTimestamps.removeWhere((t) => now - t > 2000);
    if (_msgTimestamps.length >= 3) {
      _tempBlockSecondsLeft = 5;
      _tempBlockTimer?.cancel();

      setState(() {
        _spamWarning =
            'Thao tác quá nhanh! Đang đếm ngược $_tempBlockSecondsLeft giây.';
      });

      _tempBlockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _tempBlockSecondsLeft--;
            if (_tempBlockSecondsLeft <= 0) {
              _spamWarning = null;
              timer.cancel();
            } else {
              _spamWarning =
                  'Thao tác quá nhanh! Đang đếm ngược $_tempBlockSecondsLeft giây.';
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

  Future<void> _sendSoulMessage(String text,
      {bool bypassSpamCheck = false}) async {
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

  Future<void> _sendStickerMessage(String assetPath) async {
    if (await _checkSpamAndMaybeBlock()) return;
    await _mergeService.sendSoulMessage('', imageUrl: assetPath);

    if (_houseId != null && _houseId!.isNotEmpty) {
      unawaited(
        NotificationService().sendPartnerNotification(
          houseId: _houseId!,
          title: '💬 $_myName vừa gửi nhãn dán',
          body: 'Đã gửi một nhãn dán',
          data: const {'screen': 'soul_merge', 'type': 'soul_merge'},
        ),
      );
    }
  }

  void _showStickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 35 - 7, // 35 minus 7 deleted stickers
                  itemBuilder: (context, index) {
                    final validStickers = [
                      for (int i = 1; i <= 35; i++)
                        if (![4, 5, 10, 11, 19, 26, 29].contains(i)) i
                    ];
                    final stickerPath =
                        'assets/images/anhtomau_stickers/sticker_${validStickers[index]}.gif';
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _sendStickerMessage(stickerPath);
                      },
                      child: Image.asset(stickerPath),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendCustomMessage() {
    final text = _customMsgController.text.trim();
    if (text.isEmpty) return;

    if (text.startsWith('/')) {
      String code = '';
      if (text.toLowerCase().startsWith('/code ')) {
        code = text.substring(6).trim();
      } else if (text.toLowerCase().startsWith('/giftcode ')) {
        code = text.substring(10).trim();
      } else {
        code = text.substring(1).trim();
      }

      final RegExp giftcodeRegex = RegExp(r'^[a-zA-Z0-9_-]{3,32}$');
      if (giftcodeRegex.hasMatch(code)) {
        _customMsgController.clear();
        FocusScope.of(context).unfocus();
        unawaited(() async {
          try {
            final result = await GiftcodeService().redeemGiftcode(
              houseId: _houseId ?? '',
              code: code,
            );
            if (!mounted) return;

            String displayMessage = result.message;
            if (result.success) {
              final days = result.daysAdded ?? 0;
              if (days > 0) {
                displayMessage =
                    '🎉 Chúc mừng! Bạn đã nhận thành công $days ngày VIP PRO.';
              } else {
                displayMessage =
                    '🎉 Chúc mừng! Bạn đã kích hoạt mã quà tặng thành công.';
              }
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(displayMessage),
                backgroundColor: result.success ? Colors.green : Colors.red,
              ),
            );
          } catch (e) {
            debugPrint('Error redeeming giftcode in soul merge chat: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Có lỗi xảy ra khi kích hoạt Giftcode.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }());
        return;
      }
    }

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
    final addressWord = _myRole == 'user1' ? 'em' : 'anh';
    final addressWordTitle = _myRole == 'user1' ? 'Em' : 'Anh';
    final presetsBefore = [
      '$addressWordTitle đang làm gì đó? 🤔',
      'Hello $addressWord 👋',
      'Nhớ $_partnerName quá đi nhé 💕',
    ];
    final presetsAfter = ['Yêu bạn 😘', 'Nhớ quá! 💖', 'Ú òa! 👻'];

    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLastMsg = _lastAnyMsgTimestamp == 0
        ? 999
        : (now - _lastAnyMsgTimestamp) / (1000 * 60 * 60);
    final showPresetsBefore = hoursSinceLastMsg >= 24;

    final presets = _isMerged
        ? presetsAfter
        : (showPresetsBefore ? presetsBefore : <String>[]);

    return Padding(
      padding: EdgeInsets.zero,
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
            constraints: const BoxConstraints(maxHeight: 500),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
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
                  : RepaintBoundary(
                      child: ListView.builder(
                        controller: _chatScrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _chatHistory.length,
                        itemBuilder: (context, index) {
                          final msg = _chatHistory.reversed.elementAt(index);
                          final sender = (msg['sender'] ?? '').toString();
                          final isSelf = (sender == _myRole);
                          final text = (msg['text'] ?? '').toString();
                          final imageUrl = (msg['imageUrl'] ?? '').toString();
                          final timeStr = _formatTime(msg['timestamp'] as int?);
                          final isSticker = imageUrl
                              .startsWith('assets/images/anhtomau_stickers/');

                          return Align(
                            alignment: isSelf
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: EdgeInsets.only(
                                top: 2,
                                bottom: 2,
                                left: isSelf ? 48 : 0,
                                right: isSelf ? 0 : 48,
                              ),
                              padding: isSticker
                                  ? EdgeInsets.zero
                                  : (imageUrl.isNotEmpty
                                      ? const EdgeInsets.all(6)
                                      : const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 11)),
                              decoration: isSticker
                                  ? null
                                  : BoxDecoration(
                                      gradient: isSelf
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFFF9A9E),
                                                Color(0xFFFECFEF)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isSelf
                                          ? null
                                          : Colors.white
                                              .withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(24),
                                        topRight: const Radius.circular(24),
                                        bottomLeft:
                                            Radius.circular(isSelf ? 24 : 6),
                                        bottomRight:
                                            Radius.circular(isSelf ? 6 : 24),
                                      ),
                                      border: Border.all(
                                        color: isSelf
                                            ? Colors.white
                                                .withValues(alpha: 0.6)
                                            : Colors.white
                                                .withValues(alpha: 0.9),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelf
                                              ? const Color(0xFFFF9A9E)
                                                  .withValues(alpha: 0.4)
                                              : Colors.black
                                                  .withValues(alpha: 0.06),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                              child: Column(
                                crossAxisAlignment: isSelf
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (imageUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          isSticker ? 0 : 14),
                                      child: imageUrl.startsWith('assets/')
                                          ? Image.asset(imageUrl,
                                              fit: BoxFit.contain,
                                              width: isSticker ? 160 : 200)
                                          : CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              width: 200,
                                              placeholder: (context, url) =>
                                                  Container(
                                                width: 200,
                                                height: 150,
                                                color: Colors.white12,
                                                child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            color:
                                                                Colors.white54,
                                                            strokeWidth: 2)),
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
                                                width: 200,
                                                height: 150,
                                                color: Colors.white12,
                                                child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.white54),
                                              ),
                                            ),
                                    ),
                                  if (text.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: imageUrl.isNotEmpty ? 6 : 0,
                                          left: imageUrl.isNotEmpty ? 4 : 0,
                                          right: imageUrl.isNotEmpty ? 4 : 0,
                                          bottom: 2),
                                      child: Text(
                                        text,
                                        style: SLTheme.quicksand(
                                          color: isSelf
                                              ? Colors.white
                                              : const Color(0xFF6B5B6D),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                        ).copyWith(
                                          shadows: isSelf
                                              ? const [
                                                  Shadow(
                                                    color: Colors.black26,
                                                    blurRadius: 2,
                                                    offset: Offset(0, 1),
                                                  )
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  if (timeStr.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          left: imageUrl.isNotEmpty ? 4 : 0,
                                          right: imageUrl.isNotEmpty ? 4 : 0,
                                          top: 2,
                                          bottom: imageUrl.isNotEmpty ? 4 : 0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            timeStr,
                                            style: SLTheme.quicksand(
                                              color: isSelf
                                                  ? Colors.white
                                                      .withValues(alpha: 0.8)
                                                  : const Color(0xFF9E8B9F),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (isSelf) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.check_circle,
                                                size: 10,
                                                color: Colors.white
                                                    .withValues(alpha: 0.8)),
                                          ],
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
          if (presets.isNotEmpty)
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF758F).withValues(alpha: 0.25),
                              const Color(0xFFFF4F93).withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                const Color(0xFFFF758F).withValues(alpha: 0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4F93)
                                  .withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB6C1).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAndSendChatImage,
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    child: _isUploadingPhoto
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFFF9A9E)))
                        : const Icon(Icons.add_photo_alternate_rounded,
                            color: Color(0xFF6B5B6D), size: 22),
                  ),
                ),
                GestureDetector(
                  onTap: _showStickerBottomSheet,
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    child: const Icon(Icons.emoji_emotions_rounded,
                        color: Color(0xFF6B5B6D), size: 22),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _customMsgController,
                      style: SLTheme.quicksand(
                        color: const Color(0xFF5A4A5E),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn tâm hồn...',
                        hintStyle: SLTheme.quicksand(
                          color: const Color(0xFF9E8B9F),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9A9E).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
    );
  }

  void _sendOverlaySyncPayload() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    FlutterOverlayWindow.isActive().then((active) {
      if (active) {
        final credentialsPayload = jsonEncode({
          'type': 'sync_credentials',
          'houseId': _houseId ?? '',
          'role': _myRole,
          'partnerName': _partnerName,
        });
        FlutterOverlayWindow.shareData(credentialsPayload);

        final chatPayload = jsonEncode({
          'type': 'update_chat',
          'history': _chatHistory,
          'myRole': _myRole,
          'partnerName': _partnerName,
        });
        FlutterOverlayWindow.shareData(chatPayload);
      }

      try {
        final payloadText = jsonEncode({
          'houseId': _houseId ?? '',
          'role': _myRole,
          'partnerName': _partnerName,
        });
        getApplicationDocumentsDirectory().then((dir) {
          final file = File('${dir.path}/overlay_sync.json');
          file.writeAsString(payloadText);
        });
      } catch (e) {
        debugPrint('[SoulMergeScreen] File IO save error: $e');
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      isScrollControlled: true,
      builder: (context) {
        int activeTab = 0; // 0: Hiệu ứng, 1: Cấu hình
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
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: 20 + MediaQuery.of(context).padding.bottom,
              ),
              child: SingleChildScrollView(
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
                      L10nService().translate('heart_style_title'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      L10nService().translate('heart_style_desc'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab selector dạng Pill
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {
                                  activeTab = 0;
                                });
                              },
                              borderRadius: BorderRadius.circular(17),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: activeTab == 0
                                      ? const Color(0xFFFF4F93)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Text(
                                  L10nService()
                                      .translate('heart_style_tab_effect'),
                                  style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {
                                  activeTab = 1;
                                });
                              },
                              borderRadius: BorderRadius.circular(17),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: activeTab == 1
                                      ? const Color(0xFFFF4F93)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Text(
                                  L10nService()
                                      .translate('heart_style_tab_config'),
                                  style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nội dung từng Tab
                    if (activeTab == 0) ...[
                      _buildStyleItem(
                        title:
                            L10nService().translate('heart_style_basic_title'),
                        desc: L10nService().translate('heart_style_basic_desc'),
                        styleKey: 'basic',
                        isPremium: false,
                        color: const Color(0xFFFFB7D5),
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 12),
                      _buildStyleItem(
                        title:
                            L10nService().translate('heart_style_aurora_title'),
                        desc:
                            L10nService().translate('heart_style_aurora_desc'),
                        styleKey: 'aurora',
                        isPremium: false,
                        color: const Color(0xFF00FFCC),
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 12),
                      _buildStyleItem(
                        title:
                            L10nService().translate('heart_style_cosmic_title'),
                        desc:
                            L10nService().translate('heart_style_cosmic_desc'),
                        styleKey: 'cosmic',
                        isPremium: false,
                        color: const Color(0xFFFFD700),
                        setSheetState: setSheetState,
                      ),
                    ] else ...[
                      _buildToggleRow(
                        title: L10nService()
                            .translate('heart_style_show_cat_dialog'),
                        subtitle: L10nService()
                            .translate('heart_style_show_cat_dialog_desc'),
                        value: _showHeartNotif,
                        onChanged: (val) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(
                              'soul_merge_show_heart_notif', val);
                          setSheetState(() {
                            _showHeartNotif = val;
                          });
                          setState(() {
                            _showHeartNotif = val;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
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

    return InkWell(
      onTap: () {
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
                      Flexible(
                        child: Text(
                          title,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPremium && !_isVip) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: SLTheme.quicksand(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFFF7FB2),
            activeTrackColor: const Color(0xFFFF7FB2).withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
