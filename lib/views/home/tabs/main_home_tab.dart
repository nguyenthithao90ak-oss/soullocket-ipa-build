// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'package:flutter/material.dart';
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
import 'package:soullocket_app/utils/services/album_service.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';
import 'package:soullocket_app/utils/services/storage_service.dart';
import 'package:soullocket_app/utils/services/utilities/note_service.dart';
import 'package:soullocket_app/utils/services/pending_upload_service.dart';
import 'package:soullocket_app/utils/sl_notice.dart';
import 'package:soullocket_app/models/album_item.dart';
import 'package:soullocket_app/models/house_settings.dart';
import 'package:soullocket_app/models/utilities/shared_note.dart';
import 'package:soullocket_app/views/home/tabs/settings_tab.dart'
    show SettingsTab, FloatingHeartsRingOverlay;
import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:soullocket_app/views/utilities/age_zodiac_screen.dart';
import 'package:soullocket_app/views/utilities/bucket_list_screen.dart';
import 'package:soullocket_app/views/utilities/calendar_screen.dart';
import 'package:soullocket_app/views/utilities/capsule_screen.dart';
import 'package:soullocket_app/views/utilities/cinema_screen.dart';
import 'package:soullocket_app/views/utilities/collage_maker_screen.dart';
import 'package:soullocket_app/views/utilities/creative_diary_screen.dart';
import 'package:soullocket_app/views/utilities/drawing_studio_screen.dart';
import 'package:soullocket_app/views/utilities/finance_screen.dart';
import 'package:soullocket_app/views/utilities/friendly_chat_screen.dart';
import 'package:soullocket_app/views/utilities/gift_maker_screen.dart';
import 'package:soullocket_app/views/utilities/giftcode_screen.dart';
import 'package:soullocket_app/views/utilities/habit_screen.dart';
import 'package:soullocket_app/views/utilities/love_card_screen.dart';
import 'package:soullocket_app/views/utilities/reward_store_screen.dart';
import 'package:soullocket_app/views/utilities/secret_vault_screen.dart';
import 'package:soullocket_app/views/utilities/shared_notes_screen.dart';
import 'package:soullocket_app/views/utilities/calculator_screen.dart';
import 'package:soullocket_app/views/utilities/diary_export_screen.dart';
import 'package:soullocket_app/views/utilities/history_screen.dart';
import 'package:soullocket_app/features/tarot/tarot_screen.dart';
import 'package:soullocket_app/views/utilities/utility_sticker_icon.dart';
import 'package:soullocket_app/views/utilities/utilities_config.dart';
import 'package:soullocket_app/views/utilities/voice_screen.dart';
import 'package:soullocket_app/features/wheel/wheel_screen.dart';
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

import 'package:soullocket_app/views/home/love_insights_screen.dart';
import 'package:soullocket_app/views/home/milestones_screen.dart';
import 'dart:ui' as ui;

import '../../../widgets/lottie_async_loader.dart';
import '../../../core/fast_backdrop_filter.dart';
import 'package:soullocket_app/core/sl_route.dart';
import 'package:soullocket_app/views/home/tabs/main_home/widgets/main_home_header_button.dart';

