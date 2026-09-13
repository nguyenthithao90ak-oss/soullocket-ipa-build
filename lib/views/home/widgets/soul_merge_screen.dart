import 'dart:async';
import 'dart:math' as math;
import 'package:soullocket_app/widgets/soul_merge_mascot.dart';
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
import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:soullocket_app/views/relationship/video_call_screen.dart';
import 'soul_merge/soul_merge_chat_bar.dart';
import 'soul_merge/sticker_bottom_sheet.dart';

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

class _SoulMergeScreenState extends State<SoulMergeScreen> {
  late BumpDetector _bumpDetector;
  final SoulMergeService _mergeService = SoulMergeService();
  StreamSubscription<Map<String, int>>? _mergeTimesSub;

  bool _isMerged = false;

  // Memory photos lists and timers
  List<Map<String, String>> _memoriesData = [];
  final List<ExplodingPhoto> _activePhotos = [];
  final List<({Offset position, UniqueKey id})> _activeParticleExplosions = [];
  Timer? _explosionTimer;
  final math.Random _random = math.Random();

  String? _houseId;
  String _partnerName = '…';
  String _myName = '…';
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
      _sharedOverlayStream ??= FlutterOverlayWindow.overlayListener
          .asBroadcastStream();
      _overlayListenerSub = _sharedOverlayStream!.listen((event) {
        if (event == 'launch_app') {
          const MethodChannel(
            'soul_locket/app_control',
          ).invokeMethod('bringToForeground');
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
        final myRole = p.getString('il_role')?.trim() == 'user2'
            ? 'user2'
            : 'user1';
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
    _heartsOverlayKey.currentState?.spawnFlyingToExplosion(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width / 2, size.height * 0.15),
      count: 8,
    );

    await NotificationService().sendPartnerNotification(
      houseId: _houseId!,
      title: L10nService().format('p4_soul_nudge_notification_title', {
        'name': _myName,
      }),
      body: L10nService().format('p4_soul_nudge_notification_body', {
        'name': _myName,
      }),
      data: const {'screen': 'soul_merge', 'type': 'soul_merge'},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10nService().format('p4_soul_nudge_sent', {'name': _partnerName}),
            style: SLTheme.quicksand(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFFF4F93),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
                ? L10nService().format('p4_soul_photo_limit_pro', {
                    'count': maxPhotos,
                  })
                : L10nService().format('p4_soul_photo_limit_free', {
                    'count': maxPhotos,
                  }),
          );
        }
        return;
      }

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
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
    final size = MediaQuery.sizeOf(context);
    _heartsOverlayKey.currentState?.spawnFlyingToExplosion(
      globalPosition,
      Offset(size.width / 2, size.height * 0.15),
    );
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
          specificPosition: Offset(globalPosition.dx, globalPosition.dy - 100),
        );
      }
    }

    // Continuous heart spawning & haptic feedback timer - optimized for performance
    _continuousHeartsTimer?.cancel();
    int tickCount = 0;
    _continuousHeartsTimer = Timer.periodic(const Duration(milliseconds: 90), (
      timer,
    ) {
      if (!mounted || _isMerged) {
        timer.cancel();
        return;
      }
      _heartsOverlayKey.currentState?.spawnFlyingToExplosion(
        _lastTapPosition,
        Offset(
          MediaQuery.sizeOf(context).width / 2,
          MediaQuery.sizeOf(context).height * 0.15,
        ),
        count: 5,
      );
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
  }

  void _onTapCancel() {
    _continuousHeartsTimer?.cancel();
    _continuousHeartsTimer = null;
    _interactiveScaleNotifier.value = 1.0;
  }

  // ignore: unused_element
  String _getConnectionStatusText() {
    if (!_iHaveBumped && !_partnerHasBumped) {
      return context.tr('p4_soul_status_waiting');
    } else if (_iHaveBumped && !_partnerHasBumped) {
      return L10nService().format('p4_soul_status_waiting_partner', {
        'name': _partnerName,
      });
    } else if (!_iHaveBumped && _partnerHasBumped) {
      return L10nService().format('p4_soul_status_partner_ready', {
        'name': _partnerName,
      });
    } else {
      return context.tr('p4_soul_status_connecting');
    }
  }

  // ignore: unused_element
  Color _getConnectionStatusColor() {
    if (_iHaveBumped || _partnerHasBumped) {
      return const Color(0xFFFF7FB2);
    }
    return Colors.white70;
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
          'text': L10nService().translate('p4_soul_memory_fallback_one'),
          'type': 'text',
          'mood': '💖',
          'dateStr': '',
        });
        items.add({
          'url': '',
          'text': L10nService().translate('p4_soul_memory_fallback_two'),
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

  void _spawnPhotoExplosion({
    Map<String, String>? specificItem,
    Offset? specificPosition,
  }) {
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
          _activeParticleExplosions.removeWhere(
            (item) => item.id == particleId,
          );
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
    _explosionTimer?.cancel();
    _tempBlockTimer?.cancel();
    unawaited(_mergeService.clearBumps());
    unawaited(_mergeService.clearChat());
    super.dispose();
  }

  /// Bắt đầu cuộc gọi thoại/video với người yêu
  void _startCoupleCall({required bool isVideo}) {
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) {
      SLNotice.showError(context, context.tr('p4_soul_house_missing'));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          houseId: houseId,
          targetHouseId: houseId, // Cùng house
          targetName: _partnerName,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompactHeader = MediaQuery.sizeOf(context).width < 420;
    final photoMessages = _chatHistory.where((m) {
      final url = (m['imageUrl']?.toString() ?? '').trim();
      return url.startsWith('http://') || url.startsWith('https://');
    }).toList();
    final latestPhotos = photoMessages.length > 3
        ? photoMessages.sublist(photoMessages.length - 3)
        : photoMessages;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Bề mặt yên tĩnh để hội thoại và sticker là điểm nhấn chính.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFCFD),
                  Color(0xFFFFF2F5),
                  Color(0xFFFFEAF0),
                ],
                stops: [0.0, 0.54, 1.0],
              ),
            ),
          ),

          // Hai lớp sáng mờ tạo chiều sâu mà không làm rối vùng chat.
          Positioned(
            top: -90,
            right: -76,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF8FB3).withValues(alpha: 0.18),
                    const Color(0xFFFF8FB3).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 58,
            left: -104,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFCBB9E9).withValues(alpha: 0.14),
                    const Color(0xFFCBB9E9).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          // Isolated tap hearts particle overlay
          TapHeartsOverlay(key: _heartsOverlayKey, style: _activeStyle),

          // 4. Floating message bubbles
          for (final msg in _floatingMessages)
            FloatingMessageWidget(key: msg.id, message: msg),

          for (int i = 0; i < latestPhotos.length; i++)
            PersistentFloatingPhotoWidget(
              key: ValueKey(
                latestPhotos[i]['id']?.toString() ??
                    latestPhotos[i]['timestamp'].toString(),
              ),
              url: latestPhotos[i]['imageUrl'].toString(),
              index: i,
            ),

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
                        _heartsOverlayKey.currentState?.spawnFlyingToExplosion(
                          event.position,
                          Offset(
                            MediaQuery.sizeOf(context).width / 2,
                            MediaQuery.sizeOf(context).height * 0.15,
                          ),
                          count: 2,
                        );
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
                        child: const SizedBox.square(
                          dimension: 160,
                          child: Center(
                            child: SoulMergeMascot(size: 146, framed: true),
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
                key: explosion.id,
                position: explosion.position,
              ),

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
                      context.tr('p4_soul_connected_title'),
                      style: SLTheme.quicksand(
                        color: const Color(0xFFFF4F93),
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: const Color(
                              0xFFFF4F93,
                            ).withValues(alpha: 0.5),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('p4_soul_connected_subtitle'),
                      style: SLTheme.quicksand(
                        color: const Color(0xFF7E365B),
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
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _buildChatInputBar(),
              ),
            ),
          ),

          // ═══════════════════════════════════════════
          // HEADER — Z-INDEX CAO NHẤT ĐỂ BẤM ĐƯỢC
          // ═══════════════════════════════════════════
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white.withValues(alpha: 0.20),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF875364,
                            ).withValues(alpha: 0.09),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            // ← Nút quay lại
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.pink.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: Colors.pink.shade700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Cùng hình đôi với lối vào Home và điểm chạm chính.
                            if (!isCompactHeader) ...[
                              const SoulMergeMascot(size: 42, framed: true),
                              const SizedBox(width: 10),
                            ],

                            // Tên
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.tr('p4_soul_title'),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.pink.shade800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.favorite_rounded,
                                        size: 10,
                                        color: Color(0xFFE985A2),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          _partnerName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.pink.shade500,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ═══ NÚT GỌI THOẠI ═══
                            _SoulMergeCallButton(
                              icon: Icons.phone_rounded,
                              gradientColors: const [
                                Color(0xFF58CFA2),
                                Color(0xFF49BA9B),
                              ],
                              glowColor: const Color(0xFF58CFA2),
                              onTap: () => _startCoupleCall(isVideo: false),
                              tooltip: context.tr('p4_soul_voice_call'),
                            ),
                            const SizedBox(width: 8),

                            // ═══ NÚT GỌI VIDEO ═══
                            _SoulMergeCallButton(
                              icon: Icons.videocam_rounded,
                              gradientColors: const [
                                Color(0xFF9A7DE1),
                                Color(0xFF8068C8),
                              ],
                              glowColor: const Color(0xFF9A7DE1),
                              onTap: () => _startCoupleCall(isVideo: true),
                              tooltip: context.tr('p4_soul_video_call'),
                            ),
                            const SizedBox(width: 8),

                            // ═══ NÚT HIỆU ỨNG ═══
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showHeartStyleSheet,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFF6B9D,
                                        ).withValues(alpha: 0.2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: Color(0xFFFF6B9D),
                                  ),
                                ),
                              ),
                            ),

                            // ═══ BONG BÓNG NỔI (Android only) ═══
                            if (!isCompactHeader &&
                                !kIsWeb &&
                                defaultTargetPlatform ==
                                    TargetPlatform.android) ...[
                              const SizedBox(width: 6),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _toggleOverlaySetting,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (_overlayEnabled
                                                      ? const Color(0xFFFF4F93)
                                                      : Colors.pink)
                                                  .withValues(alpha: 0.2),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _overlayEnabled
                                          ? Icons.chat_bubble_rounded
                                          : Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                      color: _overlayEnabled
                                          ? const Color(0xFFFF4F93)
                                          : Colors.pink.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _listenInteractiveEvents() {
    _interactiveEventsSub?.cancel();
    _interactiveEventsSub = _mergeService.watchInteractiveEvents().listen((
      event,
    ) {
      if (!mounted) return;
      if (event.isEmpty) return;
      final sender = event['sender']?.toString();
      if (sender == _myRole) return; // ignore my own

      final type = event['type']?.toString();
      if (type == 'photo_shot') {
        final url = event['url']?.toString() ?? '';
        final x = (event['x'] as num?)?.toDouble() ?? 0.0;
        final y = (event['y'] as num?)?.toDouble() ?? 0.0;

        final pos = Offset(
          x > 0 ? x : MediaQuery.of(context).size.width / 2,
          y > 0 ? y : MediaQuery.of(context).size.height / 2,
        );
        _heartsOverlayKey.currentState?.spawnFlyingToExplosion(
          pos,
          Offset(
            MediaQuery.sizeOf(context).width / 2,
            MediaQuery.sizeOf(context).height * 0.15,
          ),
          count: 5,
        );
        if (url.isNotEmpty) {
          _spawnPhotoExplosion(
            specificItem: {
              'url': url,
              'type': 'photo',
              'mood': '💖',
              'text': '',
              'dateStr': '',
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

      final oldSeenMs = _lastSeenMsgTimestamp;
      setState(() {
        _chatHistory = list;
        _lastMsgTimestamp = maxTimestamp;
        _lastSeenMsgTimestamp = maxTimestamp;
      });

      if (maxTimestamp > oldSeenMs) {
        unawaited(_mergeService.updateLastSeenTimestamp(maxTimestamp));
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('soul_merge_last_seen_msg_ts', maxTimestamp);
        });
      }

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

      _scrollChatToBottom();
    });
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_chatScrollController.hasClients) {
        if (_chatScrollController.offset != 0) {
          _chatScrollController.jumpTo(0);
        }
      }
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
        _spamWarning = L10nService().format('p4_soul_spam_minutes', {
          'count': remainingMin,
        });
      });
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _spamWarning = null);
      });
      return true;
    }

    // 2. Check 5s countdown
    if (_tempBlockSecondsLeft > 0) {
      setState(() {
        _spamWarning = L10nService().format('p4_soul_spam_seconds', {
          'count': _tempBlockSecondsLeft,
        });
      });
      return true;
    }

    // 3. Check messages rate (3 messages within 2 seconds)
    _msgTimestamps.removeWhere((t) => now - t > 2000);
    if (_msgTimestamps.length >= 3) {
      _tempBlockSecondsLeft = 5;
      _tempBlockTimer?.cancel();

      setState(() {
        _spamWarning = L10nService().format('p4_soul_spam_seconds', {
          'count': _tempBlockSecondsLeft,
        });
      });

      _tempBlockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _tempBlockSecondsLeft--;
            if (_tempBlockSecondsLeft <= 0) {
              _spamWarning = null;
              timer.cancel();
            } else {
              _spamWarning = L10nService().format('p4_soul_spam_seconds', {
                'count': _tempBlockSecondsLeft,
              });
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
          _spamWarning = L10nService().translate('p4_soul_spam_hour');
          _tempBlockSecondsLeft = 0;
          _tempBlockTimer?.cancel();
        });
      }

      return true;
    }

    _msgTimestamps.add(now);
    return false;
  }

  Future<void> _sendSoulMessage(
    String text, {
    bool bypassSpamCheck = false,
  }) async {
    if (!bypassSpamCheck && await _checkSpamAndMaybeBlock()) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _mergeService.sendSoulMessage(trimmed);

    // Send push notification to partner's main home screen
    if (_houseId != null && _houseId!.isNotEmpty) {
      unawaited(
        NotificationService().sendPartnerNotification(
          houseId: _houseId!,
          title: L10nService().format('p4_soul_message_notification_title', {
            'name': _myName,
          }),
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
          title: L10nService().format('p4_soul_sticker_notification_title', {
            'name': _myName,
          }),
          body: L10nService().translate('p4_soul_sticker_notification_body'),
          data: const {'screen': 'soul_merge', 'type': 'soul_merge'},
        ),
      );
    }
  }

  void _showStickerBottomSheet() {
    StickerBottomSheet.show(
      context: context,
      onStickerSelected: _sendStickerMessage,
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
                displayMessage = L10nService().format('p4_soul_giftcode_days', {
                  'days': days,
                });
              } else {
                displayMessage = L10nService().translate(
                  'p4_soul_giftcode_success',
                );
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
                SnackBar(
                  content: Text(context.tr('p4_soul_giftcode_error')),
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
    return SoulMergeChatBar(
      chatHistory: _chatHistory,
      myRole: _myRole,
      partnerName: _partnerName,
      spamWarning: _spamWarning,
      textController: _customMsgController,
      scrollController: _chatScrollController,
      isUploadingPhoto: _isUploadingPhoto,
      lastAnyMsgTimestamp: _lastAnyMsgTimestamp,
      isMerged: _isMerged,
      onSendCustomMessage: _sendCustomMessage,
      onPickImage: _pickAndSendChatImage,
      onShowSticker: _showStickerBottomSheet,
      onSendPreset: (message) => unawaited(_sendSoulMessage(message)),
      formatTime: _formatTime,
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
                  context.tr('p4_soul_overlay_permission'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
        overlayTitle: L10nService().translate('p4_soul_overlay_title'),
        overlayContent: L10nService().translate('p4_soul_overlay_content'),
      );

      if (mounted) {
        setState(() {
          _overlayEnabled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('p4_soul_overlay_enabled'),
              style: SLTheme.quicksand(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFFF4F93),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
              context.tr('p4_soul_overlay_disabled'),
              style: SLTheme.quicksand(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
                                  L10nService().translate(
                                    'heart_style_tab_effect',
                                  ),
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
                                  L10nService().translate(
                                    'heart_style_tab_config',
                                  ),
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
                        title: L10nService().translate(
                          'heart_style_basic_title',
                        ),
                        desc: L10nService().translate('heart_style_basic_desc'),
                        styleKey: 'basic',
                        isPremium: false,
                        color: const Color(0xFFFFB7D5),
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 12),
                      _buildStyleItem(
                        title: L10nService().translate(
                          'heart_style_aurora_title',
                        ),
                        desc: L10nService().translate(
                          'heart_style_aurora_desc',
                        ),
                        styleKey: 'aurora',
                        isPremium: false,
                        color: const Color(0xFF00FFCC),
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 12),
                      _buildStyleItem(
                        title: L10nService().translate(
                          'heart_style_cosmic_title',
                        ),
                        desc: L10nService().translate(
                          'heart_style_cosmic_desc',
                        ),
                        styleKey: 'cosmic',
                        isPremium: false,
                        color: const Color(0xFFFFD700),
                        setSheetState: setSheetState,
                      ),
                    ] else ...[
                      _buildToggleRow(
                        title: L10nService().translate(
                          'heart_style_show_cat_dialog',
                        ),
                        subtitle: L10nService().translate(
                          'heart_style_show_cat_dialog_desc',
                        ),
                        value: _showHeartNotif,
                        onChanged: (val) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(
                            'soul_merge_show_heart_notif',
                            val,
                          );
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
                            horizontal: 6,
                            vertical: 2,
                          ),
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
              Icon(Icons.check_circle_rounded, color: color, size: 20),
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
                  style: SLTheme.quicksand(color: Colors.white54, fontSize: 11),
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

// ═══════════════════════════════════════════════════════
// CUSTOM HEADER WIDGETS
// ═══════════════════════════════════════════════════════

/// Nút gọi thoại/video với gradient, glow, và animation
class _SoulMergeCallButton extends StatefulWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final Color glowColor;
  final VoidCallback onTap;
  final String tooltip;

  const _SoulMergeCallButton({
    required this.icon,
    required this.gradientColors,
    required this.glowColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_SoulMergeCallButton> createState() => _SoulMergeCallButtonState();
}

class _SoulMergeCallButtonState extends State<_SoulMergeCallButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, child) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withValues(
                        alpha: _glowAnim.value,
                      ),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: widget.glowColor.withValues(
                        alpha: _glowAnim.value * 0.3,
                      ),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 20),
              );
            },
          ),
        ),
      ),
    );
  }
}
