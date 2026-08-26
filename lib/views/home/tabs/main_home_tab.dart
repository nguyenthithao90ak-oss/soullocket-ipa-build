// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'package:lottie/lottie.dart';
import 'package:soullocket_app/widgets/r2_sticker_image.dart';
import 'package:soullocket_app/views/utilities/tarot/tarot_screen.dart';
import 'package:soullocket_app/views/utilities/wheel/wheel_screen.dart';
import 'package:provider/provider.dart';
import 'package:soullocket_app/views/home/tabs/main_home/providers/home_data_controller.dart';
import 'package:soullocket_app/views/home/tabs/main_home/providers/home_presence_controller.dart';
import 'package:soullocket_app/views/home/tabs/main_home/providers/home_interaction_controller.dart';
import 'package:soullocket_app/views/home/widgets/main_home/map_tilt_card.dart';
import 'package:soullocket_app/views/home/widgets/main_home/hero/heartbeat_thread_painter.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_bouncing_button.dart';
import 'package:soullocket_app/views/home/widgets/anniversary_sparkle_painter.dart';
import 'package:soullocket_app/views/home/widgets/main_home/hero/snow_globe_photo_layer.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_dashboard_screen.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:soullocket_app/utils/helpers/sensor_helper.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, ValueListenable;
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:latlong2/latlong.dart' as ll;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/views/chat/messenger_screen.dart';
import 'package:soullocket_app/views/chat/chat_detail_screen.dart';
import 'package:soullocket_app/views/map/map_screen.dart';
import 'package:soullocket_app/views/relationship/couple_connect_screen.dart';
import 'package:soullocket_app/views/single_match/single_match_hub_screen.dart';
import 'package:soullocket_app/views/home/widgets/soul_merge_screen.dart';
import 'package:soullocket_app/views/home/screens/interaction_sticker_editor_screen.dart';
import 'package:soullocket_app/widgets/animated_rabbit_sticker.dart';
import 'package:soullocket_app/utils/services/soul_merge_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/home_startup_media_cache.dart';
import 'package:soullocket_app/utils/services/love_insight_service.dart';
import 'package:soullocket_app/utils/services/location_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/military_lock_service.dart';
import 'package:soullocket_app/utils/services/presence_service.dart';
import 'package:soullocket_app/utils/services/utility_service.dart';
import 'package:soullocket_app/utils/services/house_settings_service.dart';
// import 'package:soullocket_app/utils/services/album_service.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/utils/services/storage/storage_service.dart';
import 'package:soullocket_app/utils/services/utilities/note_service.dart';
import 'package:soullocket_app/utils/services/pending_upload_service.dart';
import 'package:soullocket_app/utils/sl_notice.dart';
// import 'package:soullocket_app/models/album_item.dart';
import 'package:soullocket_app/models/house_settings.dart';
import 'package:soullocket_app/models/utilities/shared_note.dart';
import 'package:soullocket_app/views/home/tabs/settings_tab.dart'
    show SettingsTab, FloatingHeartsRingOverlay;
import 'package:soullocket_app/views/ui_prefs.dart';
// import 'package:soullocket_app/views/utilities/age_zodiac_screen.dart';
import 'package:soullocket_app/views/utilities/bucket_list_screen.dart';
import 'package:soullocket_app/views/utilities/calendar_screen.dart';
import 'package:soullocket_app/views/utilities/capsule_screen.dart';
import 'package:soullocket_app/views/utilities/cinema_screen.dart';
import 'package:soullocket_app/views/utilities/collage_maker_screen.dart';
import 'package:soullocket_app/views/utilities/creative_diary_screen.dart';
import 'package:soullocket_app/views/utilities/drawing_studio_screen.dart';
import 'package:soullocket_app/views/utilities/finance_screen.dart';
import 'package:soullocket_app/views/utilities/friendly_chat_screen.dart';
// import 'package:soullocket_app/views/utilities/gift_maker_screen.dart';
import 'package:soullocket_app/views/utilities/giftcode_screen.dart';
import 'package:soullocket_app/views/utilities/habit_screen.dart';
import 'package:soullocket_app/views/utilities/love_card_screen.dart';
import 'package:soullocket_app/views/utilities/reward_store_screen.dart';
import 'package:soullocket_app/views/utilities/secret_vault_screen.dart';
import 'package:soullocket_app/views/utilities/shared_notes_screen.dart';
// import 'package:soullocket_app/views/utilities/calculator_screen.dart';
import 'package:soullocket_app/views/utilities/diary_export_screen.dart';
import 'package:soullocket_app/views/utilities/history_screen.dart';
// import 'package:soullocket_app/views/utilities/tarot/tarot_screen.dart';
import 'package:soullocket_app/views/utilities/utility_sticker_icon.dart';
import 'package:soullocket_app/views/utilities/utilities_config.dart';
import 'package:soullocket_app/views/utilities/voice_screen.dart';
// import 'package:soullocket_app/views/utilities/wheel/wheel_screen.dart';
import 'package:soullocket_app/views/utilities/wishlist_screen.dart';
import 'package:soullocket_app/utils/zodiac_utils.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';
import 'package:soullocket_app/utils/services/daily_quest_service.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/widgets/legacy_web_ui.dart';
import 'package:soullocket_app/utils/services/purchase_service.dart';
import 'package:soullocket_app/utils/services/admob_service.dart';
import 'package:soullocket_app/utils/app_cache_manager.dart';
import 'package:soullocket_app/utils/services/love_status_notification_service.dart';

import 'package:soullocket_app/views/home/love_insights_screen.dart';
import 'package:soullocket_app/views/home/milestones_screen.dart';
import 'dart:ui' as ui;

import '../../../widgets/lottie_async_loader.dart';
import '../../../core/fast_backdrop_filter.dart';
import 'package:soullocket_app/core/sl_countdown_shapes.dart';
import 'package:soullocket_app/core/sl_route.dart';
import 'package:soullocket_app/views/home/tabs/main_home/widgets/main_home_header_button.dart';