part 'main_home/widgets/main_home_dialogs.dart';
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
part 'main_home/controllers/main_home_formatters.dart';
part 'main_home/controllers/main_home_interactions.dart';
part 'main_home/controllers/main_home_listeners.dart';
part 'main_home/controllers/main_home_routing.dart';
part 'main_home/controllers/main_home_derived_state_helper.dart';
part 'main_home/controllers/main_home_load_controller.dart';
part 'main_home/controllers/main_home_media_warmup_controller.dart';
part 'main_home/controllers/main_home_presence_map_controller.dart';
part 'main_home/controllers/main_home_widget_sync_controller.dart';
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
  static const String _pendingAvatarUploadKeyPrefix = 'main_home_avatar_';
  static const String _mapCardFirstTapSeenPrefsKey =
      'il_home_map_card_first_tap_seen_v1';
  static const String _insightCardFirstTapSeenPrefsKey =
      'il_home_insight_card_first_tap_seen_v1';

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
  final AlbumService _albumService = AlbumService();
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
  double? _avatarUploadProgress;
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
  bool _hideSettingsButtonUntilRestart = false;
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
  List<AlbumItem> _albumHighlights = [];
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

  bool _sameAlbumHighlights(List<AlbumItem> left, List<AlbumItem> right) {
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

  Future<XFile?> _cropAvatarImage(
    XFile file, {
    required bool isUser1,
  }) async {
    if (kIsWeb || file.path.isEmpty) {
      return file;
    }

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isUser1 ? 'Cắt avatar bạn nam' : 'Cắt avatar người ấy',
            toolbarColor: const Color(0xFFD81B60),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: isUser1 ? 'Cắt avatar bạn nam' : 'Cắt avatar người ấy',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) {
        return null;
      }
      return XFile(croppedFile.path);
    } catch (_) {
      return file;
    }
  }

  String _pendingAvatarUploadKeyForHouse(String houseId) =>
      '$_pendingAvatarUploadKeyPrefix$houseId';

  Future<void> _promptPendingAvatarRetryIfNeeded() async {
    if (_didPromptPendingAvatarRetry || !mounted) {
      return;
    }
    final houseId =
        (_houseId ?? await _houseService.getCurrentHouseId())?.trim();
    if (houseId == null || houseId.isEmpty) {
      return;
    }
    final pending = await PendingUploadService.instance.load(
      _pendingAvatarUploadKeyForHouse(houseId),
    );
    if (pending == null || !mounted) {
      return;
    }
    _didPromptPendingAvatarRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Lần đổi avatar trang chủ trước đã bị gián đoạn.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Thử lại',
            onPressed: () {
              unawaited(_retryPendingAvatarUpload());
            },
          ),
        ),
      );
    });
  }

  Future<void> _retryPendingAvatarUpload() async {
    final houseId =
        (_houseId ?? await _houseService.getCurrentHouseId())?.trim();
    if (houseId == null || houseId.isEmpty) {
      return;
    }
    final pendingKey = _pendingAvatarUploadKeyForHouse(houseId);
    final pending = await PendingUploadService.instance.load(pendingKey);
    if (pending == null || !mounted) {
      return;
    }
    final role = pending['role']?.toString().trim() ?? '';
    final filePath = pending['filePath']?.toString().trim() ?? '';
    if (filePath.isEmpty) {
      await PendingUploadService.instance.clear(pendingKey);
      return;
    }
    final file = XFile(filePath);
    try {
      if (await file.length() <= 0) {
        await PendingUploadService.instance.clear(pendingKey);
        return;
      }
    } catch (_) {
      await PendingUploadService.instance.clear(pendingKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy ảnh avatar cũ để thử lại.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await _changeAvatar(
      isUser1: role != 'user2',
      presetFile: file,
    );
  }

  Future<void> _changeAvatar({
    required bool isUser1,
    XFile? presetFile,
  }) async {
    final houseId = _houseId ?? await _houseService.getCurrentHouseId();
    if (!mounted || houseId == null) return;
    if (_uploadingAvatarRole != null) return;

    XFile? file;
    try {
      file = presetFile ?? await _storageService.pickImage();
    } catch (e) {
      if (mounted) SLNotice.showInfo(context, 'Lỗi chọn ảnh: $e');
    }
    if (file == null) return;
    if (!mounted) return;

    final role = isUser1 ? 'user1' : 'user2';
    final field = isUser1 ? 'avtUser1' : 'avtUser2';
    final pendingKey = _pendingAvatarUploadKeyForHouse(houseId);
    setState(() {
      _uploadingAvatarRole = role;
      _avatarUploadProgress = 0.0;
    });

    try {
      if (presetFile == null) {
        file = await _cropAvatarImage(file, isUser1: isUser1);
      }
      if (file == null) {
        return;
      }
      await PendingUploadService.instance.save(pendingKey, <String, dynamic>{
        'role': role,
        'filePath': file.path,
      });

      final upload = await _storageService.uploadPublicImage(
        houseId,
        'home_avatar',
        file,
        quality: 84,
        minWidth: 512,
        minHeight: 512,
        onProgress: (p) {
          if (mounted) {
            setState(() => _avatarUploadProgress = p);
          }
        },
      );
      final url = upload?.downloadUrl.trim() ?? '';
      if (url.isEmpty) {
        throw 'Không lấy được ảnh mới.';
      }

      final oldAvatarUrl = (_houseSettings?[field] ?? '').toString().trim();
      await PendingUploadService.instance.clear(pendingKey);

      // Lưu URL ảnh R2 vào Firebase Realtime Database để đồng bộ
      try {
        final hid = (_houseId ?? '').trim();
        if (hid.isNotEmpty) {
          await _dbRef.child('houses/$hid/settings').update({
            field: url,
          }).catchError((_) {});
        }
      } catch (_) {}

      if (oldAvatarUrl.isNotEmpty && oldAvatarUrl.startsWith('http')) {
        try {
          _storageService.deleteImageByUrl(oldAvatarUrl);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _houseSettings ??= {};
          _houseSettings![field] = url;
          _avatarUploadProgress = 1.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUser1
                  ? 'Đã cập nhật avatar cho bạn nam.'
                  : 'Đã cập nhật avatar cho bạn nữ.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Chưa thể đổi ảnh đại diện lúc này. Vui lòng thử lại.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatarRole = null;
          _avatarUploadProgress = null;
        });
      }
    }
  }

  List<String> _resolveHomeWishes() {
    final raw = _houseSettings?['wishes']?.toString() ?? '';
    final wishes = raw
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (wishes.isNotEmpty) {
      return wishes;
    }
    if (_isSingleRelationship) {
      return const [
        'Một chút dịu dàng với chính mình hôm nay cũng đủ làm ngày mới dễ thương hơn rồi.',
        'Bấm vào trái tim ở giữa để thả sang một tín hiệu thật dễ thương nhé.',
        'Mở bản đồ lên xem vị trí hiện tại của bạn để lưu lại những nơi mình đã đi qua.',
        'Lưu lại một bức ảnh xinh hoặc một dòng note ngọt ngào cho trang chủ nhé.',
      ];
    }
    return const [
      'Một câu nhớ bạn nho nhỏ cũng đủ làm tim người ấy rung nhẹ đó.',
      'Bấm vào trái tim ở giữa để thả sang một tín hiệu thật dễ thương nhé.',
      'Mở bản đồ lên xem hai đứa đang xa bao nhiêu để còn thương nhau thêm.',
      'Lưu lại một bức ảnh xinh hoặc một dòng note ngọt ngào cho trang chủ nhé.',
    ];
  }

  String _currentHomeWish() {
    final wishes = _resolveHomeWishes();
    if (wishes.isEmpty) return '';
    final safeIndex = _wishIndex >= 0 ? _wishIndex % wishes.length : 0;
    return wishes[safeIndex];
  }

  static const List<String> _kCountdownPressHoldTips = [
    'Mẹo khi ấn giữ: giữ vòng đếm ngày để mở bảng đổi hiệu ứng nhanh ngay trên trang chủ.',
    'Mẹo khi ấn giữ: giữ nút mũi tên dưới cùng để ẩn thanh tab cho tới khi mở lại màn hình.',
    'Mẹo khi ấn giữ: giữ nút cài đặt góc phải để ẩn nút cài đặt cho ảnh chụp gọn hơn.',
  ];

  int _pickNextRandomIndex({
    required int length,
    required int previousIndex,
  }) {
    if (length <= 1) {
      return 0;
    }
    var nextIndex = _random.nextInt(length);
    while (nextIndex == previousIndex) {
      nextIndex = _random.nextInt(length);
    }
    return nextIndex;
  }

  String _currentCountdownTip() {
    if (_kCountdownPressHoldTips.isEmpty) return '';
    final safeIndex =
        _tipIndex >= 0 ? _tipIndex % _kCountdownPressHoldTips.length : 0;
    return _kCountdownPressHoldTips[safeIndex];
  }

  String? _advanceHomeWish() {
    final wishes = _resolveHomeWishes();
    if (wishes.isEmpty || !mounted) return null;
    final nextIndex = _pickNextRandomIndex(
      length: wishes.length,
      previousIndex: _wishIndex,
    );
    setState(() => _wishIndex = nextIndex);
    return wishes[nextIndex];
  }

  String? _advanceCountdownTip() {
    if (_kCountdownPressHoldTips.isEmpty || !mounted) return null;
    final nextIndex = _pickNextRandomIndex(
      length: _kCountdownPressHoldTips.length,
      previousIndex: _tipIndex,
    );
    setState(() => _tipIndex = nextIndex);
    return _kCountdownPressHoldTips[nextIndex];
  }

  Widget _buildHomeNoticeSection({
    required IconData icon,
    required Color accent,
    required String label,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: SLTheme.quicksand(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: SLTheme.quicksand(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNextWish() {
    final nextWish = _advanceHomeWish();
    if (nextWish == null || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          elevation: 0,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF262E3F), Color(0xFF313A4F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.26),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _buildHomeNoticeSection(
              icon: Icons.favorite_rounded,
              accent: const Color(0xFFFF8DB6),
              label: 'Lời chúc từ SoulLocket',
              message: nextWish,
            ),
          ),
        ),
      );
  }

  void _showCountdownCircleHint({required String smartGreeting}) {
    final showWish = Random().nextBool();
    final selectedMessage =
        showWish ? _advanceHomeWish() : _advanceCountdownTip();
    if (selectedMessage == null || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          elevation: 0,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF262E3F), Color(0xFF313A4F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: _buildHomeNoticeSection(
              icon: showWish
                  ? Icons.favorite_rounded
                  : Icons.tips_and_updates_rounded,
              accent:
                  showWish ? const Color(0xFFFF8DB6) : const Color(0xFF8BE9FF),
              label: showWish ? 'Lời chúc từ SoulLocket' : 'Mẹo nhanh',
              message: selectedMessage,
            ),
          ),
        ),
      );
  }

  static const Duration _kCountdownQuickUnlockWindow = Duration(days: 7);
  static const List<String> _kCountdownQuickPremiumStyleKeys = <String>[
    'floating_hearts',
    'galaxy',
    'aurora',
    'crystal',
    'fireworks',
    'lava',
  ];

  /// Trả về Set các style đã được mở khóa riêng lẻ qua xem quảng cáo.
  /// Mỗi style được lưu độc lập, không phụ thuộc nhau.
  Future<Set<String>> _getUnlockedCountdownStyles() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <String>{};
    for (final styleKey in _kCountdownQuickPremiumStyleKeys) {
      final expiryKey = 'il_countdown_style_unlock_expiry_$styleKey';
      final expiry = prefs.getInt(expiryKey) ?? 0;
      if (expiry > now) {
        result.add(styleKey);
      }
    }
    // Migration: nếu đã có unlock hàng loạt cũ còn hiệu lực thì cộng vào
    final legacyExpiry =
        prefs.getInt('il_countdown_unlock_weekly_expiry_v2') ?? 0;
    if (legacyExpiry > now) {
      result.addAll(_kCountdownQuickPremiumStyleKeys);
    } else {
      final legacyTs = prefs.getInt('il_countdown_unlock_ad_ts') ?? 0;
      if (legacyTs > 0) {
        final fallbackExpiry =
            legacyTs + _kCountdownQuickUnlockWindow.inMilliseconds;
        if (fallbackExpiry > now) {
          result.addAll(_kCountdownQuickPremiumStyleKeys);
        }
      }
    }
    return result;
  }

  Future<void> _saveCountdownQuickUiPrefs({
    String? countdownStyleKey,
    String? fallingEffectKey,
    double? countdownSizePx,
    double? avatarSizePx,
    String? avatarFrameKey,
    String? customBackgroundUrl,
    String? countdownTextColor,
    Set<String>? prevalidatedUnlockedStyles,
    bool? isVip,
  }) async {
    await UiPrefs.ensureLoaded();
    final current = UiPrefs.notifier.value;
    final resolvedCountdownStyleKey =
        (countdownStyleKey ?? current.countdownStyleKey).trim();
    final resolvedFallingEffectKey =
        (fallingEffectKey ?? current.fallingEffectKey).trim();

    if (countdownStyleKey != null) {
      const allowedCountdownStyleKeys = <String>{
        'default',
        'floating_hearts',
        'rose_wave',
        'glass',
        'glow',
        'plain',
        'candy',
        'galaxy',
        'aurora',
        'crystal',
        'fireworks',
        'lava',
      };
      if (!allowedCountdownStyleKeys.contains(resolvedCountdownStyleKey)) {
        if (mounted) {
          _showLatestSnackBar(
            'Không thể đổi kiểu vòng đếm vì mã kiểu "$resolvedCountdownStyleKey" không hợp lệ.',
          );
        }
        return;
      }
    }

    if (fallingEffectKey != null) {
      const allowedFallingEffectKeys = <String>{
        'auto',
        'sparkles',
        'stars',
        'hearts',
        'meteors',
        'bubbles',
        'snow',
        'leaves',
        'off',
      };
      if (!allowedFallingEffectKeys.contains(resolvedFallingEffectKey)) {
        if (mounted) {
          _showLatestSnackBar(
            'Không thể đổi hiệu ứng vì mã hiệu ứng "$resolvedFallingEffectKey" không hợp lệ.',
          );
        }
        return;
      }
    }

    final resolvedIsVip = isVip ?? await PurchaseService().isVip();
    if (countdownStyleKey != null &&
        _kCountdownQuickPremiumStyleKeys.contains(resolvedCountdownStyleKey) &&
        !resolvedIsVip) {
      final resolvedUnlockedStyles =
          prevalidatedUnlockedStyles ?? await _getUnlockedCountdownStyles();
      if (!resolvedUnlockedStyles.contains(resolvedCountdownStyleKey)) {
        if (mounted) {
          _showLatestSnackBar(
            'Kiểu "$resolvedCountdownStyleKey" chưa được mở. Hãy xem quảng cáo trong bảng tùy chỉnh để mở kiểu này.',
          );
        }
        return;
      }
    }

    final normalizedCountdownStyleKey = countdownStyleKey == null
        ? current.countdownStyleKey
        : resolvedCountdownStyleKey;
    final normalizedFallingEffectKey = fallingEffectKey == null
        ? current.fallingEffectKey
        : resolvedFallingEffectKey;
    final normalizedCountdownSizePx =
        countdownSizePx ?? current.countdownSizePx;
    final normalizedAvatarSizePx = avatarSizePx ?? current.avatarSizePx;
    final normalizedAvatarFrameKey = avatarFrameKey ?? current.avatarFrameKey;
    final normalizedCustomBackgroundUrl =
        customBackgroundUrl ?? current.customBackgroundUrl;
    final normalizedCountdownTextColor =
        countdownTextColor ?? current.countdownTextColor;

    // Auto turn off transparentMode if user explicitly changes countdown style
    final newTransparentMode =
        (countdownStyleKey != null) ? false : current.transparentMode;

    if (normalizedCountdownStyleKey == current.countdownStyleKey &&
        normalizedFallingEffectKey == current.fallingEffectKey &&
        normalizedCountdownSizePx == current.countdownSizePx &&
        normalizedAvatarSizePx == current.avatarSizePx &&
        normalizedAvatarFrameKey == current.avatarFrameKey &&
        normalizedCustomBackgroundUrl == current.customBackgroundUrl &&
        normalizedCountdownTextColor == current.countdownTextColor &&
        newTransparentMode == current.transparentMode) {
      return;
    }

    final nextState = current.copyWith(
      countdownStyleKey: normalizedCountdownStyleKey,
      fallingEffectKey: normalizedFallingEffectKey,
      countdownSizePx: normalizedCountdownSizePx,
      avatarSizePx: normalizedAvatarSizePx,
      avatarFrameKey: normalizedAvatarFrameKey,
      customBackgroundUrl: normalizedCustomBackgroundUrl,
      countdownTextColor: normalizedCountdownTextColor,
      transparentMode: newTransparentMode,
    );

    unawaited(UiPrefs.saveState(nextState).catchError((_) {}));

    final houseId = (_houseId ?? '').trim();
    if (houseId.isNotEmpty) {
      final updates = <String, dynamic>{
        'updatedAt': ServerValue.timestamp,
      };
      if (normalizedCountdownStyleKey != current.countdownStyleKey) {
        updates['countdownStyle'] = normalizedCountdownStyleKey;
      }
      if (normalizedFallingEffectKey != current.fallingEffectKey) {
        updates['fallingEffect'] = normalizedFallingEffectKey;
      }
      if (normalizedCountdownSizePx != current.countdownSizePx) {
        updates['countdownSizePx'] = normalizedCountdownSizePx;
      }
      if (normalizedAvatarSizePx != current.avatarSizePx) {
        updates['avatarSizePx'] = normalizedAvatarSizePx;
      }
      if (normalizedAvatarFrameKey != current.avatarFrameKey) {
        updates['avatarFrame'] = normalizedAvatarFrameKey;
      }
      if (normalizedCustomBackgroundUrl != current.customBackgroundUrl) {
        updates['customBackgroundUrl'] = normalizedCustomBackgroundUrl;
        updates['customHomeBackground'] = normalizedCustomBackgroundUrl;
      }
      if (normalizedCountdownTextColor != current.countdownTextColor) {
        updates['countdownTextColor'] = normalizedCountdownTextColor;
      }
      if (newTransparentMode != current.transparentMode) {
        updates['transparentMode'] = newTransparentMode;
      }

      unawaited(_dbRef
          .child('houses/$houseId/settings')
          .update(updates)
          .catchError((e) {
        if (mounted) {
          _showLatestSnackBar(
            'Đã lưu trên máy. Chưa thể đồng bộ lúc này, vui lòng thử lại sau.',
          );
        }
      }));
    }
  }

  Future<void> _showCountdownQuickCustomizeSheet() async {
    final isVip = await PurchaseService().isVip();
    Set<String> unlockedStyles = isVip
        ? Set<String>.from(_kCountdownQuickPremiumStyleKeys)
        : await _getUnlockedCountdownStyles();
    if (!mounted) return;

    final styleOptions = <_CountdownQuickOption>[
      _CountdownQuickOption(
        label: context.tr('countdown_default'),
        value: 'default',
        icon: Icons.favorite_rounded,
        accent: const Color(0xFFD94C86),
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_floating_hearts'),
        value: 'floating_hearts',
        icon: Icons.favorite_border_rounded,
        accent: const Color(0xFFFF8DA1),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_glass'),
        value: 'glass',
        icon: Icons.blur_on_rounded,
        accent: const Color(0xFF6AA7D8),
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_glow'),
        value: 'glow',
        icon: Icons.auto_awesome_rounded,
        accent: const Color(0xFFFF8A65),
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_candy'),
        value: 'candy',
        icon: Icons.icecream_rounded,
        accent: const Color(0xFFFF6FA8),
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_galaxy'),
        value: 'galaxy',
        icon: Icons.nights_stay_rounded,
        accent: const Color(0xFF6F63D9),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_aurora'),
        value: 'aurora',
        icon: Icons.bolt_rounded,
        accent: const Color(0xFF26A69A),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_crystal'),
        value: 'crystal',
        icon: Icons.diamond_rounded,
        accent: const Color(0xFF5C9CE6),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_fireworks'),
        value: 'fireworks',
        icon: Icons.local_fire_department_rounded,
        accent: const Color(0xFFFF7043),
        isPremium: true,
      ),
      _CountdownQuickOption(
        label: context.tr('countdown_lava'),
        value: 'lava',
        icon: Icons.whatshot_rounded,
        accent: const Color(0xFFE53935),
        isPremium: true,
      ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F5F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return _CountdownQuickCustomizeSheetContent(
          styleOptions: styleOptions,
          unlockedStyles: unlockedStyles,
          isVip: isVip,
          homeState: this,
          sheetContext: sheetContext,
        );
      },
    );
  }

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

  bool _shouldShowAdminBadge(String role) {
    return false;
  }

  void triggerShootingHeartState({String? emoji, String? fromRole}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _showReactionFlight(
      _HomeReactionFlight(
        id: 'local-$now-${_random.nextInt(999999)}',
        fromRole: fromRole ?? _currentRole,
        toRole: (fromRole ?? _currentRole) == 'user1' ? 'user2' : 'user1',
        emoji: emoji ?? _emojiForInteractionType('miss'),
        sentAtMs: now,
      ),
    );
  }

  int _consumeLocalReactionThrowWaitSeconds(int nowMs) {
    _localReactionThrowMs.removeWhere(
      (sentAt) => nowMs - sentAt >= _kReactionThrowWindow.inMilliseconds,
    );
    if (_localReactionThrowMs.length >= _kReactionThrowBurstLimit) {
      final oldest = _localReactionThrowMs.first;
      final remainingMs =
          _kReactionThrowWindow.inMilliseconds - (nowMs - oldest);
      final seconds = (remainingMs / 1000).ceil();
      return seconds < 1 ? 1 : seconds;
    }
    _localReactionThrowMs.add(nowMs);
    return 0;
  }

  Future<int> _consumeReactionThrowWaitSeconds() async {
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) return 0;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int asInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is double) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? 0;
      return 0;
    }

    var waitMs = 0;
    try {
      final ref =
          _dbRef.child('houses/$houseId/reaction_throw_limits/$_currentRole');
      final tx = await ref.runTransaction((Object? current) {
        final data =
            current is Map ? _toStringDynamicMap(current) : <String, dynamic>{};
        final windowStartMs = asInt(data['windowStartMs']);
        final count = asInt(data['count']);
        final elapsedMs = nowMs - windowStartMs;
        final shouldStartNewWindow = windowStartMs <= 0 ||
            elapsedMs < 0 ||
            elapsedMs >= _kReactionThrowWindow.inMilliseconds;

        if (shouldStartNewWindow) {
          return Transaction.success({
            'windowStartMs': nowMs,
            'count': 1,
            'updatedAtMs': nowMs,
          });
        }

        if (count >= _kReactionThrowBurstLimit) {
          waitMs = _kReactionThrowWindow.inMilliseconds - elapsedMs;
          return Transaction.abort();
        }

        return Transaction.success({
          'windowStartMs': windowStartMs,
          'count': count + 1,
          'updatedAtMs': nowMs,
        });
      });

      if (tx.committed) return 0;
      final seconds = (waitMs / 1000).ceil();
      return seconds < 1 ? 1 : seconds;
    } catch (_) {
      return _consumeLocalReactionThrowWaitSeconds(nowMs);
    }
  }

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
          if (_houseId != null) 'houseId': _houseId!,
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

  @override
  Widget build(BuildContext context) {
    return _MainHomeStateView(
      isLoading: _isLoading,
      hasVisibleContent: _houseSettings != null,
      child: ValueListenableBuilder<UiPrefsState>(
        valueListenable: UiPrefs.notifier,
        builder: (context, uiState, __) => Stack(
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

  bool _isSendingInteraction = false;

  Future<void> _handleSendInteraction(String type, String emoji) async {
    final cleanEmoji =
        emoji.trim().isEmpty ? _emojiForInteractionType(type) : emoji;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final localWait = _consumeLocalReactionThrowWaitSeconds(nowMs);
    if (localWait > 0) {
      _showReactionThrowLimitSnack();
      return;
    }
    if (!mounted) return;

    _sendReactionFlight(type, cleanEmoji);
    _triggerMissYouEffect(type);
    _vibrateHeartbeat();

    if (_isSendingInteraction) return;
    _isSendingInteraction = true;

    final preset = _maybePresetForInteractionType(type);
    final randomTitle = preset == null
        ? null
        : preset.titles[_random.nextInt(preset.titles.length)];
    final randomMessage = preset == null
        ? null
        : preset.messages[_random.nextInt(preset.messages.length)];

    unawaited(Future(() async {
      final waitSeconds = await _consumeReactionThrowWaitSeconds();
      if (waitSeconds > 0) {
        _showReactionThrowLimitSnack();
        return;
      }
      _sendPartnerInteraction(
        type,
        showSentNotice: false,
        emoji: cleanEmoji,
        customTitle: randomTitle,
        customMessage: randomMessage,
      );
    }));

    // Mở khóa nút bấm sau 2 giây
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _isSendingInteraction = false;
      }
    });
  }
}

