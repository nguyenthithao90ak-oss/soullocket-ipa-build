import 'package:soullocket_app/widgets/sl_image_crop_file.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soullocket_app/utils/services/soul_message_history.dart';
import 'package:soullocket_app/utils/services/soul_message_actions.dart';
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
import 'package:soullocket_app/utils/screen_activity_mixin.dart';
import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:soullocket_app/views/relationship/video_call_screen.dart';
import 'package:soullocket_app/utils/services/webrtc_service.dart';
import 'soul_merge/soul_merge_chat_bar.dart';
import 'package:soullocket_app/utils/services/soul_message_delivery.dart';
import 'soul_merge/soul_merge_design.dart';
import 'soul_merge/soul_merge_background_editor.dart';
import 'soul_merge/soul_merge_interaction_strip.dart';
import 'soul_merge/soul_merge_touch_cascade.dart';
import 'soul_merge/soul_merge_options_sheet.dart';
import 'soul_merge/sticker_bottom_sheet.dart';

part 'soul_merge/exploding_photo_part.dart';
part 'soul_merge/particle_explosion_part.dart';
part 'soul_merge/tap_hearts_overlay_part.dart';
part 'soul_merge/floating_message_part.dart';
part 'soul_merge/persistent_floating_photo_part.dart';

Stream<dynamic>? _sharedOverlayStream;

class SoulMergeScreen extends StatefulWidget {
  const SoulMergeScreen({super.key});

  @override
  State<SoulMergeScreen> createState() => _SoulMergeScreenState();
}