part 'main_home/widgets/main_home_dialogs.dart';
part 'main_home/widgets/main_home_soul_merge_sticker.dart';
part 'main_home/widgets/main_home_countdown_quick_customize_sheet.dart';
part '../widgets/main_home/main_home_hero_section.dart';
part 'main_home/widgets/main_home_quick_actions.dart';
part 'main_home/widgets/main_home_presence_section.dart';
part 'main_home/widgets/main_home_status_cards.dart';
part 'main_home/widgets/main_home_tool_slot_section.dart';
part 'main_home/widgets/main_home_support.dart';
part 'main_home/widgets/main_home_relationship_action.dart';
part 'main_home/widgets/main_home_map_card.dart';
part 'main_home/widgets/main_home_insight_card.dart';
part 'main_home/widgets/main_home_avatar_section.dart';
part 'main_home/widgets/main_home_quote_activity_card.dart';
part 'main_home/widgets/main_home_shortcut_dock.dart';
part 'main_home/widgets/main_home_fullscreen_layout.dart';
part 'main_home/controllers/main_home_formatters.dart';
part 'main_home/controllers/main_home_interactions.dart';
part 'main_home/controllers/main_home_listeners.dart';
part 'main_home/controllers/main_home_routing.dart';
part 'main_home/controllers/main_home_derived_state_helper.dart';
part 'main_home/controllers/main_home_load_controller.dart';
part 'main_home/controllers/main_home_media_warmup_controller.dart';
part 'main_home/controllers/main_home_presence_map_controller.dart';
part 'main_home/controllers/main_home_widget_sync_controller.dart';
part 'main_home/controllers/main_home_avatar_controller.dart';
part 'main_home/controllers/main_home_wish_tip_controller.dart';
part 'main_home/controllers/main_home_countdown_prefs_controller.dart';
part 'main_home/controllers/main_home_reaction_controller.dart';
part 'main_home/sections/main_home_body_section.dart';
part 'main_home/widgets/main_home_state_views.dart';
part '../widgets/main_home/hero/main_home_animated_wave_background.dart';
part '../widgets/main_home/hero/main_home_countdown_visual_spec.dart';
part '../widgets/main_home/hero/main_home_hero_badges.dart';
part '../widgets/main_home/hero/main_home_hero_countdown.dart';
part '../widgets/main_home/hero/main_home_hero_counters.dart';
part '../widgets/main_home/hero/main_home_hero_header.dart';
part 'main_home/models/main_home_models.dart';

class MainHomeTab extends StatefulWidget {
  final ValueNotifier<bool> isActiveListenable;
  final VoidCallback? onOpenSettings;
  final GlobalKey? firstGuideHeroKey;
  final GlobalKey? firstGuideSettingsKey;
  final ValueListenable<bool>? isSwipingListenable;

  const MainHomeTab({
    super.key,
    required this.isActiveListenable,
    this.onOpenSettings,
    this.firstGuideHeroKey,
    this.firstGuideSettingsKey,
    this.isSwipingListenable,
  });

  @override
  State<MainHomeTab> createState() => _MainHomeTabState();
}

class _MainHomeTabState extends State<MainHomeTab> with WidgetsBindingObserver {
  final ValueNotifier<bool> _showHighlightCardFirstTapHintNotifier =
      ValueNotifier(false);
  final ValueNotifier<bool> _showInsightCardFirstTapHintNotifier =
      ValueNotifier(false);
  final ValueNotifier<double> _avatarUploadProgressNotifier =
      ValueNotifier(-1.0);
  static const String _pendingAvatarUploadKeyPrefix = 'main_home_avatar_';
  static const String _mapCardFirstTapSeenPrefsKey =
      'il_home_map_card_first_tap_seen_v1';
  static const String _insightCardFirstTapSeenPrefsKey =
      'il_home_insight_card_first_tap_seen_v1';

  static const Duration _kCountdownQuickUnlockWindow = Duration(hours: 24);
  static const Set<String> _kCountdownQuickPremiumStyleKeys = {
    'deep_ocean',
    'golden_sunset',
    'neon_pulse',
  };
  static const Duration _kReactionThrowWindow = Duration(seconds: 10);
  static const int _kReactionThrowBurstLimit = 5;
  static const List<String> _kCountdownPressHoldTips = [
    '💡 Bấm giữ thẻ đếm ngược để mở nhanh bảng đổi giao diện & màu sắc!',
    '🎨 Bấm giữ đếm ngược để tùy chỉnh font chữ, hiệu ứng và màu sắc riêng!',
    '✨ Nhấn giữ thẻ đếm ngày để tùy biến đếm ngược theo phong cách của bạn!',
  ];

  bool _hideSettingsButtonUntilRestart = false;

