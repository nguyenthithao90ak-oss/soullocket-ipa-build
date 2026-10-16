import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/sl_route.dart';
import '../utils/local_guide_route_tracker.dart';
import '../utils/services/l10n_service.dart';
import '../utils/services/notification_service.dart';
import 'app_help_center.dart';
import 'couple_default_avatar.dart';

enum LocalGuideSurfaceType {
  home,
  diary,
  utilities,
  fun,
  update,
  settings,
  utility,
}

class LocalGuideSurface {
  const LocalGuideSurface({
    required this.type,
    required this.id,
    required this.titleKey,
    required this.summaryKey,
    required this.icon,
    this.detailKey,
    this.howToKey,
  });

  final LocalGuideSurfaceType type;
  final String id;
  final String titleKey;
  final String summaryKey;
  final IconData icon;
  final String? detailKey;
  final String? howToKey;

  bool get isUtility => type == LocalGuideSurfaceType.utility;
}

const LocalGuideSurface _localGuideUnknownSurface = LocalGuideSurface(
  type: LocalGuideSurfaceType.update,
  id: 'local_guide_help',
  titleKey: 'auth_help_center_guide',
  summaryKey: 'help_empty',
  icon: Icons.help_outline_rounded,
);

class LocalGuideSession {
  const LocalGuideSession({required this.uid, required this.houseId});

  final String uid;
  final String houseId;

  @override
  bool operator ==(Object other) {
    return other is LocalGuideSession &&
        other.uid == uid &&
        other.houseId == houseId;
  }

  @override
  int get hashCode => Object.hash(uid, houseId);
}

class LocalGuideSessionNotifier extends ChangeNotifier {
  LocalGuideSessionNotifier._();

  static final LocalGuideSessionNotifier instance =
      LocalGuideSessionNotifier._();

  LocalGuideSession? _session;

  LocalGuideSession? get session => _session;

  void activate({required String uid, required String houseId}) {
    final normalizedUid = uid.trim();
    final normalizedHouseId = houseId.trim();
    if (normalizedUid.isEmpty || normalizedHouseId.isEmpty) return;
    final next = LocalGuideSession(
      uid: normalizedUid,
      houseId: normalizedHouseId,
    );
    if (_session == next) return;
    _session = next;
    LocalGuideContextNotifier.instance.setHomeTab(0);
    notifyListeners();
  }

  void deactivate({required String uid, required String houseId}) {
    final current = _session;
    if (current == null ||
        (current.uid == uid.trim() && current.houseId == houseId.trim())) {
      if (current == null) return;
      _session = null;
      notifyListeners();
    }
  }
}

class LocalGuideSessionHost extends StatefulWidget {
  const LocalGuideSessionHost({
    super.key,
    required this.uid,
    required this.houseId,
    required this.child,
  });

  final String uid;
  final String houseId;
  final Widget child;

  @override
  State<LocalGuideSessionHost> createState() => _LocalGuideSessionHostState();
}