class _ThemeBackgroundAspectRatioPreset implements CropAspectRatioPresetData {
  const _ThemeBackgroundAspectRatioPreset();

  @override
  String get name => 'house_background_9x16';

  @override
  (int ratioX, int ratioY)? get data => (9, 16);
}

class _CountdownQuickCustomizeSheetContent extends StatefulWidget {
  final List<_CountdownQuickOption> styleOptions;
  final Set<String> unlockedStyles;
  final bool isVip;
  final _MainHomeTabState homeState;
  final BuildContext sheetContext;

  const _CountdownQuickCustomizeSheetContent({
    required this.styleOptions,
    required this.unlockedStyles,
    required this.isVip,
    required this.homeState,
    required this.sheetContext,
  });

  @override
  State<_CountdownQuickCustomizeSheetContent> createState() =>
      _CountdownQuickCustomizeSheetContentState();
}

class _CountdownQuickCustomizeSheetContentState
    extends State<_CountdownQuickCustomizeSheetContent> {
  double? _tempCountdownSize;
  bool _isUploadingBg = false;
  double? _bgUploadProgress;
  String? _unlockingStyleKey;
  late Set<String> _unlockedStyles;

  @override
  void initState() {
    super.initState();
    _unlockedStyles = Set<String>.from(widget.unlockedStyles);
  }

  Widget buildOptionChip({
    required _CountdownQuickOption option,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = option.accent;
    final borderColor = selected ? accent : accent.withValues(alpha: 0.28);
    final backgroundColor =
        selected ? accent.withValues(alpha: 0.14) : Colors.white;
    final textColor = selected ? accent : const Color(0xFF584450);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, size: 17, color: accent),
              const SizedBox(width: 8),
              Text(
                option.label,
                style: SLTheme.quicksand(
                  fontSize: 12.6,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLockedAdButton({
    required _CountdownQuickOption option,
    required Future<void> Function(_CountdownQuickOption option) onUnlocked,
  }) {
    final isThisUnlocking = _unlockingStyleKey == option.value;
    final accent = option.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isThisUnlocking
            ? null
            : () async {
                if (_unlockingStyleKey != null) return;
                HapticFeedback.mediumImpact();
                setState(() {
                  _unlockingStyleKey = option.value;
                });
                try {
                  final adMob = AdMobService();
                  final adSuccess = await adMob.showRewardedAd();
                  if (!mounted) return;
                  if (adSuccess) {
                    final prefs = await SharedPreferences.getInstance();
                    final now = DateTime.now().millisecondsSinceEpoch;
                    await prefs.setInt('il_last_any_rewarded_ad_ts', now);
                    final expiry = now +
                        _MainHomeTabState
                            ._kCountdownQuickUnlockWindow.inMilliseconds;
                    final expiryKey =
                        'il_countdown_style_unlock_expiry_${option.value}';
                    await prefs.setInt(expiryKey, expiry);
                    setState(() {
                      _unlockedStyles = {..._unlockedStyles, option.value};
                    });
                    await onUnlocked(option);
                    widget.homeState._showLatestSnackBar(
                        'Đã mở khóa "${option.label}" trong 7 ngày!');
                  } else {
                    widget.homeState._showLatestSnackBar(
                        'Chưa mở khóa. Vui lòng xem hết quảng cáo.');
                  }
                } catch (_) {
                  widget.homeState
                      ._showLatestSnackBar('Đã xảy ra lỗi khi tải quảng cáo.');
                } finally {
                  if (mounted) {
                    setState(() {
                      _unlockingStyleKey = null;
                    });
                  }
                }
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                option.label,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              if (isThisUnlocking)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                )
              else
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: 22,
                  color: accent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSection({
    required String title,
    required String description,
    required IconData icon,
    required List<_CountdownQuickOption> options,
    required String selectedValue,
    required Future<void> Function(_CountdownQuickOption option) onSelect,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0DDE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((option) {
              final isLocked =
                  option.isPremium && !_unlockedStyles.contains(option.value);
              if (isLocked) {
                return buildLockedAdButton(
                  option: option,
                  onUnlocked: (opt) async {
                    HapticFeedback.selectionClick();
                    await onSelect(opt);
                  },
                );
              }
              return buildOptionChip(
                option: option,
                selected: selectedValue == option.value,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await onSelect(option);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget buildTextColorSection({
    required String selectedColorHex,
    required Future<void> Function(String hex) onSelect,
  }) {
    final colors = [
      '', // Mặc định
      '#FFFFFF', // Trắng
      '#000000', // Đen
      '#F44336', // Đỏ
      '#E91E63', // Hồng
      '#9C27B0', // Tím
      '#673AB7', // Tím đậm
      '#3F51B5', // Xanh chàm
      '#2196F3', // Xanh dương
      '#00BCD4', // Xanh ngọc
      '#4CAF50', // Xanh lá
      '#FFEB3B', // Vàng
      '#FF9800', // Cam
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0DDE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4B2B).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.format_color_text_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Màu chữ vòng đếm',
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thay đổi màu sắc nhãn và số ngày yêu.',
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: colors.map((hex) {
                final isSelected = selectedColorHex == hex;
                final isDefault = hex.isEmpty;
                final color = isDefault
                    ? Colors.transparent
                    : Color(int.parse(hex.replaceFirst('#', '0xFF')));

                return GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await onSelect(hex);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD81B60)
                            : const Color(0xFFF0DDE4),
                        width: isSelected ? 3.0 : 1.5,
                      ),
                    ),
                    child: isDefault
                        ? Icon(Icons.format_color_reset_rounded,
                            size: 20,
                            color: isSelected
                                ? const Color(0xFFD81B60)
                                : const Color(0xFF8E6F7E))
                        : (isSelected
                            ? Icon(Icons.check_rounded,
                                size: 20,
                                color: color.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white)
                            : null),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSizeSection({
    required String title,
    required String description,
    required IconData icon,
    required double currentValue,
    required double? tempValue,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangedEnd,
    required VoidCallback onSave,
    required String? customBgUrl,
  }) {
    final displayValue = tempValue ?? currentValue;
    final hasChanges =
        tempValue != null && (tempValue - currentValue).abs() > 0.01;
    final hasBg = customBgUrl != null && customBgUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0DDE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C9FF).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.zoom_out_rounded,
                color: Color(0xFF8E6F7E),
                size: 20,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFFD81B60),
                    inactiveTrackColor: const Color(0xFFFDE8F0),
                    thumbColor: const Color(0xFFD81B60),
                    overlayColor:
                        const Color(0xFFD81B60).withValues(alpha: 0.12),
                    trackHeight: 4.0,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16.0),
                  ),
                  child: Slider(
                    min: 200.0,
                    max: UiPrefs.maxCountdownSizePx,
                    value:
                        displayValue.clamp(200.0, UiPrefs.maxCountdownSizePx),
                    onChanged: onChanged,
                    onChangeEnd: onChangedEnd,
                  ),
                ),
              ),
              const Icon(
                Icons.zoom_in_rounded,
                color: Color(0xFFD81B60),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kích thước: ${displayValue.toInt()} px',
                style: SLTheme.quicksand(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w800,
                  color: hasChanges
                      ? const Color(0xFFD81B60)
                      : const Color(0xFF8E6F7E),
                ),
              ),
              if (hasChanges)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onSave,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF4D7E2)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFD81B60).withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Lưu',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD81B60),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFF0DDE4), height: 1),
          ),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9733EE).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh nền trang chủ',
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tải lên hoặc xóa ảnh nền trang chủ.',
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isUploadingBg) ...[
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFD81B60)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _bgUploadProgress != null
                        ? 'Đang tải lên: ${(_bgUploadProgress! * 100).toInt()}%'
                        : 'Đang chuẩn bị tải lên...',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E6F7E),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                if (hasBg) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: customBgUrl.trim(),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFFFDE8F0),
                        child: const Icon(Icons.image_outlined,
                            size: 16, color: Color(0xFFD81B60)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFFDE8F0),
                        child: const Icon(Icons.broken_image_outlined,
                            size: 16, color: Color(0xFFD81B60)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF0DDE4)),
                      foregroundColor: const Color(0xFF4A3640),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _pickBgImage,
                    icon: const Icon(Icons.upload_rounded,
                        size: 16, color: Color(0xFFD81B60)),
                    label: Text(
                      hasBg ? 'Thay đổi ảnh' : 'Tải ảnh lên',
                      style: SLTheme.quicksand(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (hasBg) ...[
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF4D7E2)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFD81B60), size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              'Xóa ảnh nền?',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900),
                            ),
                            content: Text(
                              'Bạn có chắc chắn muốn xóa ảnh nền trang chủ không?',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w700),
                            ),
                            actions: [
                              TextButton(
                                child: Text(
                                  'Hủy',
                                  style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF8E6F7E)),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                              TextButton(
                                child: Text(
                                  'Xóa',
                                  style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFD81B60)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _clearBgImage();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickBgImage() async {
    final homeState = widget.homeState;
    final houseId = (homeState._houseId ?? '').trim();
    if (houseId.isEmpty) {
      homeState._showLatestSnackBar(
          'Vui lòng đăng nhập hoặc tham gia nhà để đổi ảnh nền.');
      return;
    }

    if (!widget.isVip && !kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final lastAdTimeStr = prefs.getString('last_bg_ad_time');
      bool shouldShowAd = true;
      if (lastAdTimeStr != null) {
        final lastAdTime = DateTime.parse(lastAdTimeStr);
        if (DateTime.now().difference(lastAdTime).inMinutes < 15) {
          shouldShowAd = false;
        }
      }

      if (shouldShowAd) {
        final adMob = AdMobService();
        final adSuccess = await adMob.showRewardedAd(
          ignoreCooldown: true,
          loadTimeout: const Duration(seconds: 12),
        );
        if (!mounted) return;
        if (!adSuccess) {
          homeState._showLatestSnackBar('Cần xem hết quảng cáo để thay đổi ảnh nền.');
          return;
        }
        await prefs.setString('last_bg_ad_time', DateTime.now().toIso8601String());
      }
    }

    try {
      final pickedFile = await homeState._storageService.pickImage();
      if (pickedFile == null || !mounted) return;
      XFile file = pickedFile;

      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: file.path,
          aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 82,
          maxWidth: 1440,
          maxHeight: 3200,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Chỉnh sửa ảnh nền',
              toolbarColor: const Color(0xFFD81B60),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Chỉnh sửa ảnh nền',
              // Using ratio16x9 since ratio9x16 was removed in image_cropper v7
              aspectRatioPresets: const [CropAspectRatioPreset.ratio16x9],
              aspectRatioLockEnabled: true,
              aspectRatioPickerButtonHidden: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );
        if (croppedFile != null) {
          file = XFile(croppedFile.path);
        }
      } catch (e) {
        debugPrint('Lỗi cắt ảnh: $e');
      }

      if (!mounted) return;
      setState(() {
        _isUploadingBg = true;
        _bgUploadProgress = 0.0;
      });

      final url = await homeState._storageService.uploadImage(
        houseId,
        'themes',
        file,
        quality: 95,
        minWidth: 1440,
        minHeight: 1440,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _bgUploadProgress = progress;
            });
          }
        },
      );

      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        homeState._showLatestSnackBar('Tải ảnh nền thất bại.');
        return;
      }

      final oldUrl = UiPrefs.notifier.value.customBackgroundUrl;
      if (oldUrl.isNotEmpty) {
        try {
          homeState._storageService.deleteImageByUrl(oldUrl);
        } catch (_) {}
      }

      await homeState._saveCountdownQuickUiPrefs(
        customBackgroundUrl: url.trim(),
        isVip: widget.isVip,
      );

      homeState._showLatestSnackBar('Đã lưu ảnh nền thành công!');
    } catch (e) {
      if (mounted) {
        homeState._showLatestSnackBar('Đã xảy ra lỗi khi tải lên ảnh nền.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingBg = false;
          _bgUploadProgress = null;
        });
      }
    }
  }

  Future<void> _clearBgImage() async {
    final oldUrl = UiPrefs.notifier.value.customBackgroundUrl;
    if (oldUrl.isNotEmpty) {
      try {
        widget.homeState._storageService.deleteImageByUrl(oldUrl);
      } catch (_) {}
    }
    await widget.homeState._saveCountdownQuickUiPrefs(
      customBackgroundUrl: '',
      isVip: widget.isVip,
    );
    widget.homeState._showLatestSnackBar('Đã xóa ảnh nền trang chủ.');
  }

  Widget buildTimerSection({
    required bool showTimer,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0DDE4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDC830), Color(0xFFF37335)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF37335).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bộ đếm giờ chi tiết',
                    style: SLTheme.quicksand(
                      fontSize: 14.8,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4A3640),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hiện giờ/phút/giây bên dưới số ngày.',
                    style: SLTheme.quicksand(
                      fontSize: 12.1,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E6F7E),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: showTimer,
            activeThumbColor: const Color(0xFFD81B60),
            activeTrackColor: const Color(0xFFFDE8F0),
            inactiveThumbColor: const Color(0xFFB0B0B0),
            inactiveTrackColor: const Color(0xFFF0DDE4),
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }

  Widget buildBackgroundSection({
    required String? customBgUrl,
  }) {
    final hasBg = customBgUrl != null && customBgUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0DDE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9733EE).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh nền trang chủ',
                      style: SLTheme.quicksand(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3640),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tải lên hoặc xóa ảnh nền trang chủ.',
                      style: SLTheme.quicksand(
                        fontSize: 12.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E6F7E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isUploadingBg) ...[
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFD81B60)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _bgUploadProgress != null
                        ? 'Đang tải lên: ${(_bgUploadProgress! * 100).toInt()}%'
                        : 'Đang chuẩn bị tải lên...',
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E6F7E),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                if (hasBg) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: customBgUrl.trim(),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFFFDE8F0),
                        child: const Icon(Icons.image_outlined,
                            size: 16, color: Color(0xFFD81B60)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFFDE8F0),
                        child: const Icon(Icons.broken_image_outlined,
                            size: 16, color: Color(0xFFD81B60)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF0DDE4)),
                      foregroundColor: const Color(0xFF4A3640),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _pickBgImage,
                    icon: const Icon(Icons.upload_rounded,
                        size: 16, color: Color(0xFFD81B60)),
                    label: Text(
                      hasBg ? 'Thay đổi ảnh' : 'Tải ảnh lên',
                      style: SLTheme.quicksand(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (hasBg) ...[
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2F7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF4D7E2)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFD81B60), size: 20),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              'Xóa ảnh nền?',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900),
                            ),
                            content: Text(
                              'Bạn có chắc chắn muốn xóa ảnh nền trang chủ không?',
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w700),
                            ),
                            actions: [
                              TextButton(
                                child: Text(
                                  'Hủy',
                                  style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF8E6F7E)),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                              TextButton(
                                child: Text(
                                  'Xóa',
                                  style: SLTheme.quicksand(
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFD81B60)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _clearBgImage();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: ValueListenableBuilder<UiPrefsState>(
        valueListenable: UiPrefs.notifier,
        builder: (context, uiState, __) {
          final selectedStyle = widget.styleOptions.firstWhere(
            (option) => option.value == uiState.countdownStyleKey,
            orElse: () => widget.styleOptions.first,
          );

          final currentStyleIsLocked =
              _MainHomeTabState._kCountdownQuickPremiumStyleKeys.contains(
                    uiState.countdownStyleKey,
                  ) &&
                  !_unlockedStyles.contains(uiState.countdownStyleKey);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              12,
              18,
              max(mediaQuery.padding.bottom, 14.0) + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF8FB1),
                            Color(0xFFD81B60),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tùy chỉnh vòng đếm',
                            style: SLTheme.quicksand(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF33262D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ấn giữ vòng đếm ngày để mở bảng này và đổi nhanh giao diện ngay trên trang chủ.',
                            style: SLTheme.quicksand(
                              fontSize: 12.4,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF806575),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(widget.sheetContext).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFF0DDE4),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFD81B60),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFF2F7),
                        Color(0xFFFFFBFD),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFF4D7E2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đang dùng',
                        style: SLTheme.quicksand(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD81B60),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (currentStyleIsLocked)
                            buildLockedAdButton(
                              option: selectedStyle,
                              onUnlocked: (opt) async {
                                await widget.homeState
                                    ._saveCountdownQuickUiPrefs(
                                  countdownStyleKey: opt.value,
                                  prevalidatedUnlockedStyles: _unlockedStyles,
                                  isVip: widget.isVip,
                                );
                              },
                            )
                          else
                            buildOptionChip(
                              option: selectedStyle,
                              selected: true,
                              onTap: () =>
                                  widget.homeState._saveCountdownQuickUiPrefs(
                                countdownStyleKey: selectedStyle.value,
                                prevalidatedUnlockedStyles: _unlockedStyles,
                                isVip: widget.isVip,
                              ),
                            ),
                          // Tạm ngắt hiển thị hiệu ứng nền
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                buildSection(
                  title: 'Giao diện vòng đếm',
                  description: 'Đổi phong cách hiển thị vòng đếm ngày.',
                  icon: Icons.change_circle_rounded,
                  options: widget.styleOptions,
                  selectedValue: uiState.countdownStyleKey,
                  onSelect: (option) =>
                      widget.homeState._saveCountdownQuickUiPrefs(
                    countdownStyleKey: option.value,
                    prevalidatedUnlockedStyles: _unlockedStyles,
                    isVip: widget.isVip,
                  ),
                ),
                const SizedBox(height: 12),
                buildTextColorSection(
                  selectedColorHex: uiState.countdownTextColor,
                  onSelect: (hex) =>
                      widget.homeState._saveCountdownQuickUiPrefs(
                    countdownTextColor: hex,
                    prevalidatedUnlockedStyles: _unlockedStyles,
                    isVip: widget.isVip,
                  ),
                ),
                const SizedBox(height: 12),
                buildSizeSection(
                  title: 'Kích thước vòng đếm',
                  description: 'Kéo để điều chỉnh độ lớn của vòng đếm ngày.',
                  icon: Icons.photo_size_select_large_rounded,
                  currentValue: uiState.countdownSizePx,
                  tempValue: _tempCountdownSize,
                  customBgUrl: uiState.customBackgroundUrl,
                  onChanged: (value) {
                    setState(() {
                      _tempCountdownSize = value;
                    });
                  },
                  onChangedEnd: (value) {
                    setState(() {
                      _tempCountdownSize = value;
                    });
                  },
                  onSave: () async {
                    if (_tempCountdownSize != null) {
                      final sizeToSave = _tempCountdownSize!;
                      await widget.homeState._saveCountdownQuickUiPrefs(
                        countdownSizePx: sizeToSave,
                        isVip: widget.isVip,
                      );
                      HapticFeedback.mediumImpact();
                      if (mounted) {
                        setState(() => _tempCountdownSize = null);
                      }
                    }
                  },
                ),
                buildTimerSection(
                  showTimer: uiState.homeShowTimer,
                  onToggle: (val) async {
                    HapticFeedback.selectionClick();
                    await UiPrefs.setHomeShowTimer(val);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(widget.sheetContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD81B60),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Xong',
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SoulMergeSticker extends StatefulWidget {
  final int activeIndex;
  const SoulMergeSticker({super.key, this.activeIndex = 0});

  @override
  State<SoulMergeSticker> createState() => SoulMergeStickerState();
}

class SoulMergeStickerState extends State<SoulMergeSticker> {
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

  static const List<String> _appTips = [
    '💡 Chạm giữ nút "Lưu Tâm Sự" để thấy hiệu ứng co giãn 3D cực mượt nha!',
    '💡 Viết tâm sự dưới 30 ký tự sẽ tự động biến thành thẻ trích dẫn nghệ thuật lãng mạn đó!',
    '💡 Lắc điện thoại cùng lúc với người ấy khi mở Soul Merge để ghép đôi tâm hồn 💕',
    '💡 Chia sẻ kỷ niệm ra ngoài qua liên kết Memory Share để bạn bè cùng xem nhé 🏡',
    '💡 Chạm liên tục vào trái tim trong Soul Merge để bắn ra những hạt bụi phép thuật lãng mạn 💫',
    '💡 Bạn có thể gửi ảnh thì thầm trực tiếp cho người ấy ngay trong màn hình Soul Merge 📸',
    '💡 Bật bong bóng nổi ngoài app (nút chat ở góc) để trò chuyện nhanh với người ấy bất cứ lúc nào!',
    '💡 Nâng cấp tài khoản PRO để tạo tới 20 liên kết Memory Share và tắt quảng cáo hoàn toàn 💎',
    '💡 Trải nghiệm Rạp chiếu phim đôi ở tab Tiện ích để cùng xem phim online với người ấy 🍿',
    '💡 Sử dụng Sổ tay chi tiêu chung ở tab Tiện ích để quản lý quỹ hẹn hò của hai bạn minh bạch 💰',
    '💡 Gửi thư đến tương lai bằng Hộp thư thời gian (Capsule) để bất ngờ trao gửi yêu thương ✉️',
    '💡 Cùng lên danh sách To-do list hoặc ghi lại ghi chú ngọt ngào ở mục Ghi chú chung 📝',
    '💡 Thử vận may hoặc giải trí cùng người ấy với Vòng quay thử thách ở tab Giải Trí 🎡',
    '💡 Rút bài Tarot tình duyên mỗi ngày ở tab Giải Trí để xem mức độ đồng điệu hôm nay 🔮',
    '💡 Đừng quên cho thú cưng ảo ăn và tương tác mỗi ngày trong ngôi nhà chung nhé 🐱',
    '💡 Vào Cài đặt ➔ Giao diện để đổi màu chủ đề cực xinh như "Hoàng hôn", "Đại dương" hay "Hồng ngọt ngào"! 🎨',
    '💡 Bạn có thể bật hiệu ứng tuyết rơi, trái tim bay hoặc lá rụng rất lãng mạn trong Cài đặt ➔ Giao diện! ❄️',
    '💡 Đừng quên vào Cài đặt ➔ Giao diện để tải lên ảnh đôi (tỷ lệ 9:16) làm hình nền nhà chung ấm cúng nhé! 🖼️',
    '💡 Muốn đổi kiểu chữ lãng mạn? Hãy vào Cài đặt ➔ Giao diện ➔ Chọn phông chữ (Quicksand, Inter, Roboto...)! ✍️',
    '💡 Vào Cài đặt ➔ Giao diện để bật/tắt khung viền ảnh đại diện thủy tinh, ngọc trai hay viền VIP lấp lánh! 💍',
    '💡 Cài đặt phong cách đồng hồ đếm ngược ngày yêu (Anniversary style) với nhiều mẫu độc đáo trong Cài đặt! ⏰',
    '💡 Vào Cài đặt ➔ Bảo mật ➔ Thiết lập câu hỏi bảo mật để dễ dàng tự khôi phục tài khoản khi cần! 🔑',
    '💡 Để tránh người lạ đọc trộm nhật ký, hãy vào Cài đặt ➔ Bảo mật và đặt "Mã PIN dự phòng" ngay nha! 🔒',
    '💡 Tính năng Kho báu bí mật tự động khóa sau 5p/15p/1h, bạn có thể tùy chỉnh ở Cài đặt ➔ Bảo mật! 💼',
    '💡 Vào Cài đặt ➔ Bảo mật ➔ Quản lý thiết bị để kiểm tra và đăng xuất từ xa khỏi các thiết bị lạ! 📱',
    '💡 Bạn có thể liên kết tài khoản Google trong Cài đặt ➔ Bảo mật để đăng nhập nhanh chóng và an toàn hơn! 🌐',
    '💡 Đăng ký Email phụ trong Cài đặt ➔ Bảo mật để tăng cường an toàn và nhận mã khôi phục khi quên mật khẩu! ✉️',
    '💡 Vào Cài đặt ➔ Thông báo để nhận tin nhắc nhở trước ngày kỷ niệm 1 ngày, 3 ngày hoặc 7 ngày nhé! 📅',
    '💡 Để biết lúc nào người ấy vào ứng dụng, hãy bật "Thông báo đối phương online" trong Cài đặt ➔ Thông báo! 🔔',
    '💡 Để ẩn thời gian online, hãy vào Cài đặt ➔ Thông báo ➔ tắt mục "Hiển thị trạng thái hoạt động". Người ấy sẽ không thấy bạn đang hoạt động nữa! 🟢',
    '💡 Vào Cài đặt ➔ Mối quan hệ để đổi biệt danh đáng yêu hiển thị riêng cho hai bạn nha! 💕',
    '💡 Bạn có thể chỉnh ngày bắt đầu yêu trong Cài đặt ➔ Mối quan hệ để đếm chính xác số ngày bên nhau! 🗓️',
    '💡 Hãy vào Cài đặt ➔ Widget để tùy chỉnh giao diện đếm ngày yêu ngoài màn hình chính điện thoại cực đẹp! 📱',
    '💡 Trong Cài đặt ➔ Mối quan hệ, bạn có thể dễ dàng chuyển đổi giữa chế độ Độc thân (Single) và Đôi lứa (Couple)! 🏡',
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
    _loadSettings();
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
    }
  }

  @override
  void dispose() {
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
      if (!_isSingle) {
        _initChatListening();
        _initInteractiveEventsListening();
        _startTipsTimer();
      }
    }
  }

  void _initInteractiveEventsListening() {
    _interactiveEventsSub?.cancel();
    _interactiveEventsSub =
        SoulMergeService().watchInteractiveEvents().listen((event) async {
      if (event.isEmpty || _isSingle || !mounted) return;
      final sender = event['sender']?.toString();
      if (sender == _myRole) return; // ignore my own

      final type = event['type']?.toString();
      if (type == 'photo_shot') {
        // 1. Hiển thị thông báo bằng chữ nếu được bật
        if (_showHeartNotif) {
          _showFloatingMessage('Người ấy vừa thả tim cho bạn! 💕');
        }

        // 2. Hiển thị hiệu ứng tim bay nếu:
        // - Chúng ta đang ở màn hình home (luôn bay ở home)
        if (widget.activeIndex == 0) {
          final prefs = await SharedPreferences.getInstance();
          final style = prefs.getString('soul_merge_heart_style') ?? 'basic';
          if (mounted) {
            setState(() {
              _globalHeartStyle = style;
            });
            // Trì hoãn nhẹ 50ms để widget cập nhật style mới rồi bắn tim
            Future.delayed(const Duration(milliseconds: 50), () {
              _globalHeartsKey.currentState
                  ?.spawnLocalExplosion(const Offset(26, 26), count: 6);
            });
          }
        }
      }
    });
  }

  Future<void> _initChatListening() async {
    final prefs = await SharedPreferences.getInstance();
    _myRole = prefs.getString('il_role') ?? 'user1';

    _messagesSub = SoulMergeService().watchSoulMessages().listen((messages) {
      if (messages.isEmpty || _isSingle) return;
      final isVisible = widget.activeIndex == 0;
      if (!isVisible) return;
      final lastMsg = messages.last;
      final sender = lastMsg['sender']?.toString();
      if (sender != _myRole) {
        final text = lastMsg['text']?.toString() ?? '';
        final imgUrl = lastMsg['imageUrl']?.toString() ?? '';
        final displayTxt = text.isNotEmpty
            ? text
            : (imgUrl.isNotEmpty ? 'Đã gửi một ảnh 📸' : '');
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
    _tipsTimer?.cancel();
    _tipsTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _showRandomTip();
    });
  }

  void _showRandomTip() {
    final isVisible = widget.activeIndex == 0;
    if (!isVisible) return;
    final tip = _appTips[_random.nextInt(_appTips.length)];
    _showFloatingMessage(tip);
  }

  void _showFloatingMessage(String text) {
    if (!mounted) return;
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
    if (_isSingle) return const SizedBox.shrink();

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
              // Đuôi nhọn bong bóng thoại chĩa xuống dưới, luôn đứng cố định ở trung tâm sticker (left = 22)
              if (_showBubble && _bubbleText != null)
                Positioned(
                  bottom: 51,
                  left: 22,
                  child: AnimatedOpacity(
                    opacity: _showBubble ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Transform.rotate(
                      angle: 3.1415926535 / 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(
                                color: Color(0xFFFFB3CA), width: 1.5),
                            right: BorderSide(
                                color: Color(0xFFFFB3CA), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Bong bóng chat hiển thị tin nhắn / mẹo nền trắng viền hồng pastel cực xinh
              Positioned(
                bottom: 57,
                left: tooltipLeft,
                child: AnimatedOpacity(
                  opacity: _showBubble ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _showBubble && _bubbleText != null
                      ? Container(
                          width: 212,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFB3CA),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFCEBCD0)
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            _bubbleText!,
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF5A4656),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
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
                      targetPos.dx
                          .clamp(0.0, MediaQuery.sizeOf(context).width - 52),
                      targetPos.dy
                          .clamp(0.0, MediaQuery.sizeOf(context).height - 150),
                    );
                  });
                },
                onPanEnd: (_) {
                  if (_position != null) _savePosition(_position!);
                },
                onTap: () async {
                  await Navigator.push(
                    context,
                    SLRoute(builder: (_) => const SoulMergeScreen()),
                  );
                  _loadSettings();
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4F93).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/interaction_stickers/custom/numbered/sticker_098.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