  void _hideSettingsButtonForSession() {
    if (!mounted) return;
    final isCurrentlyHidden = _hideSettingsButtonUntilRestart;
    setState(() => _hideSettingsButtonUntilRestart = !isCurrentlyHidden);

    if (!isCurrentlyHidden) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Đã làm mờ nút cài đặt. Bạn vẫn có thể nhấn vào góc này để mở cài đặt, hoặc nhấn giữ để hiện lại.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
    }
  }

  String _resolveMyName() => _resolveNameForRole(_currentRole);

  Future<void> _deliverIncomingAlert(
    _MissYouAlertPayload payload, {
    String? removalPath,
  }) async {
    final prefs = await OfflineCacheService.getPrefs();
    final lastLocalMs = prefs.getInt('il_last_local_push_time_v2') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (nowMs - lastLocalMs >= 3600000) {
      await prefs.setInt('il_last_local_push_time_v2', nowMs);
      await _notificationService.showLocalNotification(
        title: payload.title,
        body: payload.body.isNotEmpty ? payload.body : payload.message,
        data: {
          'screen': 'home',
          'type': 'partner_care',
          'careType': payload.type,
          if (_houseId != null) 'houseId': _houseId,
        },
        dedupeKey:
            '${payload.fromUid}|${payload.fromRole}|${payload.sentAtMs}|${payload.type}|${payload.title}',
      );
    }
    if (!mounted) return;
    _showMissYouScreen(payload);
    if (removalPath != null) {
      unawaited(_dbRef.child(removalPath).remove().catchError((_) {}));
    }
  }

  int _calculateDays() {
    final dateStr = _houseSettings?['startDate'] ?? _houseSettings?['loveDate'];
    if (dateStr == null) return 0;
    try {
      final DateTime start = DateTime.parse(dateStr.toString());
      final DateTime now = DateTime.now();
      final DateTime current = DateTime(now.year, now.month, now.day);
      final int diff = current.difference(start).inDays;
      return diff < 0 ? 0 : diff + 1;
    } catch (e) {
      return 0;
    }
  }

  TextStyle _uiTextStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return SLTheme.textStyleForKey(
      UiPrefs.notifier.value.fontKey,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  List<Color> _profileAccentGradient(bool isUser1) {
    if (isUser1) {
      return const [Color(0xFF60A5FA), Color(0xFF2563EB)];
    }
    return const [Color(0xFFFF8FB1), Color(0xFFFF4D79)];
  }

  BoxDecoration _homeCardDecoration({double radius = 24}) {
    final tone = UiPrefs.notifier.value.homeBlockToneKey;
    final color = switch (tone) {
      'mist' => const Color(0xFFEEF4FF).withValues(alpha: 0.72),
      'rose' => const Color(0xFFFFE1EC).withValues(alpha: 0.68),
      'glass' => Colors.white.withValues(alpha: 0.14),
      _ => Colors.white.withValues(alpha: 0.82),
    };
    final borderColor = switch (tone) {
      'mist' => const Color(0xFFB8D4FF).withValues(alpha: 0.70),
      'rose' => const Color(0xFFFFA8C8).withValues(alpha: 0.65),
      'glass' => Colors.white.withValues(alpha: 0.28),
      _ => const Color(0xFFFFCEE0).withValues(alpha: 0.80),
    };
    final shadowColor = switch (tone) {
      'mist' => const Color(0xFF64B5F6).withValues(alpha: 0.12),
      'rose' => SLColors.primary.withValues(alpha: 0.14),
      'glass' => Colors.black.withValues(alpha: 0.18),
      _ => const Color(0xFFFF6DA0).withValues(alpha: 0.10),
    };

    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.60),
          blurRadius: 0,
          offset: const Offset(0, 0),
          spreadRadius: 0,
        ),
      ],
      border: Border.all(color: borderColor, width: 1.0),
    );
  }

  static final List<String> _kHomeStickerAssets =
      List<String>.generate(99, (i) {
    final num = (i + 1).toString().padLeft(3, '0');
    return 'assets/images/interaction_stickers/custom/numbered/sticker_$num.png';
  });

  static const List<String> _kGiftSuggestions = [
    '🎁 Handmade viết tay lời yêu thương',
    '💐 Một bó hoa tươi kèm thiệp nhỏ xinh',
    '🎂 Bất ngờ với bánh kem và nến lung linh',
    '🍫 Hộp socola tình yêu và một cái ôm thật chặt',
    '💍 Trang sức nhỏ xinh đính tên 2 đứa',
    '🧸 Thú bông ôm tay dễ thương to đùng',
    '🎫 Vé xem phim đôi hoặc concert cả 2 thích',
    '📸 Album ảnh kỷ niệm tự thiết kế',
    '🌹 Một bữa tối lãng mạn với đèn nến và hoa',
    '✈️ Chuyến đi chơi 2 ngày 1 đêm bất ngờ',
    '🛍️ Set quà chăm sóc da hoặc nước hoa',
    '🎧 Tai nghe bluetooth cùng playlist tặng riêng',
    '🖼️ Khung ảnh điện tử quay vòng kỷ niệm',
    '🌸 Cây cảnh nhỏ xinh để cùng chăm sóc',
    '☕ Bộ ly sứ đôi khắc tên 2 đứa',
    '🎮 Game hoặc boardgame có thể chơi cùng nhau',
    '🧦 Đồ đôi: áo, mũ hoặc vớ dễ thương',
    '📖 Cuốn sổ nhỏ ghi lại lời yêu mỗi ngày',
    '🎵 Đàn hộp nhỏ (ukulele) và bài hát tặng riêng',
    '🌟 Bộ đèn sao trần phòng ngủ lãng mạn',
  ];

  static String _giftSuggestionsForBirthday(int month, int day) {
    return 'Gợi ý quà: ${_kGiftSuggestions[(month + day) % _kGiftSuggestions.length]}';
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseService _houseService = HouseService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final LoveInsightService _insightService = LoveInsightService();
  final UtilityService _utilityService = UtilityService();
  final HouseSettingsService _houseSettingsService = HouseSettingsService();
  // final AlbumService _albumService = AlbumService();
  final NoteService _noteService = NoteService();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final LocationService _locationService = LocationService();
  final Random _random = Random();
  DateTime? _lastFetchTime;
  static const Duration _fetchCacheDuration = Duration(seconds: 30);

  Map<String, dynamic>? _houseSettings;
  Map<String, dynamic> _presenceDataMap = {};
  final ValueNotifier<Map<String, dynamic>> _presenceDataNotifier =
      ValueNotifier<Map<String, dynamic>>({});
  Map<String, dynamic> get _presenceData => _presenceDataMap;
  set _presenceData(Map<String, dynamic> v) => _presenceDataMap = v;
  bool _hasLoadedPresenceSnapshot = false;
  bool _isLoading = true;
  bool _showStatus = true;
  bool _showWeather = true;
  String? _houseId;
  String _currentRole = 'user1';
  List<UtilityApp> _pinnedApps = const [];
  late final Stream<DateTime> _secondStream = Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  ).asBroadcastStream();
  String? _uploadingAvatarRole;
  bool _didPromptPendingAvatarRetry = false;
  final ValueNotifier<String> _homeDistanceTextNotifier =
      ValueNotifier<String>('Đang định vị...');
  final ValueNotifier<String?> _homeMapAlertNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<Map<String, dynamic>?> _homePartnerBatteryNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<Map<String, dynamic>?> _homeMyBatteryNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<bool> _isScrollingNotifier = ValueNotifier<bool>(false);
  int _wishIndex = -1;
  int _tipIndex = -1;
  Timer? _weatherRefreshTimer;
  Timer? _loveWidgetSyncDebounce;

  Timer? _incomingInteractionDialogTimer;
  Timer? _fallbackTimeoutTimer;
  Timer? _delayedListenersTimer;
  Timer? _delayedMapWeatherTimer;
  Timer? _presenceSnapshotFallbackTimer;
  Timer? _calendarWidgetSyncDebounce;
  Timer? _healthCycleWidgetSyncDebounce;
  Timer? _fetchHouseDataDebounceTimer;
  Future<void>? _activeFetchFuture;
  StreamSubscription? _settingsSubscription;
  StreamSubscription? _presenceSubscription;
  final List<StreamSubscription> _presenceSubList = [];
  StreamSubscription? _missInteractionSubscription;
  StreamSubscription<DatabaseEvent>? _alertSubscription;
  StreamSubscription<DatabaseEvent>? _newDeviceNotificationSubscription;
  StreamSubscription<DatabaseEvent>? _partnerInboxSubscription;
  StreamSubscription? _albumSubscription;
  StreamSubscription? _noteSubscription;
  StreamSubscription<DatabaseEvent>? _chatSignalSubscription;
  StreamSubscription<DatabaseEvent>? _reactionFlightSubscription;
  StreamSubscription? _gpsSubscription;

  LoveInsightData? _insightData;
  // ignore: prefer_final_fields
  final List<dynamic> _albumHighlights = [];
  List<SharedNote> _noteHighlights = [];
  StreamSubscription<DatabaseEvent>? _homeCalendarSubscription;
  StreamSubscription<DatabaseEvent>? _healthCycleSyncSubscription;
  List<Map<String, dynamic>> _homeCalendarEvents = [];

  String? _selectedHomeToolId;
  late final ValueNotifier<List<_HomeReactionFlight>> _reactionFlightsNotifier;
  final Set<String> _seenReactionFlightIds = <String>{};
  final List<int> _localReactionThrowMs = <int>[];
  bool _isCoupleConnected = false;

  String? _lastMissEventFingerprint;
  int _lastMissEventShownAt = 0;
  bool _weatherSyncInFlight = false;
  final Map<String, String?> _weatherReverseGeocodeCache = <String, String?>{};
  final Map<String, int> _weatherReverseGeocodeCacheTs = <String, int>{};
  final Map<String, Future<String?>> _weatherReverseGeocodeInFlight =
      <String, Future<String?>>{};
  Timer? _interactionRotationTimer;
  final List<String> _rotationQueue = [];
  Map<String, dynamic>? _pendingWidgetSettings;
  bool _pendingWidgetSyncIncludeDiaryMedia = false;
  bool _widgetSyncInFlight = false;
  String _lastLoveWidgetSignature = '';
  String _lastLoveWidgetAccountKey = '';
  String _presenceUiSignature = '';
  String _homeMapPreviewSignature = '';
  String? _lastInsightSettingsKey;
  String? _pendingInsightSettingsKey;
  int _insightRequestSerial = 0;
  int _liveWorkSessionId = 0;
  List<String> _cachedWidgetDiaryImageUrls = const <String>[];
  List<String> _recentChatSignals = [];
  int _lastChatMessageTs = 0; // timestamp ms của tin nhắn chat cuối cùng
  late final ValueNotifier<_PartnerInteractionPreset>
      _smartInteractionPresetNotifier;
  _PartnerInteractionPreset get _smartInteractionPreset =>
      _smartInteractionPresetNotifier.value;
  set _smartInteractionPreset(_PartnerInteractionPreset v) =>
      _smartInteractionPresetNotifier.value = v;
  bool _showDefaultHeartSuggestion = false;
  String? _manualInteractionPresetType;
  bool _isSendingInteraction = false;
  bool _incomingInteractionDialogVisible = false;
  final List<_MissYouAlertPayload> _incomingInteractionQueue =
      <_MissYouAlertPayload>[];
  OverlayEntry? _interactionDragOverlayEntry;
  final Map<String, GlobalKey> _interactionDragOptionKeys =
      <String, GlobalKey>{};
  final Map<String, Rect> _interactionDragOptionRects = <String, Rect>{};
  final Map<String, Rect> _interactionDragOptionHitRects = <String, Rect>{};
  List<_PartnerInteractionPreset> _interactionDragMenuOptions =
      const <_PartnerInteractionPreset>[];
  String? _interactionDragHoveredType;
  final ValueNotifier<String?> _interactionDragHoveredNotifier =
      ValueNotifier<String?>(null);
  Offset? _interactionDragPointerGlobal;
  bool _isTabActive = false;
  bool _showMapCardFirstTapHint = !(OfflineCacheService.getPrefsSync()
          ?.getBool(_mapCardFirstTapSeenPrefsKey) ??
      false);
  bool _showInsightCardFirstTapHint = !(OfflineCacheService.getPrefsSync()
          ?.getBool(_insightCardFirstTapSeenPrefsKey) ??
      false);
  String _lastHomeSettingsPayloadSignature = '';
  String _lastWidgetSettingsSyncKey = '';
  final ValueNotifier<String> _fallingEffectTypeNotifier =
      ValueNotifier<String>('off');
  bool _deferHeavyHomeMotion = false;
  int _homeMediaWarmupToken = 0;
  final Set<String> _seenNewDeviceNotificationIds = <String>{};
  String _lastHomeMediaWarmupSignature = '';

  StreamSubscription? _membersSubscription;

  static const Duration _kHomeMotionWarmupDelay = Duration(milliseconds: 650);

  bool get _showLegacyMessengerButton => false;
  String get _partnerRole => _currentRole == 'user1' ? 'user2' : 'user1';

  Map<String, dynamic> _buildDefaultHomeSettings() {
    return {
      'houseName': 'Ngôi Nhà Của Tôi',
      'startDate': DateTime.now().toIso8601String().split('T')[0],
      'nameU1': 'Bạn',
      'nameU2': 'Người ấy',
      'relationshipMode': 'couple',
    };
  }

  // Tính số ngày yêu hoặc ngày từ lúc bắt đầu
  String _homeSettingsCacheKey(String houseId) {
    final normalized = houseId.trim();
    if (normalized.isEmpty) return 'home_settings';
    return 'home_settings_$normalized';
  }

  bool get _hasWarmHomeSnapshot =>
      (_houseId?.trim().isNotEmpty ?? false) && _houseSettings != null;

  Future<void> _loadCustomStickers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final preset in _kPartnerInteractionPresets) {
        final customPath = prefs.getString('custom_sticker_${preset.type}');
        if (customPath != null && customPath.isNotEmpty) {
          preset.assetPath = customPath;
        }
      }
    } catch (_) {}
  }

  _PartnerInteractionPreset get _displayInteractionPreset {
    final manualType = _manualInteractionPresetType;
    if (manualType != null) {
      final manualPreset = _maybePresetForInteractionType(manualType);
      if (manualPreset != null) {
        return manualPreset;
      }
    }
    return _smartInteractionPreset;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadCustomStickers());
    WidgetsBinding.instance.addObserver(this);
    _isTabActive = widget.isActiveListenable.value;
    widget.isActiveListenable.addListener(_onActiveChanged);
    _reactionFlightsNotifier = ValueNotifier<List<_HomeReactionFlight>>([]);
    _smartInteractionPresetNotifier = ValueNotifier<_PartnerInteractionPreset>(
        _defaultSmartInteractionPreset());
    unawaited(() async {
      try {
        final selectedUiFont = SLTheme.textStyleForKey(
          UiPrefs.notifier.value.fontKey,
        );
        await GoogleFonts.pendingFonts([
          GoogleFonts.comfortaa(fontWeight: FontWeight.w900),
          selectedUiFont,
        ]);
      } catch (_) {}
    }());
    // Pre-cache sticker assets deferred and chunked to avoid startup stutter
    Timer(const Duration(seconds: 4), () async {
      if (!mounted) return;
      for (var i = 0; i < _kHomeStickerAssets.length; i++) {
        if (!mounted) break;
        precacheImage(AssetImage(_kHomeStickerAssets[i]), context);
        // Chia nhỏ mỗi đợt 10 ảnh, nghỉ 50ms để không block UI thread
        if (i % 10 == 9) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    });
    unawaited(_syncHomeCardFirstTapHintState());
    _restoreWarmHomeCache();
    _warmHomeMedia(
      delayMotion: true,
      force: _hasWarmHomeSnapshot,
    );

    unawaited(
      _fetchHouseData(
        preserveVisibleState: _hasWarmHomeSnapshot,
        preloadOnly: !_isTabActive,
      ),
    );
    unawaited(_promptPendingAvatarRetryIfNeeded());
    unawaited(PurchaseService().getVipAccessInfo().catchError((_) =>
        const VipAccessInfo(isVip: false, planId: '', expiresAtMs: null)));
  }

  void _onActiveChanged() {
    if (!mounted) return;
    final nextActive = widget.isActiveListenable.value;
    if (_isTabActive != nextActive) {
      _handleTabActivityChanged(nextActive);
    }
  }

  @override
  void didUpdateWidget(covariant MainHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveListenable != widget.isActiveListenable) {
      oldWidget.isActiveListenable.removeListener(_onActiveChanged);
      widget.isActiveListenable.addListener(_onActiveChanged);
      final nextActive = widget.isActiveListenable.value;
      if (_isTabActive != nextActive) {
        _handleTabActivityChanged(nextActive);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.isActiveListenable.removeListener(_onActiveChanged);
    _invalidateLiveWorkSession();
    _cancelLiveWorkBindings();
    _fetchHouseDataDebounceTimer?.cancel();

    // Explicitly cancel subscriptions in dispose to satisfy linter rule 'cancel_subscriptions'
    for (final sub in _presenceSubList) {
      sub.cancel();
    }
    _presenceSubList.clear();
    _settingsSubscription?.cancel();
    _presenceSubscription?.cancel();
    _missInteractionSubscription?.cancel();
    _alertSubscription?.cancel();
    _newDeviceNotificationSubscription?.cancel();
    _partnerInboxSubscription?.cancel();
    _albumSubscription?.cancel();
    _noteSubscription?.cancel();
    _homeCalendarSubscription?.cancel();
    _healthCycleSyncSubscription?.cancel();
    _chatSignalSubscription?.cancel();
    _reactionFlightSubscription?.cancel();
    _gpsSubscription?.cancel();
    _membersSubscription?.cancel();

    _homeMediaWarmupToken++;

    _interactionDragHoveredNotifier.dispose();
    _reactionFlightsNotifier.dispose();
    _smartInteractionPresetNotifier.dispose();
    _presenceDataNotifier.dispose();
    _homeDistanceTextNotifier.dispose();
    _homeMapAlertNotifier.dispose();
    _homePartnerBatteryNotifier.dispose();
    _fallingEffectTypeNotifier.dispose();
    _isScrollingNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isTabActive &&
        _houseId != null) {
      unawaited(_ensureAppWideLocationTracking(_houseId!));
      unawaited(_refreshCurrentRoleWeather());
    }
  }

  void _handleTabActivityChanged(bool isActive) {
    _isTabActive = isActive;
    if (isActive) {
      _deferHeavyHomeMotion = true;
      _warmHomeMedia(delayMotion: true);
      // ⚡ Skip re-fetch if data is still fresh (< 30s old)
      final dataIsFresh = _lastFetchTime != null &&
          DateTime.now().difference(_lastFetchTime!) <= _fetchCacheDuration;
      if (dataIsFresh) return;
      // ⚡ Debounce fetch until after swipe animation (~300ms) + warmup settle (650ms).
      //    700ms gives enough breathing room so the UI thread is free during animation.
      _fetchHouseDataDebounceTimer?.cancel();
      _fetchHouseDataDebounceTimer =
          Timer(const Duration(milliseconds: 700), () {
        if (!mounted || !_isTabActive) return;
        unawaited(
          _fetchHouseData(
            preserveVisibleState: true,
          ),
        );
      });
      return;
    }
    // Do not cancel Firebase RTDB bindings here (keep them connected to avoid tearing down and re-fetching on tab switch).
    // Instead, we only pause non-critical active loops if any, but weather loop and presence check and update will
    // automatically adapt based on _isTabActive inside their respective timers/listeners.
    _fetchHouseDataDebounceTimer?.cancel();
    _invalidateLiveWorkSession();
  }

  /// Bọc setup listener trong try-catch để tránh crash dây chuyền nếu 1 listener fail
  void _wrapSetup(VoidCallback fn, String label) {
    try {
      fn();
    } catch (e, st) {
      debugPrint('[HomeSetup] $label listener setup failed: $e\n$st');
    }
  }

  Future<void> _syncHomeCardFirstTapHintState() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final nextMapVisible =
        !(prefs.getBool(_mapCardFirstTapSeenPrefsKey) ?? false);
    final nextInsightVisible =
        !(prefs.getBool(_insightCardFirstTapSeenPrefsKey) ?? false);

    if (!mounted) {
      _showMapCardFirstTapHint = nextMapVisible;
      _showInsightCardFirstTapHint = nextInsightVisible;
      return;
    }

    if (nextMapVisible == _showMapCardFirstTapHint &&
        nextInsightVisible == _showInsightCardFirstTapHint) {
      return;
    }

    _safeSetState(() {
      _showMapCardFirstTapHint = nextMapVisible;
      _showInsightCardFirstTapHint = nextInsightVisible;
    });
  }

  Future<void> _markHomeCardFirstTapSeen({required bool isMapCard}) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final prefsKey = isMapCard
        ? _mapCardFirstTapSeenPrefsKey
        : _insightCardFirstTapSeenPrefsKey;

    if (mounted) {
      _safeSetState(() {
        if (isMapCard) {
          _showMapCardFirstTapHint = false;
        } else {
          _showInsightCardFirstTapHint = false;
        }
      });
    } else if (isMapCard) {
      _showMapCardFirstTapHint = false;
    } else {
      _showInsightCardFirstTapHint = false;
    }

    await prefs.setBool(prefsKey, true);
  }

  Future<void> _handleMapCardTap() async {
    await _markHomeCardFirstTapSeen(isMapCard: true);
    await _openMapScreen();
  }

  Future<void> _handleInsightCardTap() async {
    await _markHomeCardFirstTapSeen(isMapCard: false);
    _openLoveInsights();
  }

  Set<String> _homeSearchableUtilityIds() {
    final ids = <String>{};
    for (final app in UtilityService.appsForMode(_relationshipMode)) {
      if (_buildEmbeddedHomeTool(app.id) != null) {
        ids.add(app.id);
      }
    }
    return ids;
  }

  Future<void> _openSearchResultDestination(dynamic result) async {
    final action = result.actionId as String;
    if (action == 'history') {
      await Navigator.of(context).push(
        SLRoute(
          builder: (_) => HistoryScreen(houseId: _houseId ?? ''),
        ),
      );
      return;
    }

    if (action.startsWith('utility:')) {
      final utilityId = action.substring('utility:'.length);
      final tool = _buildEmbeddedHomeTool(utilityId);
      if (tool == null) {
        return;
      }
      await Navigator.of(context).push(
        SLRoute(builder: (_) => tool),
      );
    }
  }

  int _invalidateLiveWorkSession() => _invalidateLiveWorkSessionImpl();

  void _cancelLiveWorkBindings() {
    _cancelLiveWorkBindingsImpl();
  }

  void _showLatestSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
        ),
      );
  }

  String _presenceRoleUiSignature(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return 'none';
    }

    final online = PresenceService.isPresenceOnline(data);
    final weatherRaw = data['weather'];
    var weatherSignature = '';
    if (weatherRaw is Map) {
      final weather = _toStringDynamicMap(weatherRaw);
      final temp = _readDouble(weather['temp'])?.round();
      final condition = weather['cond']?.toString().trim() ?? '';
      weatherSignature = '${temp ?? ''}|$condition';
    }

    if (online) {
      return 'on|$weatherSignature';
    }

    final lastSeen = _readEpochMs(data['lastSeen']) ?? -1;
    return 'off|$lastSeen|$weatherSignature';
  }

  String _presenceUiSignatureForPayload(Map<String, dynamic> payload) {
    String roleSignature(String role) {
      final raw = payload[role];
      if (raw is! Map) {
        return '$role:none';
      }
      return '$role:${_presenceRoleUiSignature(_toStringDynamicMap(raw))}';
    }

    return '${roleSignature('user1')}|${roleSignature('user2')}';
  }

  void _updatePresenceData(Map<String, dynamic> nextPresence) {
    _updatePresenceDataImpl(nextPresence);
  }

  void _updateHomeMapPreview({
    required String distanceText,
    required String? alertText,
  }) {
    _updateHomeMapPreviewImpl(
      distanceText: distanceText,
      alertText: alertText,
    );
  }

  dynamic _normalizeInsightSignatureValue(dynamic value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, dynamic>{
        for (final entry in entries)
          entry.key.toString(): _normalizeInsightSignatureValue(entry.value),
      };
    }
    if (value is List) {
      return value
          .map<dynamic>(_normalizeInsightSignatureValue)
          .toList(growable: false);
    }
    return value;
  }

  String _buildInsightSettingsKey(
    Map<String, dynamic> settings,
    String relationshipMode,
  ) {
    return _buildInsightSettingsKeyImpl(settings, relationshipMode);
  }

  String _buildCanonicalSettingsPayloadSignature(
      Map<String, dynamic> settings) {
    return _buildCanonicalSettingsPayloadSignatureImpl(settings);
  }

  String _buildWidgetSettingsSyncKey(Map<String, dynamic> settings) {
    return _buildWidgetSettingsSyncKeyImpl(settings);
  }

  Future<void> _refreshHomeInsights({
    required String houseId,
    required String relationshipMode,
    required String settingsKey,
  }) {
    return _refreshHomeInsightsImpl(
      houseId: houseId,
      relationshipMode: relationshipMode,
      settingsKey: settingsKey,
    );
  }

  Future<void> _fetchHouseData({
    bool preserveVisibleState = false,
    bool preloadOnly = false,
  }) {
    if (_activeFetchFuture != null) {
      return _activeFetchFuture!;
    }
    final future = _fetchHouseDataImpl(
      preserveVisibleState: preserveVisibleState,
      preloadOnly: preloadOnly,
    );
    _activeFetchFuture = future;
    return future.then((_) {
      _activeFetchFuture = null;
    }, onError: (_) {
      _activeFetchFuture = null;
    });
  }

  String _zodiacAndAgeForRole(String role) {
    return _zodiacAndAgeForRoleImpl(role);
  }

  int _widgetMemoryOrderValue(dynamic raw) {
    return _widgetMemoryOrderValueImpl(raw);
  }

  List<({int order, String url})> _widgetDiaryImageEntriesFromRaw(dynamic raw) {
    return _widgetDiaryImageEntriesFromRawImpl(raw);
  }

  Future<List<String>> _loadWidgetDiaryImageUrls(String houseId) {
    return _loadWidgetDiaryImageUrlsImpl(houseId);
  }

  Future<
      ({
        String bgTheme,
        bool showDiaryOnWidget,
        bool heartAnimated,
        String heartStyleKey,
        String heartColorKey,
        String diaryLayoutKey,
        String seasonModeKey,
        String widgetStyleKey,
      })> _loadWidgetAppearancePrefs(String houseId) {
    return _loadWidgetAppearancePrefsImpl(houseId);
  }

  String _widgetAccountKey(String houseId) {
    return _widgetAccountKeyImpl(houseId);
  }

  void _scheduleLoveWidgetSync(
    Map<String, dynamic> settings, {
    required bool includeDiaryMedia,
  }) {
    _scheduleLoveWidgetSyncImpl(
      settings,
      includeDiaryMedia: includeDiaryMedia,
    );
  }

  Future<void> _syncLoveWidget(
    Map<String, dynamic> settings, {
    bool includeDiaryMedia = false,
  }) {
    return _syncLoveWidgetImpl(
      settings,
      includeDiaryMedia: includeDiaryMedia,
    );
  }

  Future<void> _cleanupOldReactionFlights(String houseId) async {
    try {
      final cutoff = DateTime.now().millisecondsSinceEpoch -
          const Duration(minutes: 2).inMilliseconds;
      final snapshot = await _dbRef
          .child('houses/$houseId/reaction_flights')
          .orderByChild('sentAt')
          .endAt(cutoff)
          .limitToFirst(30)
          .get();
      final raw = snapshot.value;
      if (raw is! Map) return;

      final updates = <String, Object?>{};
      for (final key in raw.keys) {
        updates['houses/$houseId/reaction_flights/${key.toString()}'] = null;
      }
      if (updates.isNotEmpty) {
        await _dbRef.update(updates);
      }
    } catch (_) {}
  }

  String _normalizeInteractionSignal(String input) {
    var normalized = input.toLowerCase();
    const accentGroups = {
      r'[àáạảãâầấậẩẫăằắặẳẵ]': 'a',
      r'[èéẹẻẽêềếệểễ]': 'e',
      r'[ìíịỉĩ]': 'i',
      r'[òóọỏõôồốộổỗơờớợởỡ]': 'o',
      r'[ùúụủũưừứựửữ]': 'u',
      r'[ỳýỵỷỹ]': 'y',
      r'[đ]': 'd',
    };
    accentGroups.forEach((pattern, replacement) {
      normalized = normalized.replaceAll(RegExp(pattern), replacement);
    });
    return normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
  }

  int _signalMatches(String haystack, List<String> keywords) {
    return keywords.where((keyword) {
      final pattern = RegExp(
        '(^|\\s)${RegExp.escape(keyword)}(?=\\s|\$)',
        caseSensitive: false,
      );
      return pattern.hasMatch(haystack);
    }).length;
  }

  _PartnerInteractionPreset _pickSmartInteractionPresetFromSignals({
    bool avoidCurrent = false,
  }) {
    final signalParts = <String>[
      ..._recentChatSignals,
      ..._noteHighlights.take(6).expand(
            (item) => [
              item.title,
              item.content,
            ],
          ),
    ];
    final haystack = _normalizeInteractionSignal(signalParts.join(' '));
    final weights = <String, double>{
      for (final preset in _kPartnerInteractionPresets)
        preset.type: preset.weight.toDouble(),
    };

    weights['angry'] = 3;
    weights['tease'] = 6;

    final affectionMatches = _signalMatches(haystack, [
      'yeu',
      'thuong',
      'nho',
      'hon',
      'hun',
      'kiss',
      'iu',
      'nho em',
      'nho anh',
      'nho ban',
    ]);
    final supportMatches = _signalMatches(haystack, [
      'buon',
      'met',
      'stress',
      'khoc',
      'co len',
      'on khong',
      'om',
      'mong on',
      'thuong qua',
    ]);
    final playfulMatches = _signalMatches(haystack, [
      'haha',
      'hihi',
      'hehe',
      'cuoi',
      'dua',
      'treu',
      'troll',
      'meme',
      'lol',
      'kkk',
    ]);
    final conflictMatches = _signalMatches(haystack, [
      'gian',
      'doi',
      'bun',
      'tuc',
      'bo mac',
      'lang nhang',
      'sao khong',
    ]);

    weights['miss'] = (weights['miss'] ?? 0) + affectionMatches * 5;
    weights['kiss'] = (weights['kiss'] ?? 0) + affectionMatches * 4;
    weights['hug'] = (weights['hug'] ?? 0) + supportMatches * 7;
    weights['miss'] = (weights['miss'] ?? 0) + supportMatches * 2;
    weights['tease'] = (weights['tease'] ?? 0) + playfulMatches * 4;
    weights['kiss'] = (weights['kiss'] ?? 0) + playfulMatches * 1.5;
    weights['angry'] = (weights['angry'] ?? 0) + conflictMatches * 2;
    weights['hug'] = (weights['hug'] ?? 0) + conflictMatches * 2.5;

    if (supportMatches > 0) {
      weights['angry'] = 1;
    }

    weights['angry'] = (weights['angry'] ?? 1).clamp(1, 8).toDouble();
    weights['tease'] = (weights['tease'] ?? 1).clamp(2, 10).toDouble();

    final availablePresets = _kPartnerInteractionPresets.where((preset) {
      if (!preset.showInSmartSuggestion) return false;
      if (!avoidCurrent) return true;
      if (preset.type != _smartInteractionPreset.type) return true;
      return _kPartnerInteractionPresets
              .where((item) => item.showInSmartSuggestion)
              .length ==
          1;
    }).toList();

    final totalWeight = availablePresets.fold<double>(
      0,
      (acc, preset) => acc + (weights[preset.type] ?? 1),
    );
    if (totalWeight <= 0) {
      return availablePresets.isNotEmpty
          ? availablePresets.first
          : _defaultSmartInteractionPreset();
    }

    var cursor = _random.nextDouble() * totalWeight;
    for (final preset in availablePresets) {
      cursor -= weights[preset.type] ?? 1;
      if (cursor <= 0) {
        return preset;
      }
    }
    return availablePresets.isNotEmpty
        ? availablePresets.last
        : _defaultSmartInteractionPreset();
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  bool _sameAlbumHighlights(List<dynamic> left, List<dynamic> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      final l = left[index];
      final r = right[index];
      if (l.id != r.id ||
          l.timestamp != r.timestamp ||
          l.thumbUrl != r.thumbUrl ||
          l.url != r.url ||
          l.caption != r.caption ||
          l.authorName != r.authorName) {
        return false;
      }
    }
    return true;
  }

  bool _sameNoteHighlights(List<SharedNote> left, List<SharedNote> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      final l = left[index];
      final r = right[index];
      if (l.id != r.id ||
          l.updatedAt != r.updatedAt ||
          l.title != r.title ||
          l.content != r.content ||
          l.isPinned != r.isPinned) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _toStringDynamicMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return {};
  }

  int? _readEpochMs(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) {
      if (raw.isNaN || raw.isInfinite) return null;
      return raw.toInt();
    }
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  double? _readDouble(dynamic raw) {
    double? result;
    if (raw is num) {
      result = raw.toDouble();
    } else if (raw is String) {
      result = double.tryParse(raw);
    }
    if (result != null && (result.isNaN || result.isInfinite)) return null;
    return result;
  }

  String _resolveNameForRole(String role) {
    final field = role == 'user1' ? 'nameU1' : 'nameU2';
    final name = _houseSettings?[field]?.toString().trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return role == 'user1' ? 'Nam' : 'Nữ';
  }







  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeDataController()),
        ChangeNotifierProvider(create: (_) => HomePresenceController()),
        ChangeNotifierProvider(create: (_) => HomeInteractionController()),
      ],
      child: _MainHomeStateView(
        isLoading: _isLoading,
        hasVisibleContent: _houseSettings != null,
        child: ValueListenableBuilder<UiPrefsState>(
          valueListenable: UiPrefs.notifier,
          builder: (context, uiState, _) => Stack(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: widget.isActiveListenable,
                builder: (context, isActive, _) {
                  if (!isActive) return const SizedBox.shrink();
                  return const SizedBox.shrink();
                },
              ),
              _buildMainContent(
                customBackgroundUrl: uiState.customBackgroundUrl,
              ),
              const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent({
    required String customBackgroundUrl,
  }) {
    return _buildMainContentSection(
      context,
      customBackgroundUrl: customBackgroundUrl,
    );
  }


}

class _ThemeBackgroundAspectRatioPreset implements CropAspectRatioPresetData {
  const _ThemeBackgroundAspectRatioPreset();

  @override
  String get name => 'house_background_9x16';

  @override
  (int ratioX, int ratioY)? get data => (9, 16);
}

class HomeUpcomingEvent {
  final String title;
  final DateTime date;
  final String type; // 'calendar' | 'anniversary' | 'birthday' | 'holiday'

  HomeUpcomingEvent({
    required this.title,
    required this.date,
    required this.type,
  });
}