class _LocalGuideSessionHostState extends State<LocalGuideSessionHost> {
  @override
  void dispose() {
    LocalGuideSessionNotifier.instance.deactivate(
      uid: widget.uid,
      houseId: widget.houseId,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Trạng thái màn hình hiện tại của trợ thủ. Chỉ là state trong app, không ghi
/// RTDB/Firestore và không gửi nội dung màn hình ra ngoài.
class LocalGuideContextNotifier extends ChangeNotifier {
  LocalGuideContextNotifier._();

  static final LocalGuideContextNotifier instance =
      LocalGuideContextNotifier._();

  LocalGuideSurface _surface = const LocalGuideSurface(
    type: LocalGuideSurfaceType.home,
    id: 'home',
    titleKey: 'home_tab',
    summaryKey: 'home_trangchltr_ffe72e',
    icon: Icons.home_rounded,
    detailKey: 'home_daily_couple_description',
    howToKey: 'home_bmsngychnh_cf2261',
  );

  LocalGuideSurface get surface => _surface;

  void setHomeTab(int index) {
    final next = switch (index) {
      1 => const LocalGuideSurface(
        type: LocalGuideSurfaceType.diary,
        id: 'diary',
        titleKey: 'diary_tab',
        summaryKey: 'update_hub_memories_note',
        icon: Icons.menu_book_rounded,
        detailKey: 'update_hub_memories_note',
        howToKey: 'starter_memory_body',
      ),
      2 => const LocalGuideSurface(
        type: LocalGuideSurfaceType.utilities,
        id: 'utilities',
        titleKey: 'nav_apps',
        summaryKey: 'update_hub_tools_note',
        icon: Icons.widgets_rounded,
        detailKey: 'help_utilities_body',
        howToKey: 'update_hub_tools_note',
      ),
      3 => const LocalGuideSurface(
        type: LocalGuideSurfaceType.fun,
        id: 'fun',
        titleKey: 'game_tab',
        summaryKey: 'p9_game_subtitle',
        icon: Icons.sports_esports_rounded,
        detailKey: 'p9_game_subtitle',
        howToKey: 'memory_puzzle_gesture_guide',
      ),
      4 => const LocalGuideSurface(
        type: LocalGuideSurfaceType.update,
        id: 'update',
        titleKey: 'nav_update',
        summaryKey: 'update_hub_welcome_note',
        icon: Icons.auto_awesome_rounded,
        detailKey: 'update_hub_features_hint',
        howToKey: 'update_hub_welcome_note',
      ),
      _ => const LocalGuideSurface(
        type: LocalGuideSurfaceType.home,
        id: 'home',
        titleKey: 'home_tab',
        summaryKey: 'home_trangchltr_ffe72e',
        icon: Icons.home_rounded,
        detailKey: 'home_daily_couple_description',
        howToKey: 'home_bmsngychnh_cf2261',
      ),
    };
    _setSurface(next);
  }

  void setSettings() {
    _setSurface(_settingsSurface);
  }

  void setUtility(String id) {
    final surface = _utilitySurfaces[id];
    if (surface != null) _setSurface(surface);
  }

  LocalGuideSurface? surfaceForRouteType(String routeType) {
    final surfaceId = _routeSurfaceIds[routeType];
    if (surfaceId == 'settings') return _settingsSurface;
    if (surfaceId == 'couple_connect') {
      return _utilitySurfaces['couple_connect'];
    }
    return surfaceId == null ? null : _utilitySurfaces[surfaceId];
  }

  static const LocalGuideSurface _settingsSurface = LocalGuideSurface(
    type: LocalGuideSurfaceType.settings,
    id: 'settings',
    titleKey: 'settings',
    summaryKey: 'home_citchatikh_dada1e',
    icon: Icons.settings_rounded,
    detailKey: 'settings_account_desc',
    howToKey: 'settings_menu_guide_desc',
  );

  static const Map<String, String> _routeSurfaceIds = {
    'SettingsTab': 'settings',
    'SettingsLinksManagerScreen': 'couple_connect',
    'LocalAlbumScreen': 'local_album',
    'CollageMakerScreen': 'collage',
    'CinemaScreen': 'cinema',
    'CreativeDiaryScreen': 'creative_diary',
    'LoveCardScreen': 'surprise_maker',
    'CapsuleScreen': 'capsule',
    'CalendarScreen': 'calendar',
    'SharedNotesScreen': 'note',
    'FinanceScreen': 'finance',
    'VoiceScreen': 'voice',
    'HabitScreen': 'habit',
    'HealthScreen': 'health',
    'SleepTrackerScreen': 'sleep_tracker',
    'TarotScreen': 'tarot',
    'WheelScreen': 'wheel',
    'DrawingStudioScreen': 'drawing',
    'FriendlyChatScreen': 'friendly_chat',
    'SecretVaultScreen': 'vault',
    'DiaryExportScreen': 'diary_export',
    'RewardStoreScreen': 'store',
    'SoulEventsScreen': 'soul_events',
  };

  void _setSurface(LocalGuideSurface next) {
    if (_surface.id == next.id && _surface.type == next.type) return;
    _surface = next;
    notifyListeners();
  }

  static const Map<String, LocalGuideSurface> _utilitySurfaces = {
    'local_album': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'local_album',
      titleKey: 'util_luunhtbit_6f4b4a',
      summaryKey: 'local_album_empty_desc',
      icon: Icons.photo_library_rounded,
      detailKey: 'local_album_notice',
      howToKey: 'local_album_source_photos_desc',
    ),
    'collage': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'collage',
      titleKey: 'utility_title_collage',
      summaryKey: 'collage_subtitle',
      icon: Icons.collections_rounded,
      detailKey: 'collage_subtitle',
      howToKey: 'collage_tap_select_photos',
    ),
    'cinema': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'cinema',
      titleKey: 'utility_title_cinema',
      summaryKey: 'cinema_teaser_body',
      icon: Icons.movie_creation_rounded,
      detailKey: 'p8_cinema_dialog_feature_body',
      howToKey: 'p8_cinema_dialog_how_to_body',
    ),
    'creative_diary': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'creative_diary',
      titleKey: 'utility_title_creative_diary',
      summaryKey: 'creative_diary_memory_question',
      icon: Icons.auto_stories_rounded,
      detailKey: 'update_hub_memories_note',
      howToKey: 'creative_diary_memory_question',
    ),
    'surprise_maker': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'surprise_maker',
      titleKey: 'utility_title_surprise',
      summaryKey: 'love_card_info_create_body',
      icon: Icons.card_giftcard_rounded,
      detailKey: 'love_card_info_create_body',
      howToKey: 'love_card_info_share_body',
    ),
    'capsule': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'capsule',
      titleKey: 'utility_title_capsule',
      summaryKey: 'p3_capsule_help_features',
      icon: Icons.mark_email_unread_rounded,
      detailKey: 'p3_capsule_help_features',
      howToKey: 'p3_capsule_help_how_to',
    ),
    'calendar': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'calendar',
      titleKey: 'utility_title_calendar',
      summaryKey: 'utilities_desc_calendar',
      icon: Icons.calendar_month_rounded,
      detailKey: 'calendar_hero_desc',
      howToKey: 'calendar_add_plan_desc',
    ),
    'note': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'note',
      titleKey: 'utility_title_note',
      summaryKey: 'search_utility_subtitle_note',
      icon: Icons.description_rounded,
      detailKey: 'home_note_edit_rule',
      howToKey: 'home_note_tap_to_write',
    ),
    'finance': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'finance',
      titleKey: 'utility_title_finance',
      summaryKey: 'p8_finance_info_features_body',
      icon: Icons.account_balance_wallet_rounded,
      detailKey: 'p8_finance_info_features_body',
      howToKey: 'p8_finance_info_how_to_body',
    ),
    'voice': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'voice',
      titleKey: 'utility_title_voice',
      summaryKey: 'voice_help_features',
      icon: Icons.mic_none_rounded,
      detailKey: 'voice_help_features',
      howToKey: 'voice_help_steps',
    ),
    'couple_connect': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'couple_connect',
      titleKey: 'starter_pairing_title',
      summaryKey: 'starter_pairing_body',
      icon: Icons.link_rounded,
      detailKey: 'pairing_ui_dashboard_subtitle',
      howToKey: 'starter_pairing_body',
    ),
    'habit': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'habit',
      titleKey: 'utility_title_habit',
      summaryKey: 'utilities_desc_habit',
      icon: Icons.check_circle_outline_rounded,
      detailKey: 'p3_habit_hero_subtitle',
      howToKey: 'util_habit_help_body',
    ),
    'health': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'health',
      titleKey: 'utility_title_health',
      summaryKey: 'utilities_desc_health',
      icon: Icons.favorite_border_rounded,
      detailKey: 'p3_health_consent_body',
      howToKey: 'p3_health_mark_today_subtitle',
    ),
    'sleep_tracker': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'sleep_tracker',
      titleKey: 'utility_title_sleep',
      summaryKey: 'utilities_desc_sleep',
      icon: Icons.bedtime_outlined,
      detailKey: 'sleep_tracking_consent',
      howToKey: 'sleep_tracking_manual_hint',
    ),
    'tarot': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'tarot',
      titleKey: 'utility_title_tarot',
      summaryKey: 'tarot_empty_desc',
      icon: Icons.auto_awesome_rounded,
      detailKey: 'tarot2_hero_desc',
      howToKey: 'tarot2_guide_intro',
    ),
    'wheel': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'wheel',
      titleKey: 'utility_title_wheel',
      summaryKey: 'utilities_daily_wheel_subtitle',
      icon: Icons.casino_outlined,
      detailKey: 'utilities_daily_wheel_subtitle',
      howToKey: 'wheel_choices_hint',
    ),
    'drawing': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'drawing',
      titleKey: 'utility_title_drawing',
      summaryKey: 'p8_drawing_info_features_body',
      icon: Icons.brush_rounded,
      detailKey: 'p8_drawing_info_features_body',
      howToKey: 'p8_drawing_info_how_to_body',
    ),
    'friendly_chat': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'friendly_chat',
      titleKey: 'utility_title_friendly_chat',
      summaryKey: 'search_utility_subtitle_friendly_chat',
      icon: Icons.chat_bubble_outline_rounded,
      detailKey: 'friendly_chat_privacy_desc',
      howToKey: 'friendly_chat_starter_label',
    ),
    'vault': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'vault',
      titleKey: 'utility_title_vault',
      summaryKey: 'utilities_desc_vault',
      icon: Icons.lock_outline_rounded,
      detailKey: 'help_security_body',
      howToKey: 'support_guide_privacy_vault_steps',
    ),
    'diary_export': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'diary_export',
      titleKey: 'utility_title_diary_export',
      summaryKey: 'utilities_desc_diary_export',
      icon: Icons.file_download_outlined,
      detailKey: 'diary_export_help_features',
      howToKey: 'diary_export_guide_choose',
    ),
    'store': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'store',
      titleKey: 'utility_title_store',
      summaryKey: 'utilities_desc_store',
      icon: Icons.redeem_rounded,
      detailKey: 'reward_store_missions_hint',
      howToKey: 'reward_store_streak_hint',
    ),
    'soul_events': LocalGuideSurface(
      type: LocalGuideSurfaceType.utility,
      id: 'soul_events',
      titleKey: 'copy_fc725e371ce1',
      summaryKey: 'theme_event_anniversary_section_desc',
      icon: Icons.event_note_rounded,
      detailKey: 'theme_event_anniversary_section_desc',
      howToKey: 'theme_event_calendar_section_desc',
    ),
  };
}