class _SoulMergeScreenState extends State<SoulMergeScreen>
    with ScreenActivityMixin {
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
  final ValueNotifier<double> _interactiveScaleNotifier = ValueNotifier(1.0);
  int _heartPulse = 0;
  final GlobalKey<SoulMergeTouchCascadeState> _touchCascadeKey =
      GlobalKey<SoulMergeTouchCascadeState>();
  DateTime? _lastManualNudgeTime;

  final TextEditingController _customMsgController = TextEditingController();
  final FocusNode _soulComposerFocusNode = FocusNode();
  Map<String, dynamic>? _replyTarget;
  bool _isSendingMessage = false;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub;
  StreamSubscription<Map<String, dynamic>>? _interactiveEventsSub;
  StreamSubscription<Map<String, dynamic>>? _readReceiptsSub;
  final SoulMessageOutbox _messageOutbox = SoulMessageOutbox();
  Map<String, dynamic> _readReceipts = {};
  String? _lastMarkedReadId;
  final List<FloatingMessage> _floatingMessages = [];
  final List<String> _persistentPhotos = [];
  bool _isUploadingPhoto = false;
  int _lastMsgTimestamp = 0;
  int _lastSeenMsgTimestamp = 0;
  int _lastAnyMsgTimestamp = 0;
  bool _hasProcessedFirstMessages = false;
  String _myRole = 'user1';
  List<Map<String, dynamic>> _chatHistory = [];
  String _messageSearchQuery = '';
  bool _messageSearchOpen = false;
  final SoulMessageHistory _messageHistory = SoulMessageHistory();
  bool _isLoadingOlderMessages = false;
  bool _historyLoadFailed = false;
  bool _latestMessagesFailed = false;
  bool _hasLoadedMessages = false;
  StreamSubscription<Map<String, dynamic>>? _backgroundSub;
  String _backgroundUrl = '';
  StreamSubscription<Map<String, dynamic>>? _soulAvatarSub;
  StreamSubscription<List<Map<String, dynamic>>>? _pinnedMessagesSub;
  bool _realtimeBound = false;
  List<Map<String, dynamic>> _pinnedMessages = [];
  String _soulAvatarUrl = '';
  String? _screenOwnerUid;
  bool _isUploadingBackground = false;
  bool _isUploadingSoulAsset = false;
  bool _callRouteOpen = false;
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

  List<Map<String, dynamic>> get _filteredChatHistory {
    final query = _messageSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return _chatHistory;
    return _chatHistory
        .where((message) {
          final text = message['text']?.toString().toLowerCase() ?? '';
          final sender = message['sender']?.toString().toLowerCase() ?? '';
          return text.contains(query) || sender.contains(query);
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> get _pinnedDisplayMessages {
    return _pinnedMessages
        .map((pin) {
          final id = pin['id']?.toString();
          Map<String, dynamic>? message;
          for (final entry in _messageHistory.messages) {
            if (entry['id']?.toString() == id) {
              message = entry;
              break;
            }
          }
          return {...?message, ...pin, if (id case final value?) 'id': value};
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _screenOwnerUid = FirebaseAuth.instance.currentUser?.uid;
    _chatScrollController.addListener(_onChatScroll);
    _bumpDetector = BumpDetector(
      threshold: 3.5, // Sensitive enough for a gentle bump
      onBump: _handleLocalBump,
    );

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
      if (!mounted || !_scopeIsCurrent) return;
      if (isScreenActive) _bindRealtimeListeners();
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

    // mergeTimes được bind theo lifecycle màn hình trong _bindRealtimeListeners.
  }

  void _bindRealtimeListeners() {
    if (!mounted ||
        !isScreenActive ||
        _realtimeBound ||
        !_scopeIsCurrent ||
        _houseId == null ||
        _houseId!.isEmpty) {
      return;
    }
    _realtimeBound = true;
    _listenBackground();
    _listenSoulAvatar();
    _listenSoulMessages();
    _listenReadReceipts();
    _listenInteractiveEvents();
    _pinnedMessagesSub?.cancel();
    final houseId = _houseId;
    if (houseId != null && houseId.isNotEmpty) {
      _pinnedMessagesSub = _mergeService
          .watchSoulPinnedMessages(houseId: houseId)
          .listen((pinned) {
            if (!mounted ||
                !isScreenActive ||
                !_scopeIsCurrent ||
                _houseId != houseId) {
              return;
            }
            setState(() => _pinnedMessages = pinned);
          });
    }
    _mergeTimesSub?.cancel();
    _mergeTimesSub = _mergeService.watchMergeTimes().listen((mergeTimes) {
      if (!mounted || !isScreenActive || !_scopeIsCurrent) return;
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

        if (mounted && isScreenActive) {
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

  void _unbindRealtimeListeners() {
    _realtimeBound = false;
    _mergeTimesSub?.cancel();
    _mergeTimesSub = null;
    _messagesSub?.cancel();
    _messagesSub = null;
    _interactiveEventsSub?.cancel();
    _interactiveEventsSub = null;
    _readReceiptsSub?.cancel();
    _readReceiptsSub = null;
    _backgroundSub?.cancel();
    _backgroundSub = null;
    _soulAvatarSub?.cancel();
    _soulAvatarSub = null;
    _pinnedMessagesSub?.cancel();
    _pinnedMessagesSub = null;
  }

  void _handleLocalBump() {
    if (_isMerged) return;
    debugPrint('[SoulMergeScreen] _handleLocalBump triggered (bump or tap)');
    _mergeService.reportBump();
    HapticFeedback.mediumImpact();
    setState(() => _heartPulse++);
  }

  void _startTouchHolding() {
    _touchCascadeKey.currentState?.startHolding(connected: _isMerged);
  }

  Future<void> _initUserInfo() async {
    try {
      _houseId = await _mergeService.getCurrentHouseId();
      if (!mounted || !_scopeIsCurrent) return;
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
        if (!mounted || !_scopeIsCurrent) return;

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
        if (!mounted || !_scopeIsCurrent) return;
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

  void _sendManualNudgeNotification() async {
    if (_houseId == null || _houseId!.isEmpty) return;

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
        SLSnackBar(
          content: Text(
            L10nService().format('p4_soul_nudge_sent', {'name': _partnerName}),
          ),
          backgroundColor: const Color(0xFFFF4F93),
          behavior: SnackBarBehavior.floating,

          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickAndSendChatImage() async {
    if (_isUploadingPhoto || !_scopeIsCurrent) return;
    final initialHouseId = _houseId;
    final initialUid = _screenOwnerUid;
    final reply = _replyTarget;
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
      if (image == null ||
          !mounted ||
          !_scopeIsCurrent ||
          _houseId != initialHouseId) {
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final houseId = _houseId ?? '';
      final uploadResult = await StorageService.instance.uploadPublicImage(
        houseId,
        'soul_merge',
        XFile(image.path),
        quality: 50,
      );

      final url = uploadResult?.downloadUrl;
      if (url != null && url.isNotEmpty) {
        await _mergeService.sendSoulMessage(
          '',
          imageUrl: url,
          replyTo: reply?['id']?.toString(),
          expectedHouseId: initialHouseId,
          expectedUid: initialUid,
        );
        if (!mounted || !_scopeIsCurrent || _houseId != initialHouseId) return;
        if (identical(_replyTarget, reply)) setState(() => _replyTarget = null);
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
    _startTouchHolding();
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
  }

  void _onTapUp() {
    _interactiveScaleNotifier.value = 1.0;
    _touchCascadeKey.currentState?.releaseHolding();
  }

  void _onTapCancel() {
    _onTapUp();
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
    _touchCascadeKey.currentState?.completeConnection();
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
    _explosionTimer = null;
    if (!isScreenActive || _memoriesData.isEmpty) return;
    _spawnPhotoExplosion();
    _explosionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isScreenActive) {
        timer.cancel();
        _explosionTimer = null;
        return;
      }
      _spawnPhotoExplosion();
    });
  }

  void _spawnPhotoExplosion({
    Map<String, String>? specificItem,
    Offset? specificPosition,
  }) {
    if (!isScreenActive) return;
    if (_memoriesData.isEmpty && specificItem == null) return;
    final randomItem =
        specificItem ?? _memoriesData[_random.nextInt(_memoriesData.length)];

    final size = MediaQuery.of(context).size;
    final double x = 20 + _random.nextDouble() * math.max(1, size.width - 120);
    final double y = MediaQuery.paddingOf(context).top + 60;
    final position = Offset(
      (specificPosition?.dx ?? x)
          .clamp(12, math.max(12, size.width - 110))
          .toDouble(),
      y,
    );

    final photo = ExplodingPhoto(
      url: randomItem['url'] ?? '',
      text: randomItem['text'] ?? '',
      type: randomItem['type'] ?? 'photo',
      mood: randomItem['mood'] ?? '💖',
      dateStr: randomItem['dateStr'] ?? '',
      position: position,
      angle: (_random.nextDouble() - 0.5) * 0.4, // Slight rotation
      targetScale: 0.48 + _random.nextDouble() * 0.12,
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
  void onScreenActivityChanged(bool active) {
    if (!active) {
      _bumpDetector.stop();
      _explosionTimer?.cancel();
      _explosionTimer = null;
      _unbindRealtimeListeners();
      return;
    }
    _bindRealtimeListeners();
    if (!_isMerged) _bumpDetector.start();
    if (_isMerged && _memoriesData.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isScreenActive) _startPhotoExplosions();
      });
    }
  }

  @override
  void dispose() {
    _vipSub?.cancel();
    _customMsgController.dispose();
    _soulComposerFocusNode.dispose();
    _chatScrollController.removeListener(_onChatScroll);
    _chatScrollController.dispose();
    _backgroundSub?.cancel();
    _soulAvatarSub?.cancel();
    _pinnedMessagesSub?.cancel();
    _interactiveScaleNotifier.dispose();
    _messagesSub?.cancel();
    _interactiveEventsSub?.cancel();
    _readReceiptsSub?.cancel();
    _messageOutbox.dispose();
    _bumpDetector.stop();
    _unbindRealtimeListeners();
    _overlayListenerSub?.cancel();
    _explosionTimer?.cancel();
    _tempBlockTimer?.cancel();
    unawaited(_mergeService.clearBumps());
    unawaited(_mergeService.clearChat());
    super.dispose();
  }

  /// Bắt đầu cuộc gọi thoại/video với người yêu
  Future<void> _startCoupleCall({required bool isVideo}) async {
    if (_callRouteOpen || !_scopeIsCurrent) return;
    if (WebRTCService().isBusy) {
      SLNotice.showError(context, context.tr('p4_call_busy'));
      return;
    }
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) {
      SLNotice.showError(context, context.tr('p4_soul_house_missing'));
      return;
    }

    _callRouteOpen = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            houseId: houseId,
            targetHouseId: houseId, // Cùng house
            targetName: _partnerName,
            isVideo: isVideo,
            callerName: _myName,
          ),
        ),
      );
    } finally {
      _callRouteOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    final photoMessages = _chatHistory.where((m) {
      final url = (m['imageUrl']?.toString() ?? '').trim();
      return url.startsWith('http://') || url.startsWith('https://');
    }).toList();
    final latestPhotos = photoMessages.length > 3
        ? photoMessages.sublist(photoMessages.length - 3)
        : photoMessages;

    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.background),

          if (_backgroundUrl.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CachedNetworkImage(
                  imageUrl: _backgroundUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 1440,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                  color: Colors.black.withValues(alpha: 0.18),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),

          if (_backgroundUrl.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: Colors.white.withValues(alpha: .08)),
              ),
            ),

          Positioned.fill(
            child: SoulMergeTouchCascade(
              key: _touchCascadeKey,
              style: _activeStyle,
            ),
          ),

          // 4. Floating message bubbles
          for (final msg in _floatingMessages)
            FloatingMessageWidget(key: msg.id, message: msg),

          Positioned.fill(
            top:
                MediaQuery.paddingOf(context).top +
                SoulMergeHeader.contentHeight(context) +
                10,
            bottom: MediaQuery.paddingOf(context).bottom + 10,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showInteraction =
                        constraints.maxHeight >= 300 &&
                        MediaQuery.viewInsetsOf(context).bottom == 0;
                    return Column(
                      children: [
                        if (showInteraction) ...[
                          SoulMergeInteractionStrip(
                            scale: _interactiveScaleNotifier,
                            isMerged: _isMerged,
                            partnerName: _partnerName,
                            isSelfReady: _iHaveBumped,
                            isPartnerReady: _partnerHasBumped,
                            onAccessibleTap: () {
                              // Screen reader dùng hai lần kích hoạt để giữ/thả.
                              if (_interactiveScaleNotifier.value < 1) {
                                _onTapUp();
                              } else {
                                _interactiveScaleNotifier.value = .9;
                                _startTouchHolding();
                                _handleLocalBump();
                              }
                            },
                            heartPulse: _heartPulse,
                            heartStyle: _activeStyle,
                            photoUrls: latestPhotos
                                .map((photo) => photo['imageUrl'].toString())
                                .toList(growable: false),
                            onPointerDown: (event) =>
                                _onTapDown(event.position),
                            onPointerMove: (_) {},
                            onPointerUp: (_) => _onTapUp(),
                            onPointerCancel: (_) => _onTapCancel(),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Expanded(child: _buildChatInputBar()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top + 176,
            child: IgnorePointer(
              child: ClipRect(
                child: Stack(
                  children: [
                    for (final explosion in _activeParticleExplosions)
                      ParticleExplosionWidget(
                        key: explosion.id,
                        position: explosion.position,
                      ),
                    for (final photo in _activePhotos)
                      ExplodingPhotoWidget(key: photo.id, photo: photo),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SoulMergeHeader(
              partnerName: _partnerName,
              avatarUrl: _soulAvatarUrl,
              onBack: () => Navigator.of(context).pop(),
              onVoiceCall: () => _startCoupleCall(isVideo: false),
              onVideoCall: () => _startCoupleCall(isVideo: true),
              onOptions: _showSoulOptions,
              onSearch: () {
                if (!mounted || !isScreenActive) return;
                setState(() => _messageSearchOpen = true);
              },
              onAvatarTap: _showSoulOptions,
            ),
          ),
        ],
      ),
    );
  }

  void _listenInteractiveEvents() {
    final houseId = _houseId;
    _interactiveEventsSub?.cancel();
    _interactiveEventsSub = _mergeService
        .watchInteractiveEvents(houseId: houseId)
        .listen((event) {
      if (!mounted ||
          !isScreenActive ||
          !_scopeIsCurrent ||
          _houseId != houseId) {
        return;
      }
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
        setState(() => _heartPulse++);
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
    final houseId = _houseId;
    _messagesSub?.cancel();
    _messagesSub = _mergeService
        .watchSoulMessages(houseId: houseId)
        .listen(
          (list) {
            if (!mounted ||
                !isScreenActive ||
                !_scopeIsCurrent ||
                _houseId != houseId) {
              return;
            }
            final wasNearBottom =
                !_chatScrollController.hasClients ||
                _chatScrollController.offset < 48;
            _messageHistory.applyLatest(list);
            final visibleHistory = _visibleSoulMessages;
            _messageOutbox.reconcile(visibleHistory);
            if (_replyTarget != null) {
              final targets = visibleHistory.where(
                (message) => message['id'] == _replyTarget!['id'],
              );
              _replyTarget = targets.isEmpty ? null : targets.first;
            }
            final visibleLatest = list
                .where(
                  (message) =>
                      SoulMessageActions.visibleTo(message, _screenOwnerUid),
                )
                .toList();

            if (visibleLatest.isNotEmpty) {
              int highestT = 0;
              for (final msg in visibleLatest) {
                final t = msg['timestamp'] as int? ?? 0;
                if (t > highestT) highestT = t;
              }
              if (highestT != _lastAnyMsgTimestamp) {
                setState(() => _lastAnyMsgTimestamp = highestT);
              }
            }

            final isFirstLoad = !_hasProcessedFirstMessages;
            int maxTimestamp = _lastMsgTimestamp;

            if (isFirstLoad) {
              _hasProcessedFirstMessages = true;
              final unreadMsgs = visibleLatest.where((msg) {
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
                    if (mounted && isScreenActive) {
                      _spawnFloatingMessage(text, false);
                    }
                  });
                }
              }

              for (final msg in visibleLatest) {
                final t = msg['timestamp'] as int? ?? 0;
                if (t > maxTimestamp) maxTimestamp = t;
              }
            }

            for (final msg in visibleLatest) {
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
                          if (active && mounted && isScreenActive) {
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
              _chatHistory = _decorateMessageDelivery(
                _messageOutbox.merge(visibleHistory),
              );
              _hasLoadedMessages = true;
              _latestMessagesFailed = false;
              _lastMsgTimestamp = maxTimestamp;
            });

            _sendOverlaySyncPayload();

            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
              FlutterOverlayWindow.isActive().then((active) {
                if (mounted && isScreenActive && _overlayEnabled != active) {
                  setState(() {
                    _overlayEnabled = active;
                  });
                }
              });
            }

            if (wasNearBottom) _scrollChatToBottom();
          },
          onError: (Object error) {
            if (!mounted ||
                !isScreenActive ||
                !_scopeIsCurrent ||
                _houseId != houseId) {
              return;
            }
            setState(() => _latestMessagesFailed = true);
            debugPrint(
              '[SoulMergeScreen] Chat load failed: ${error.runtimeType}',
            );
          },
        );
  }

  bool get _scopeIsCurrent =>
      _screenOwnerUid != null &&
      FirebaseAuth.instance.currentUser?.uid == _screenOwnerUid;

  void _onChatScroll() {
    if (!isScreenActive ||
        !_chatScrollController.hasClients ||
        !_hasLoadedMessages ||
        _historyLoadFailed ||
        _chatScrollController.position.userScrollDirection ==
            ScrollDirection.idle) {
      return;
    }
    if (_chatScrollController.position.extentAfter < 100) {
      unawaited(_loadOlderMessages());
    }
  }

  void _retryHistory() {
    if (!isScreenActive) return;
    if (_latestMessagesFailed) {
      setState(() => _latestMessagesFailed = false);
      _listenSoulMessages();
    } else {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    final before = _messageHistory.before;
    final houseId = _houseId;
    if (_isLoadingOlderMessages ||
        !_messageHistory.hasOlder ||
        before == null ||
        houseId == null ||
        !_scopeIsCurrent ||
        !isScreenActive) {
      return;
    }
    setState(() {
      _isLoadingOlderMessages = true;
      _historyLoadFailed = false;
    });
    try {
      final page = await _mergeService.loadOlderSoulMessages(
        houseId: houseId,
        before: before,
      );
      if (!mounted ||
          !isScreenActive ||
          !_scopeIsCurrent ||
          _houseId != houseId)
        return;
      _messageHistory.applyOlder(page, requestedBefore: before);
      setState(() => _chatHistory = _visibleSoulMessages);
    } catch (error) {
      if (!mounted || !isScreenActive || !_scopeIsCurrent) return;
      setState(() => _historyLoadFailed = true);
      debugPrint('[SoulMergeScreen] History load failed: ${error.runtimeType}');
    } finally {
      if (mounted) setState(() => _isLoadingOlderMessages = false);
    }
  }

  void _listenBackground() {
    final houseId = _houseId;
    if (houseId == null) return;
    _backgroundSub?.cancel();
    _backgroundSub = _mergeService
        .watchSoulBackground(houseId)
        .listen(
          (background) {
            if (!mounted ||
                !isScreenActive ||
                !_scopeIsCurrent ||
                _houseId != houseId)
              return;
            final url = background['url']?.toString() ?? '';
            final uri = Uri.tryParse(url);
            setState(
              () => _backgroundUrl =
                  uri?.scheme == 'https' &&
                      uri!.host.isNotEmpty &&
                      uri.userInfo.isEmpty
                  ? url
                  : '',
            );
          },
          onError: (Object error) {
            debugPrint(
              '[SoulMergeScreen] Background load failed: ${error.runtimeType}',
            );
          },
        );
  }

  void _listenSoulAvatar() {
    final houseId = _houseId;
    if (houseId == null) return;
    _soulAvatarSub?.cancel();
    _soulAvatarSub = _mergeService
        .watchSoulAvatar(houseId)
        .listen(
          (avatar) {
            if (!mounted ||
                !isScreenActive ||
                !_scopeIsCurrent ||
                _houseId != houseId)
              return;
            final url = avatar['url']?.toString() ?? '';
            final uri = Uri.tryParse(url);
            setState(
              () => _soulAvatarUrl =
                  uri?.scheme == 'https' &&
                      uri!.host.isNotEmpty &&
                      uri.userInfo.isEmpty
                  ? url
                  : '',
            );
          },
          onError: (Object error) {
            debugPrint(
              '[SoulMergeScreen] Soul Merge avatar load failed: ${error.runtimeType}',
            );
          },
        );
  }

  Future<void> _showSoulOptions() async {
    final option = await showModalBottomSheet<SoulMergeOption>(
      context: context,
      backgroundColor: const Color(0xFFFFF8FA),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => SoulMergeOptionsSheet(
        hasAvatar: _soulAvatarUrl.isNotEmpty,
        hasBackground: _backgroundUrl.isNotEmpty,
        overlayEnabled: _overlayEnabled,
        isUploadingBackground: _isUploadingBackground,
        isUploadingAsset: _isUploadingSoulAsset || _isUploadingBackground,
      ),
    );
    if (!mounted || !_scopeIsCurrent) return;
    switch (option) {
      case SoulMergeOption.avatar:
        await _pickSoulAvatar();
      case SoulMergeOption.background:
        await _pickSoulBackground();
      case SoulMergeOption.removeBackground:
        await _removeSoulBackground();
      case SoulMergeOption.overlay:
        await _toggleOverlaySetting();
      case SoulMergeOption.heartStyle:
        _showHeartStyleSheet();
      case null:
        break;
    }
  }

  Future<void> _pickSoulAvatar() async {
    final houseId = _houseId;
    final ownerUid = _screenOwnerUid;
    bool isCurrent() => mounted && _scopeIsCurrent &&
        ownerUid != null && _screenOwnerUid == ownerUid && _houseId == houseId;
    if (_isUploadingSoulAsset || houseId == null || !_scopeIsCurrent) return;
    setState(() => _isUploadingSoulAsset = true);
    try {
      var image = await StorageService.instance.pickImage(preserveOriginal: true);
      if (image == null ||
          !mounted ||
          !_scopeIsCurrent ||
          _houseId != houseId) {
        return;
      }
      image = await cropAndConfirmImage(
        context: context,
        image: image,
        aspectRatio: 1,
        circular: true,
        maxOutputSize: const Size(1080, 1080),
        titleKey: 'p5_profile_crop_avatar',
        isScopeCurrent: isCurrent,
      );
      if (image == null || !isCurrent()) return;
      if (await _mergeService.getCurrentHouseId() != houseId || !isCurrent()) return;
      // Avatar Soul Merge phải dùng session ảnh công khai Firebase Storage.
      // Đường managed generic trả URL R2 r2.dev đã đóng public (401), khiến
      // CachedNetworkImage không thể đọc dù upload đã báo thành công.
      final upload = await StorageService.instance.uploadPublicImage(
        houseId,
        'soul_merge',
        image,
        minWidth: 512,
        minHeight: 512,
        quality: 88,
      );
      if (upload == null ||
          upload.downloadUrl.isEmpty ||
          !mounted ||
          !_scopeIsCurrent ||
          _houseId != houseId) {
        throw StateError('Soul Merge avatar upload not confirmed');
      }
      await _mergeService.saveSoulAvatar(
        houseId,
        url: upload.downloadUrl,
        storagePath: upload.storagePath,
      );
      if (!mounted || !isCurrent()) return;
      await discardConfirmedCropImage(image);
      if (!mounted || !isCurrent()) return;
      setState(() => _soulAvatarUrl = upload.downloadUrl);
      SLNotice.showSuccess(context, context.tr('p5_profile_change_avatar'));
    } catch (error) {
      if (mounted && _scopeIsCurrent) {
        SLNotice.showError(context, context.tr('err_upload_background'));
      }
      debugPrint(
        '[SoulMergeScreen] Soul Merge avatar upload failed: ${error.runtimeType}',
      );
    } finally {
      if (mounted) setState(() => _isUploadingSoulAsset = false);
    }
  }

  Future<void> _pickSoulBackground() async {
    final houseId = _houseId;
    final ownerUid = _screenOwnerUid;
    if (_isUploadingBackground ||
        houseId == null ||
        houseId.isEmpty ||
        ownerUid == null ||
        !_scopeIsCurrent) {
      return;
    }
    bool isScopeCurrent() =>
        mounted &&
        _scopeIsCurrent &&
        _screenOwnerUid == ownerUid &&
        _houseId == houseId;
    final backgroundSize = MediaQuery.sizeOf(context);
    setState(() => _isUploadingBackground = true);
    File? temporaryCrop;
    try {
      final image = await StorageService.instance.pickImage(
        preserveOriginal: true,
      );
      if (image == null || !mounted || !isScopeCurrent()) return;
      final croppedBytes = await showSoulMergeBackgroundEditor(
        context: context,
        image: image,
        backgroundSize: backgroundSize,
        isScopeCurrent: isScopeCurrent,
      );
      if (croppedBytes == null || !isScopeCurrent()) return;
      // Kiểm tra House thật sau thời gian chọn/chỉnh ảnh, trước tạo phiên upload.
      if (await _mergeService.getCurrentHouseId() != houseId ||
          !isScopeCurrent()) {
        return;
      }
      var uploadImage = XFile.fromData(
        croppedBytes,
        name: 'soul_merge_background.png',
        mimeType: 'image/png',
      );
      if (!kIsWeb) {
        // File tạm riêng để dùng bước nén WebP native của StorageService.
        final temporaryDirectory = await getTemporaryDirectory();
        if (!isScopeCurrent()) return;
        temporaryCrop = File(
          '${temporaryDirectory.path}/soul_merge_background_${DateTime.now().microsecondsSinceEpoch}.png',
        );
        await temporaryCrop.writeAsBytes(croppedBytes);
        if (!isScopeCurrent()) return;
        uploadImage = XFile(temporaryCrop.path);
      }
      // Nền chat cần URL Firebase Storage đọc được lâu dài. Không dùng
      // managed R2 generic vì public endpoint hiện trả 401 khi tải ảnh.
      final upload = await StorageService.instance.uploadPublicImage(
        houseId,
        'soul_merge',
        uploadImage,
        minWidth: 1080,
        minHeight: 1600,
        quality: 82,
      );
      if (upload == null ||
          upload.downloadUrl.isEmpty ||
          !mounted ||
          !_scopeIsCurrent ||
          _houseId != houseId) {
        throw StateError('Soul Merge background upload not confirmed');
      }
      await _mergeService.saveSoulBackground(
        houseId,
        url: upload.downloadUrl,
        storagePath: upload.storagePath,
        expectedUid: ownerUid,
      );
      if (!mounted || !isScopeCurrent()) return;
      setState(() => _backgroundUrl = upload.downloadUrl);
      SLNotice.showSuccess(context, context.tr('theme_success_bg_saved'));
    } catch (error) {
      if (mounted && _scopeIsCurrent) {
        SLNotice.showError(context, context.tr('err_upload_background'));
      }
      debugPrint(
        '[SoulMergeScreen] Background upload failed: ${error.runtimeType}',
      );
    } finally {
      if (temporaryCrop != null) {
        try {
          await temporaryCrop.delete();
        } catch (_) {
          debugPrint('[SoulMergeScreen] Background crop cleanup deferred');
        }
      }
      if (mounted) setState(() => _isUploadingBackground = false);
    }
  }

  Future<void> _removeSoulBackground() async {
    final houseId = _houseId;
    if (_isUploadingBackground || houseId == null || !_scopeIsCurrent) return;
    setState(() => _isUploadingBackground = true);
    try {
      await _mergeService.saveSoulBackground(houseId);
      if (mounted && _scopeIsCurrent) setState(() => _backgroundUrl = '');
    } catch (error) {
      if (mounted && _scopeIsCurrent) {
        SLNotice.showError(context, context.tr('err_upload_background'));
      }
    } finally {
      if (mounted) setState(() => _isUploadingBackground = false);
    }
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
  }

  Future<void> _sendStickerMessage(String assetPath) async {
    if (_isSendingMessage || !_scopeIsCurrent) return;
    if (await _checkSpamAndMaybeBlock()) return;
    final reply = _replyTarget;
    try {
      await _mergeService.sendSoulMessage(
        '',
        imageUrl: assetPath,
        replyTo: reply?['id']?.toString(),
        expectedHouseId: _houseId,
        expectedUid: _screenOwnerUid,
      );
      if (!mounted || !_scopeIsCurrent) return;
      if (identical(_replyTarget, reply)) setState(() => _replyTarget = null);
    } catch (error) {
      if (mounted && _scopeIsCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('p4_soul_send_failed'))),
        );
      }
      return;
    }

  }

  List<Map<String, dynamic>> get _visibleSoulMessages => _messageHistory
      .messages
      .where(
        (message) => SoulMessageActions.visibleTo(message, _screenOwnerUid),
      )
      .toList();

  void _listenReadReceipts() {
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) return;
    _readReceiptsSub?.cancel();
    _readReceiptsSub = _mergeService.watchSoulReadReceipts(houseId).listen((
      receipts,
    ) {
      if (!mounted ||
          !isScreenActive ||
          !_scopeIsCurrent ||
          _houseId != houseId)
        return;
      setState(() {
        _readReceipts = receipts;
        _chatHistory = _decorateMessageDelivery(
          _messageOutbox.merge(_visibleSoulMessages),
        );
      });
    });
  }

  List<Map<String, dynamic>> _decorateMessageDelivery(
    List<Map<String, dynamic>> messages,
  ) => messages
      .map((message) {
        final state = message['__delivery'];
        if (state == 'sending' || state == 'failed') return message;
        if (soulMessageIsSelf(message, _screenOwnerUid, _myRole) &&
            soulMessageWasSeen(message, _readReceipts)) {
          return {...message, '__delivery': 'seen'};
        }
        if (soulMessageIsSelf(message, _screenOwnerUid, _myRole))
          return {...message, '__delivery': 'sent'};
        return message;
      })
      .toList(growable: false);

  void _markMessageVisible(Map<String, dynamic> message) {
    final houseId = _houseId;
    final uid = _screenOwnerUid;
    final id = message['id']?.toString() ?? '';
    final timestamp = (message['timestamp'] as num?)?.toInt() ?? 0;
    if (houseId == null ||
        uid == null ||
        id.isEmpty ||
        timestamp <= _lastSeenMsgTimestamp ||
        soulMessageIsSelf(message, uid, _myRole) ||
        id == _lastMarkedReadId)
      return;
    _lastMarkedReadId = id;
    unawaited(
      _mergeService
          .markSoulMessageRead(
            houseId: houseId,
            expectedUid: uid,
            role: _myRole,
            messageId: id,
            timestamp: timestamp,
          )
          .then((_) {
            if (!mounted || !_scopeIsCurrent || _houseId != houseId) return;
            setState(() {
              _lastSeenMsgTimestamp = timestamp;
            });
            SharedPreferences.getInstance().then(
              (prefs) => prefs.setInt('soul_merge_last_seen_msg_ts', timestamp),
            );
          })
          .catchError((_) {
            if (_lastMarkedReadId == id) _lastMarkedReadId = null;
          }),
    );
  }

  Future<void> _retrySoulMessage(String id) async {
    final pending = _messageOutbox[id];
    final houseId = _houseId;
    final uid = _screenOwnerUid;
    if (pending == null || houseId == null || uid == null || _isSendingMessage)
      return;
    _messageOutbox.setState(id, SoulDeliveryState.sending);
    if (mounted)
      setState(
        () => _chatHistory = _decorateMessageDelivery(
          _messageOutbox.merge(_visibleSoulMessages),
        ),
      );
    try {
      await _mergeService.sendSoulMessage(
        pending.text,
        imageUrl: pending.imageUrl,
        replyTo: pending.replyTo,
        expectedHouseId: houseId,
        expectedUid: uid,
        messageId: id,
        isRetry: true,
      );
      _messageOutbox.setState(id, SoulDeliveryState.sent);
    } catch (_) {
      _messageOutbox.setState(id, SoulDeliveryState.failed);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('p4_soul_send_failed'))),
        );
    }
    if (mounted)
      setState(
        () => _chatHistory = _decorateMessageDelivery(
          _messageOutbox.merge(_visibleSoulMessages),
        ),
      );
  }

  void _onSoulMessageChanged(String id, Map<String, dynamic>? message) {
    if (!mounted || !isScreenActive || !_scopeIsCurrent) return;
    setState(() {
      _messageHistory.applyMessage(id, message);
      _chatHistory = _visibleSoulMessages;
      if (_replyTarget?['id'] == id) {
        _replyTarget =
            message != null &&
                SoulMessageActions.visibleTo(message, _screenOwnerUid)
            ? message
            : null;
      }
    });
    _sendOverlaySyncPayload();
  }

  Future<void> _performMessageAction(
    Map<String, dynamic> message,
    String errorKey,
    Future<void> Function(String houseId, String uid, String id) action,
  ) async {
    final houseId = _houseId;
    final uid = _screenOwnerUid;
    final id = message['id']?.toString() ?? '';
    if (!mounted ||
        !_scopeIsCurrent ||
        houseId == null ||
        uid == null ||
        id.isEmpty) {
      return;
    }
    try {
      await action(houseId, uid, id);
    } catch (error) {
      if (!mounted || !_scopeIsCurrent || _houseId != houseId) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr(errorKey))));
      debugPrint('[SoulMergeScreen] Message action failed');
    }
  }

  Future<void> _reactToSoulMessage(
    Map<String, dynamic> message,
    String reaction,
  ) => _performMessageAction(
    message,
    'p4_soul_action_reaction_failed',
    (houseId, uid, id) => _mergeService.setSoulReaction(
      houseId: houseId,
      expectedUid: uid,
      messageId: id,
      reaction: reaction,
    ),
  );

  Future<void> _removeSoulReaction(Map<String, dynamic> message) =>
      _performMessageAction(
        message,
        'p4_soul_action_reaction_failed',
        (houseId, uid, id) => _mergeService.removeSoulReaction(
          houseId: houseId,
          expectedUid: uid,
          messageId: id,
        ),
      );

  bool _canDeleteSoulMessage(Map<String, dynamic> message) =>
      _scopeIsCurrent &&
      message['senderUid'] != null &&
      message['senderUid'] == _screenOwnerUid;

  void _replyToSoulMessage(Map<String, dynamic> message) {
    if (!_scopeIsCurrent) return;
    setState(() => _replyTarget = message);
    _soulComposerFocusNode.requestFocus();
  }

  Future<void> _hideSoulMessage(Map<String, dynamic> message) =>
      _performMessageAction(message, 'p4_soul_action_delete_failed', (
        houseId,
        uid,
        id,
      ) async {
        await _mergeService.hideSoulMessage(
          houseId: houseId,
          expectedUid: uid,
          messageId: id,
        );
        if (mounted && _scopeIsCurrent && _houseId == houseId) {
          _onSoulMessageChanged(id, {
            ...message,
            'hiddenFor': {
              if (message['hiddenFor'] is Map)
                ...Map<String, dynamic>.from(message['hiddenFor'] as Map),
              uid: true,
            },
          });
        }
      });

  Future<void> _deleteSoulMessage(Map<String, dynamic> message) =>
      _performMessageAction(message, 'p4_soul_action_delete_failed', (
        houseId,
        uid,
        id,
      ) async {
        await _mergeService.deleteSoulMessage(
          houseId: houseId,
          expectedUid: uid,
          messageId: id,
        );
        if (mounted && _scopeIsCurrent && _houseId == houseId) {
          _onSoulMessageChanged(id, null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('p4_soul_action_deleted'))),
          );
        }
      });

  bool _isMessagePinned(Map<String, dynamic> message) {
    final id = message['id']?.toString();
    return id != null &&
        _pinnedMessages.any((pin) => pin['id']?.toString() == id);
  }

  Future<void> _pinSoulMessage(Map<String, dynamic> message) async {
    final houseId = _houseId;
    final uid = _screenOwnerUid;
    final id = message['id']?.toString();
    if (!isScreenActive || houseId == null || uid == null || id == null) return;
    try {
      await _mergeService.pinSoulMessage(
        houseId: houseId,
        expectedUid: uid,
        messageId: id,
      );
    } catch (error) {
      if (mounted && isScreenActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('p4_soul_action_reaction_failed'))),
        );
      }
      debugPrint('[SoulMergeScreen] Pin message failed: ${error.runtimeType}');
    }
  }

  Future<void> _unpinSoulMessage(Map<String, dynamic> message) async {
    final houseId = _houseId;
    final uid = _screenOwnerUid;
    final id = message['id']?.toString();
    if (!isScreenActive || houseId == null || uid == null || id == null) return;
    try {
      await _mergeService.unpinSoulMessage(
        houseId: houseId,
        expectedUid: uid,
        messageId: id,
      );
    } catch (error) {
      if (mounted && isScreenActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('p4_soul_action_reaction_failed'))),
        );
      }
      debugPrint(
        '[SoulMergeScreen] Unpin message failed: ${error.runtimeType}',
      );
    }
  }

  void _showStickerBottomSheet() {
    StickerBottomSheet.show(
      context: context,
      onStickerSelected: _sendStickerMessage,
    );
  }

  Future<void> _sendCustomMessage() async {
    if (_isSendingMessage || !_scopeIsCurrent) return;
    final draft = _customMsgController.text;
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
              SLSnackBar(
                content: Text(displayMessage),
                backgroundColor: result.success ? Colors.green : Colors.red,
              ),
            );
          } catch (e) {
            debugPrint('Error redeeming giftcode in soul merge chat: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SLSnackBar(
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

    final reply = _replyTarget;
    final houseId = _houseId;
    final uid = _screenOwnerUid;
    if (houseId == null || uid == null) return;
    if (await _checkSpamAndMaybeBlock()) return;
    final messageId = _mergeService.newSoulMessageId(houseId);
    final pending = SoulPendingMessage(
      id: messageId,
      text: text,
      role: _myRole,
      uid: uid,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      replyTo: reply?['id']?.toString(),
      draft: draft,
    );
    _messageOutbox.add(pending);
    if (mounted)
      setState(() {
        _isSendingMessage = true;
        _chatHistory = _decorateMessageDelivery(
          _messageOutbox.merge(_visibleSoulMessages),
        );
      });
    try {
      await _mergeService.sendSoulMessage(
        text,
        replyTo: reply?['id']?.toString(),
        expectedHouseId: houseId,
        expectedUid: uid,
        messageId: messageId,
      );
      _messageOutbox.setState(messageId, SoulDeliveryState.sent);
      if (!mounted || !_scopeIsCurrent || _houseId != houseId) return;
      if (_customMsgController.text == draft) _customMsgController.clear();
      if (identical(_replyTarget, reply)) setState(() => _replyTarget = null);
    } catch (error) {
      _messageOutbox.setState(messageId, SoulDeliveryState.failed);
      if (mounted && _scopeIsCurrent && _houseId == houseId) {
        setState(
          () => _chatHistory = _decorateMessageDelivery(
            _messageOutbox.merge(_visibleSoulMessages),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('p4_soul_send_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
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
      chatHistory: _filteredChatHistory,
      myRole: _myRole,
      partnerName: _partnerName,
      spamWarning: _spamWarning,
      textController: _customMsgController,
      scrollController: _chatScrollController,
      isUploadingPhoto: _isUploadingPhoto,
      lastAnyMsgTimestamp: _lastAnyMsgTimestamp,
      isMerged: _isMerged,
      isLoadingHistory:
          _isLoadingOlderMessages ||
          (!_hasLoadedMessages && !_latestMessagesFailed),
      historyLoadFailed: _historyLoadFailed || _latestMessagesFailed,
      onRetryHistory: _retryHistory,
      onLoadOlder: () => unawaited(_loadOlderMessages()),
      onSendCustomMessage: _sendCustomMessage,
      onPickImage: _pickAndSendChatImage,
      onShowSticker: _showStickerBottomSheet,
      onSendPreset: (message) => unawaited(_sendSoulMessage(message)),
      formatTime: _formatTime,
      onReactMessage: _reactToSoulMessage,
      onDeleteMessage: _deleteSoulMessage,
      onReplyMessage: _replyToSoulMessage,
      canDeleteMessage: _canDeleteSoulMessage,
      composerFocusNode: _soulComposerFocusNode,
      onHideMessage: _hideSoulMessage,
      onRemoveReaction: _removeSoulReaction,
      currentUid: _screenOwnerUid,
      replyTarget: _replyTarget,
      onCancelReply: () => setState(() => _replyTarget = null),
      isSending: _isSendingMessage,
      watchMessage: (id) => _mergeService.watchSoulMessage(_houseId!, id),
      shouldWatchMessage: (id) => !_messageHistory.isLatest(id),
      onMessageChanged: _onSoulMessageChanged,
      onMessageVisible: _markMessageVisible,
      onRetryMessage: _retrySoulMessage,
      searchQuery: _messageSearchOpen ? _messageSearchQuery : null,
      onSearchChanged: (value) {
        if (mounted && isScreenActive) {
          setState(() => _messageSearchQuery = value);
        }
      },
      onCloseSearch: () {
        if (mounted) {
          setState(() {
            _messageSearchOpen = false;
            _messageSearchQuery = '';
          });
        }
      },
      pinnedMessages: _pinnedDisplayMessages,
      onPinMessage: _pinSoulMessage,
      onUnpinMessage: _unpinSoulMessage,
      isMessagePinned: _isMessagePinned,
    );
  }

  void _sendOverlaySyncPayload() {
    if (!isScreenActive ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    FlutterOverlayWindow.isActive().then((active) {
      if (!active || !mounted || !isScreenActive) return;
      final credentialsPayload = jsonEncode({
        'type': 'sync_credentials',
        'houseId': _houseId ?? '',
        'role': _myRole,
        'partnerName': _partnerName,
      });
      FlutterOverlayWindow.shareData(credentialsPayload);

      final chatPayload = jsonEncode({
        'type': 'update_chat',
        'history': _chatHistory.reversed
            .take(SoulMessageHistory.pageSize)
            .toList()
            .reversed
            .toList(),
        'myRole': _myRole,
        'partnerName': _partnerName,
      });
      FlutterOverlayWindow.shareData(chatPayload);

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
              SLSnackBar(
                content: Text(context.tr('p4_soul_overlay_permission')),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
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
      _sendOverlaySyncPayload();

      if (mounted) {
        setState(() {
          _overlayEnabled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(context.tr('p4_soul_overlay_enabled')),
            backgroundColor: const Color(0xFFFF4F93),
            behavior: SnackBarBehavior.floating,
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
          SLSnackBar(
            content: Text(context.tr('p4_soul_overlay_disabled')),
            backgroundColor: Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
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
                            L10nService().translate(
                              'ui_home_pro_test_unlocked_badge',
                            ),
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