class LocalGuideTrial {
  const LocalGuideTrial._();

  static const trialDuration = Duration(days: 3);
  static const tipGap = Duration(minutes: 15);
  static const snoozeDuration = Duration(hours: 4);
  static const daySnoozeDuration = Duration(days: 1);
  static const maxTipsPerDay = 4;

  static String _scope(String? uid) =>
      uid == null || uid.trim().isEmpty ? 'device' : uid.trim();

  static String startKey(String? uid) =>
      'local_guide_companion_started_at_${_scope(uid)}';

  static String lastTipKey(String? uid) =>
      'local_guide_companion_last_tip_${_scope(uid)}';

  static String snoozeKey(String? uid) =>
      'local_guide_companion_snooze_until_${_scope(uid)}';

  static String countKey(String? uid, DateTime now) =>
      'local_guide_companion_count_${_scope(uid)}_${now.year}_${now.month}_${now.day}';

  static Future<DateTime> ensureStarted(
    SharedPreferences prefs,
    String? uid,
    DateTime now,
  ) async {
    final key = startKey(uid);
    final saved = prefs.getInt(key);
    if (saved != null && saved > 0) {
      return DateTime.fromMillisecondsSinceEpoch(saved);
    }
    await prefs.setInt(key, now.millisecondsSinceEpoch);
    return now;
  }

  static bool isActive(DateTime startedAt, DateTime now) =>
      now.isBefore(startedAt.add(trialDuration));

  static bool canShowTip(SharedPreferences prefs, String? uid, DateTime now) {
    final lastTip = prefs.getInt(lastTipKey(uid));
    if (lastTip != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(lastTip)) < tipGap) {
      return false;
    }
    final snooze = prefs.getInt(snoozeKey(uid));
    if (snooze != null &&
        now.isBefore(DateTime.fromMillisecondsSinceEpoch(snooze))) {
      return false;
    }
    return (prefs.getInt(countKey(uid, now)) ?? 0) < maxTipsPerDay;
  }

  static Future<void> recordTip(
    SharedPreferences prefs,
    String? uid,
    DateTime now,
  ) async {
    await prefs.setInt(lastTipKey(uid), now.millisecondsSinceEpoch);
    final key = countKey(uid, now);
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  static Future<void> snooze(
    SharedPreferences prefs,
    String? uid,
    DateTime now,
  ) => prefs.setInt(
    snoozeKey(uid),
    now.add(snoozeDuration).millisecondsSinceEpoch,
  );

  static Future<void> snoozeForDay(
    SharedPreferences prefs,
    String? uid,
    DateTime now,
  ) => prefs.setInt(
    snoozeKey(uid),
    now.add(daySnoozeDuration).millisecondsSinceEpoch,
  );
}

class LocalGuideCompanionOverlay extends StatefulWidget {
  const LocalGuideCompanionOverlay({
    super.key,
    required this.child,
    this.authenticatedOnly = true,
  });

  final Widget child;
  final bool authenticatedOnly;

  @override
  State<LocalGuideCompanionOverlay> createState() =>
      _LocalGuideCompanionOverlayState();
}

class _LocalGuideCompanionOverlayState extends State<LocalGuideCompanionOverlay>
    with WidgetsBindingObserver {
  final _contextNotifier = LocalGuideContextNotifier.instance;
  SharedPreferences? _prefs;
  Timer? _tipTimer;
  Timer? _hideTimer;
  Timer? _expiryTimer;
  LocalGuideSession? _session;
  DateTime? _trialStartedAt;
  bool _tipVisible = false;
  bool _loading = true;
  int _generation = 0;
  Offset _bubbleOffset = Offset.zero;

  bool get _sessionReady => !widget.authenticatedOnly || _session != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _contextNotifier.addListener(_onContextChanged);
    LocalGuideSessionNotifier.instance.addListener(_onSessionChanged);
    LocalGuideRouteTracker.instance.addListener(_onRouteChanged);
    _session = LocalGuideSessionNotifier.instance.session;
    unawaited(_loadTrial());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _contextNotifier.removeListener(_onContextChanged);
    LocalGuideSessionNotifier.instance.removeListener(_onSessionChanged);
    LocalGuideRouteTracker.instance.removeListener(_onRouteChanged);
    _tipTimer?.cancel();
    _hideTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleTip(delay: const Duration(seconds: 2));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _tipTimer?.cancel();
      _hideTimer?.cancel();
      if (mounted && _tipVisible) setState(() => _tipVisible = false);
    }
  }

  void _onSessionChanged() {
    if (!mounted) return;
    final next = LocalGuideSessionNotifier.instance.session;
    if (next == _session) return;
    _session = next;
    _tipVisible = false;
    _loading = true;
    _tipTimer?.cancel();
    _hideTimer?.cancel();
    _expiryTimer?.cancel();
    unawaited(_loadTrial());
    setState(() {});
  }

  void _onContextChanged() {
    if (!mounted) return;
    _tipVisible = false;
    _hideTimer?.cancel();
    setState(() {});
    _scheduleTip(delay: const Duration(milliseconds: 1400));
  }

  void _onRouteChanged() {
    if (!mounted) return;
    _tipVisible = false;
    _hideTimer?.cancel();
    setState(() {});
    _scheduleTip(delay: const Duration(milliseconds: 1400));
  }

  Future<void> _loadTrial() async {
    final generation = ++_generation;
    final session = _session;
    if (widget.authenticatedOnly && session == null) {
      _prefs = null;
      _trialStartedAt = null;
      _loading = false;
      if (mounted) setState(() {});
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final started = await LocalGuideTrial.ensureStarted(
        prefs,
        session?.uid,
        now,
      );
      if (!mounted || generation != _generation || session != _session) return;
      _prefs = prefs;
      _trialStartedAt = started;
      _loading = false;
      setState(() {});
      _scheduleExpiry(started);
      _scheduleTip(delay: const Duration(milliseconds: 1200));
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _loading = false;
      setState(() {});
    }
  }

  void _scheduleExpiry(DateTime started) {
    _expiryTimer?.cancel();
    final remaining = started
        .add(LocalGuideTrial.trialDuration)
        .difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) return;
    _expiryTimer = Timer(remaining, () {
      if (!mounted) return;
      _tipTimer?.cancel();
      _hideTimer?.cancel();
      setState(() {
        _trialStartedAt = null;
        _tipVisible = false;
      });
    });
  }

  void _scheduleTip({required Duration delay}) {
    _tipTimer?.cancel();
    if (!_sessionReady ||
        LocalGuideRouteTracker.instance.hasModal ||
        _loading ||
        _prefs == null ||
        _trialStartedAt == null ||
        _visibleSurface == null) {
      return;
    }
    _tipTimer = Timer(delay, _showTipIfAllowed);
  }

  Future<void> _showTipIfAllowed() async {
    final prefs = _prefs;
    final started = _trialStartedAt;
    final uid = _session?.uid;
    final now = DateTime.now();
    if (!mounted ||
        prefs == null ||
        started == null ||
        !_sessionReady ||
        LocalGuideRouteTracker.instance.hasModal ||
        _visibleSurface == null ||
        !LocalGuideTrial.isActive(started, now) ||
        !LocalGuideTrial.canShowTip(prefs, uid, now)) {
      return;
    }
    final generation = _generation;
    await LocalGuideTrial.recordTip(prefs, uid, now);
    if (!mounted || generation != _generation) return;
    _tipVisible = true;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() => _tipVisible = false);
    });
    setState(() {});
  }

  void _snoozeTipForDay() {
    final prefs = _prefs;
    final uid = _session?.uid;
    if (prefs != null && uid != null) {
      unawaited(LocalGuideTrial.snoozeForDay(prefs, uid, DateTime.now()));
    }
    _hideTimer?.cancel();
    setState(() => _tipVisible = false);
  }

  Future<void> _openChat() async {
    _hideTimer?.cancel();
    setState(() => _tipVisible = false);
    final navigator = NotificationService.navigatorKey.currentState;
    final sheetContext = navigator?.overlay?.context;
    if (navigator == null || sheetContext == null || !sheetContext.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: sheetContext,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocalGuideChatSheet(surface: _visibleSurface!),
    );
    if (mounted) _scheduleTip(delay: const Duration(minutes: 2));
  }

  LocalGuideSurface? get _visibleSurface {
    final routeType = LocalGuideRouteTracker.instance.activeScreenType;
    if (routeType != null) {
      return _contextNotifier.surfaceForRouteType(routeType);
    }
    return _contextNotifier.surface;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final surface = _visibleSurface;
    final show =
        _sessionReady &&
        !_loading &&
        _trialStartedAt != null &&
        surface != null &&
        !LocalGuideRouteTracker.instance.hasModal &&
        LocalGuideTrial.isActive(_trialStartedAt!, DateTime.now());
    final messageWidth = math.max(
      160,
      math.min(300, media.width - 12 - 64 - 4 - 12),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (show)
          PositionedDirectional(
            end: 12,
            bottom: math.max(MediaQuery.paddingOf(context).bottom + 76, 88),
            child: Transform.translate(
              offset: _bubbleOffset,
              child: _LocalGuideFloatingCard(
                surface: surface,
                expanded: _tipVisible,
                maxWidth: messageWidth.toDouble(),
                onChat: _openChat,
                onDismiss: _snoozeTipForDay,
                onDrag: (delta) {
                  final size = MediaQuery.sizeOf(context);
                  final next = _bubbleOffset + delta;
                  final maxX = math.max(0, size.width - 92);
                  final maxY = math.max(0, size.height - 190);
                  setState(() {
                    _bubbleOffset = Offset(
                      next.dx.clamp(-maxX, 12).toDouble(),
                      next.dy.clamp(-maxY, 12).toDouble(),
                    );
                  });
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _LocalGuideFloatingCard extends StatefulWidget {
  const _LocalGuideFloatingCard({
    required this.surface,
    required this.expanded,
    required this.maxWidth,
    required this.onChat,
    required this.onDismiss,
    required this.onDrag,
  });

  final LocalGuideSurface surface;
  final bool expanded;
  final double maxWidth;
  final VoidCallback onChat;
  final VoidCallback onDismiss;
  final ValueChanged<Offset> onDrag;

  @override
  State<_LocalGuideFloatingCard> createState() =>
      _LocalGuideFloatingCardState();
}

class _LocalGuideFloatingCardState extends State<_LocalGuideFloatingCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motionController;
  bool _foreground = true;
  bool _motionEnabled = false;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    final enabled =
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (enabled == _motionEnabled) return;
    _motionEnabled = enabled;
    if (enabled) {
      _motionController.repeat();
    } else {
      _motionController.stop();
      _motionController.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motionController.dispose();
    super.dispose();
  }

  Widget _buildBubble(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onPanUpdate: (details) => widget.onDrag(details.delta),
        child: InkWell(
          onTap: widget.onChat,
          customBorder: const CircleBorder(),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFB5C8), Color(0xFFBFAEFF)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: .92),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .28),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: ClipOval(
                    child: SizedBox.square(
                      dimension: 45,
                      child: CoupleDefaultAvatar(
                        female: true,
                        animate: _motionEnabled,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 3,
                  right: 7,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: .95),
                  ),
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .9),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: context.tr('home_trltinch_918abe'),
      button: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            // Không dùng đường cong vượt 1 (easeOutBack) ở đây: transitionBuilder
            // đã tự áp easeOutBack cho scale, áp chồng sẽ đưa giá trị > 1 vào
            // CurvedAnimation và Flutter báo lỗi liên tục.
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final scale = Tween<double>(begin: .82, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              );
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: scale, child: child),
              );
            },
            child: widget.expanded
                ? ConstrainedBox(
                    key: const ValueKey('local-guide-tip'),
                    constraints: BoxConstraints(maxWidth: widget.maxWidth),
                    child: Material(
                      color: colors.surface,
                      elevation: 7,
                      shadowColor: colors.primary.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 18,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    context.tr(widget.surface.titleKey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: context.tr('region_time_24'),
                                  onPressed: widget.onDismiss,
                                  icon: const Icon(
                                    Icons.visibility_off_rounded,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              context.tr(widget.surface.summaryKey),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton.icon(
                                onPressed: widget.onChat,
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                ),
                                label: Text(context.tr('auth_guide_short')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('local-guide-empty')),
          ),
          const SizedBox(width: 8),
          _buildBubble(context),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phase = _motionEnabled ? _motionController.value : 0.0;
    final bob = math.sin(phase * math.pi * 2) * 3;
    return Transform.translate(
      offset: Offset(0, bob),
      child: _buildContent(context),
    );
  }
}

enum _GuideAnswerFocus { overview, features, howTo }

class LocalGuideChatSheet extends StatefulWidget {
  const LocalGuideChatSheet({super.key, required this.surface});

  final LocalGuideSurface surface;

  @override
  State<LocalGuideChatSheet> createState() => _LocalGuideChatSheetState();
}

class _LocalGuideChatSheetState extends State<LocalGuideChatSheet> {
  final _controller = TextEditingController();
  String? _answerKey;
  LocalGuideSurface? _answerSurface;
  String? _lastQuestion;
  _GuideAnswerFocus _answerFocus = _GuideAnswerFocus.overview;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask([String? value, _GuideAnswerFocus? requestedFocus]) {
    final query = (value ?? _controller.text).trim();
    final matchedSurface = _findSurface(query);
    final focus = requestedFocus ?? _focusForQuery(query);
    final isUnknown =
        matchedSurface == null &&
        query.isNotEmpty &&
        requestedFocus == null &&
        focus == _GuideAnswerFocus.overview;
    final surface = isUnknown
        ? _localGuideUnknownSurface
        : (matchedSurface ?? widget.surface);
    final answerKey = switch (focus) {
      _GuideAnswerFocus.features => surface.detailKey ?? surface.summaryKey,
      _GuideAnswerFocus.howTo => surface.howToKey ?? surface.summaryKey,
      _GuideAnswerFocus.overview => surface.summaryKey,
    };
    setState(() {
      _answerSurface = surface;
      _answerKey = isUnknown ? 'help_empty' : answerKey;
      _answerFocus = isUnknown ? _GuideAnswerFocus.overview : focus;
      _lastQuestion = query.isEmpty ? null : query;
    });
    _controller.clear();
  }

  LocalGuideSurface? _findSurface(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return widget.surface;
    final surfaces = <String, LocalGuideSurface>{
      widget.surface.id: widget.surface,
      LocalGuideContextNotifier.instance.surface.id:
          LocalGuideContextNotifier.instance.surface,
      ...LocalGuideContextNotifier._utilitySurfaces,
    }.values;
    LocalGuideSurface? bestSurface;
    var bestScore = 0;
    for (final surface in surfaces) {
      final title = _normalize(context.tr(surface.titleKey));
      final id = _normalize(surface.id.replaceAll('_', ' '));
      final aliases = <String>[id, title];
      final score = aliases.fold<int>(0, (current, alias) {
        if (alias.isEmpty) return current;
        if (normalized.contains(alias) || alias.contains(normalized)) {
          return current + 10;
        }
        return current +
            normalized
                .split(' ')
                .where((word) => word.length > 2 && alias.contains(word))
                .length;
      });
      if (score > bestScore) {
        bestScore = score;
        bestSurface = surface;
      }
    }
    if (bestSurface != null) return bestSurface;
    if (_isGenericQuestion(normalized)) return widget.surface;
    return null;
  }

  bool _isGenericQuestion(String normalized) {
    const markers = [
      'man hinh',
      'dang o dau',
      'o dau',
      'lam gi',
      'chuc nang',
      'trang nay',
      'nut',
      'icon',
      'tinh nang',
      'cach',
      'su dung',
      'bam',
      'cham',
      'mo',
      'tao',
      'them',
      'luu',
      'chon',
    ];
    return markers.any(normalized.contains);
  }

  _GuideAnswerFocus _focusForQuery(String query) {
    final normalized = _normalize(query);
    const featureMarkers = [
      'lam gi',
      'chuc nang',
      'tinh nang',
      'icon',
      'tac dung',
      'co gi',
    ];
    const howToMarkers = [
      'cach',
      'su dung',
      'bam',
      'cham',
      'tao',
      'them',
      'luu',
      'chon',
      'mo',
      'dung nhu nao',
    ];
    if (featureMarkers.any(normalized.contains)) {
      return _GuideAnswerFocus.features;
    }
    if (howToMarkers.any(normalized.contains)) {
      return _GuideAnswerFocus.howTo;
    }
    return _GuideAnswerFocus.overview;
  }

  String _normalize(String value) {
    var result = value.toLowerCase().trim();
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵäå',
      'e': 'èéẹẻẽêềếệểễë',
      'i': 'ìíịỉĩîï',
      'o': 'òóọỏõôồốộổỗơờớợởỡö',
      'u': 'ùúụủũưừứựửữûü',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    for (final entry in groups.entries) {
      for (final rune in entry.value.runes) {
        result = result.replaceAll(String.fromCharCode(rune), entry.key);
      }
    }
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _openGuide() async {
    Navigator.of(context).pop();
    await Future<void>.delayed(Duration.zero);
    final rootContext =
        NotificationService.navigatorKey.currentState?.overlay?.context;
    if (rootContext == null || !rootContext.mounted) return;
    await slPush<void>(rootContext, const AppHelpCenterScreen());
  }

  @override
  Widget build(BuildContext context) {
    final surface = _answerSurface ?? widget.surface;
    final answerKey = _answerKey;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .84,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('home_trltinch_918abe'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('close'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    context.tr('help_intro'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_lastQuestion != null) ...[
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 290),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: const BorderRadiusDirectional.only(
                            topStart: Radius.circular(16),
                            topEnd: Radius.circular(16),
                            bottomStart: Radius.circular(16),
                          ),
                        ),
                        child: Text(_lastQuestion!),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _GuideAnswerCard(
                    surface: surface,
                    answerKey: answerKey,
                    focus: _answerFocus,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('update_hub_features_hint'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _GuideChoiceButton(
                    icon: surface.icon,
                    label: context.tr(surface.titleKey),
                    selected: _answerFocus == _GuideAnswerFocus.overview,
                    onPressed: () => _ask(context.tr(surface.titleKey)),
                  ),
                  _GuideChoiceButton(
                    icon: Icons.auto_awesome_rounded,
                    label: context.tr('update_hub_features'),
                    selected: _answerFocus == _GuideAnswerFocus.features,
                    onPressed: () => _ask(
                      context.tr('update_hub_features'),
                      _GuideAnswerFocus.features,
                    ),
                  ),
                  _GuideChoiceButton(
                    icon: Icons.lightbulb_outline_rounded,
                    label: context.tr('auth_guide_short'),
                    selected: _answerFocus == _GuideAnswerFocus.howTo,
                    onPressed: () => _ask(
                      context.tr('auth_guide_short'),
                      _GuideAnswerFocus.howTo,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: _openGuide,
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: Text(context.tr('update_hub_guide')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('core_done'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideChoiceButton extends StatelessWidget {
  const _GuideChoiceButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            alignment: AlignmentDirectional.centerStart,
            foregroundColor: selected ? colors.primary : colors.onSurface,
            backgroundColor: selected
                ? colors.primaryContainer.withValues(alpha: .38)
                : null,
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideAnswerCard extends StatelessWidget {
  const _GuideAnswerCard({
    required this.surface,
    required this.answerKey,
    required this.focus,
  });

  final LocalGuideSurface surface;
  final String? answerKey;
  final _GuideAnswerFocus focus;

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String labelKey,
    required String textKey,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr(labelKey),
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(context.tr(textKey), style: const TextStyle(height: 1.35)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summaryKey = answerKey ?? surface.summaryKey;
    final detailKey = surface.detailKey;
    final howToKey = surface.howToKey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .44),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(surface.icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(surface.titleKey),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (focus == _GuideAnswerFocus.overview &&
                    (detailKey == null || summaryKey != detailKey)) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.tr(summaryKey),
                    style: const TextStyle(height: 1.35),
                  ),
                ],
                if (detailKey != null &&
                    (focus == _GuideAnswerFocus.overview ||
                        focus == _GuideAnswerFocus.features))
                  _section(
                    context,
                    icon: Icons.auto_awesome_rounded,
                    labelKey: 'p3_help_features_label',
                    textKey: detailKey,
                  ),
                if (howToKey != null &&
                    (focus == _GuideAnswerFocus.overview ||
                        focus == _GuideAnswerFocus.howTo))
                  _section(
                    context,
                    icon: Icons.lightbulb_outline_rounded,
                    labelKey: 'p3_help_how_to_label',
                    textKey: howToKey,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
