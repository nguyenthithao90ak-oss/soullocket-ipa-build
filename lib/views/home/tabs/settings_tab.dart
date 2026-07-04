// ignore_for_file: unused_field
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/fast_backdrop_filter.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../screens/document_viewer_screen.dart';
import '../screens/global_search_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../login_screen.dart';
import '../../app_entry.dart';
import 'package:soullocket_app/views/chat/chat_detail_screen.dart';
import 'package:soullocket_app/views/home/widgets/soul_merge_screen.dart'
    show TapHeartsOverlay, TapHeartsOverlayState;
import 'package:image_cropper/image_cropper.dart';

import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, kDebugMode;
import '../../../utils/services/notification_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/sl_theme.dart';
import '../../../core/sl_route.dart';
import '../../../utils/services/house_settings_service.dart';
import '../../../utils/services/location_service.dart';
import '../../../utils/services/music_service.dart';
import '../../../utils/services/purchase_service.dart';
import '../../../utils/services/schedule_notif_service.dart';
import '../../../utils/services/settings_sync_service.dart';
import '../../../utils/services/storage_service.dart';
import '../../../utils/services/cloudflare_r2_service.dart';
import '../../../utils/services/soul_merge_service.dart';
import '../../../utils/services/countdown_space_service.dart';
import '../../../models/data_export_result.dart';
import '../../../utils/services/data_export_service.dart';
import '../../../utils/services/friends_service.dart';
import '../../relationship/couple_connect_screen.dart';
import '../../ui_prefs.dart';
import '../../premium/premium_store_screen.dart';
import '../../utilities/age_zodiac_screen.dart';
import '../../utilities/bucket_list_screen.dart';
import '../../utilities/calculator_screen.dart';
import '../../utilities/calendar_screen.dart';
import '../../utilities/capsule_screen.dart';
import '../../utilities/cinema_screen.dart';
import '../../utilities/collage_maker_screen.dart';
import '../../utilities/creative_diary_screen.dart';
import '../../utilities/drawing_studio_screen.dart';
import '../../utilities/finance_screen.dart';
import '../../utilities/friendly_chat_screen.dart';
import '../../utilities/gift_maker_screen.dart';
import '../../utilities/giftcode_screen.dart';
import '../../utilities/habit_screen.dart';
import '../../utilities/history_screen.dart';
import '../../utilities/love_card_screen.dart';
import '../../utilities/reward_store_screen.dart';
import '../../utilities/secret_vault_screen.dart';
import '../../utilities/shared_notes_screen.dart';
import '../../../features/tarot/tarot_screen.dart';
import '../../utilities/voice_screen.dart';
import '../../../features/wheel/wheel_screen.dart';
import '../../utilities/wishlist_screen.dart';
import '../../utilities/diary_export_screen.dart';
import '../../utilities/device_manager_screen.dart';
// import '../../auth/qr_authorize_scanner_screen.dart';
import '../../utilities/user_support_chat_screen.dart';
import 'settings/settings_gift_links_manager_screen.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/services/auth_service.dart';
import '../../../utils/services/device_manager_service.dart';
import '../../../utils/services/presence_service.dart';
import '../../../utils/services/security_flow_guard.dart';
import '../../../utils/services/admob_service.dart';
import '../../../utils/services/breakup_service.dart';
import '../../../utils/services/critical_data_sync_service.dart';
import '../../../utils/services/house_service.dart';
import '../../../utils/services/military_lock_service.dart';
import '../../../utils/services/push_notification_helper.dart';
import '../../../utils/services/role_utils.dart';
import 'package:soullocket_app/models/soul_event.dart';
import '../../../utils/services/soul_event_service.dart';
import '../../../utils/services/qr_payload_codec.dart';
import '../../../utils/services/sound_service.dart';
import '../../../utils/services/utility_service.dart';
import 'settings/controllers/settings_security_controller.dart';
import 'settings/security/security_otp_dialogs.dart';
import '../../../widgets/first_setup_spotlight_guide.dart';
import '../../../widgets/legacy_web_ui.dart';
import '../../../widgets/pin_pad_setup_modal.dart';
import '../../../utils/services/widget_service.dart';
import '../../../models/house_settings.dart';

import '../../../core/constants/app_config.dart';
import '../../../utils/flexible_date_input.dart';
import '../../../utils/sl_notice.dart';
import '../../../utils/app_error_mapper.dart';
import '../../../utils/services/error_logger_service.dart';
import '../../../utils/services/pending_upload_service.dart';
import '../../../utils/services/app_lifecycle_presence_guard.dart';
import '../../../widgets/soul_locket_brand_mark.dart';
import '../../visitors/visitor_profile_screen.dart';
import 'settings/account/identity_panel.dart';
import 'main_home_tab.dart' show AnimatedWaveBackground, ShootingHeartEffect;
import 'settings/controllers/settings_identity_controller.dart';
import 'settings/controllers/settings_notifications_controller.dart';
import 'settings/controllers/settings_widget_controller.dart';
import 'settings/relationship/relationship_actions.dart';

part 'settings/settings_shared_widgets.dart';
part 'settings/settings_state_helpers.dart';
part 'settings/settings_persistence.dart';
part 'settings/settings_widget_persistence_part.dart';
part 'settings/settings_account_section.dart';
part 'settings/settings_identity_helpers_part.dart';
part 'settings/settings_security_section.dart';
part 'settings/security/security_action_flows_part.dart';
part 'settings/security/security_shared_widgets_part.dart';
part 'settings/security/security_lock_helpers_part.dart';
part 'settings/settings_theme_section.dart';
part 'settings/theme/theme_background_editor_part.dart';
part 'settings/theme/theme_preview_widgets_part.dart';
part 'settings/theme/theme_panel_actions_part.dart';
part 'settings/theme/theme_music_panel_part.dart';
part 'settings/theme/theme_panel_controls_part.dart';
part 'settings/theme/theme_event_preview_part.dart';
part 'settings/settings_widget_section.dart';
part 'settings/widget/widget_preview_part.dart';
part 'settings/widget/widget_actions_part.dart';
part 'settings/widget/widget_panel_helpers_part.dart';
part 'settings/countdown/settings_countdown_mode_screen.dart';
part 'settings/countdown/countdown_mode_state_handlers.dart';
part 'settings/countdown/countdown_mode_view_section.dart';
part 'settings/countdown/countdown_mode_models_part.dart';
part 'settings/countdown/countdown_mode_snapshot_codec_part.dart';
part 'settings/countdown/countdown_mode_editor_part.dart';
part 'settings/countdown/countdown_mode_editor_helpers_part.dart';
part 'settings/countdown/countdown_mode_dialogs_part.dart';
part 'settings/countdown/countdown_mode_shell_part.dart';
part 'settings/countdown/countdown_mode_widgets_part.dart';
part 'settings/countdown/countdown_mode_theme_part.dart';
part 'settings/countdown/countdown_mode_layout_section.dart';
part 'settings/settings_notifications_section.dart';
part 'settings/settings_relationship_section.dart';
part 'settings/settings_support_legal_section.dart';
part 'settings/settings_data_health_section.dart';
part 'settings/settings_shell.dart';

const Color _kSettingsBgTop = Color(0xFFEAF0F6);
const Color _kSettingsBgMid = Color(0xFFDCE4EE);
const Color _kSettingsBgBottom = Color(0xFFCDD8E6);
const Color _kSettingsHeaderBg = Color(0xFFE7EDF4);
const Color _kSettingsHeaderSurface = Color(0xFFF9FBFD);
const Color _kSettingsHeaderBorder = Color(0xFFBEC9D7);
const Color _kSettingsActionTileText = Color(0xFF243041);
const List<String> _widgetHeartStyleKeys = <String>[
  '🤍',
  '🤎',
  '♥️',
  '❣️',
  '❤️',
  '💞',
  '🖤',
  '💟',
  '❤️‍🔥',
  '🩷',
  '🩶',
  '🩵',
  '💘',
  '❤️‍🩹',
  '💓',
  '💗',
  '💖',
  '💝',
  '💌',
  '💋',
  '🫶',
  '🫀',
  '💫💗',
  '♡✦',
  '✧♥︎',
  '❥∞',
  'ღ♡',
  '☾♡',
  '♡🪽',
  '✦💘',
];
const String _defaultWidgetHeartStyleKey = '❤️';

const List<String> _widgetPreviewSizeKeys = <String>[
  'small',
  'medium',
  'large',
];
const List<String> _widgetDiaryLayoutKeys = <String>[
  'single',
  'duo',
  'grid',
];
const List<String> _widgetSeasonModeKeys = <String>[
  'auto',
  'none',
  'valentine',
  'anniversary',
  'birthday',
];

String _normalizeWidgetHeartStyleKey(String? value) {
  final normalized = (value ?? '').trim();
  if (_widgetHeartStyleKeys.contains(normalized)) {
    return normalized;
  }

  switch (normalized) {
    case 'classic':
    case 'duo':
    case 'sparkle':
    case 'orbit':
    case 'wing':
    default:
      return _defaultWidgetHeartStyleKey;
  }
}

String _widgetPreviewSizeLabel(String key) {
  switch (key) {
    case 'small':
      return L10nService().translate('home_nh_4c0e81');
    case 'large':
      return L10nService().translate('home_ln_41d05f');
    case 'medium':
    default:
      return L10nService().translate('home_va_74ffe0');
  }
}

String _widgetStyleLabel(String key) {
  switch (key) {
    case 'countdown':
      return 'Đếm ngày';
    case 'classic':
    default:
      return 'Mặc định';
  }
}

String _widgetDiaryLayoutLabel(String key) {
  switch (key) {
    case 'duo':
      return L10nService().translate('home_2nhi_804ddf');
    case 'grid':
      return L10nService().translate('home_collage4nh_f50ff1');
    case 'single':
    default:
      return L10nService().translate('home_1nhln_ddf1d8');
  }
}

String _widgetSeasonModeLabel(String key) {
  switch (key) {
    case 'none':
      return L10nService().translate('home_tthiungdp_d11975');
    case 'valentine':
      return 'Valentine';
    case 'anniversary':
      return L10nService().translate('home_knimyu_5b8036');
    case 'birthday':
      return L10nService().translate('home_sinhnht_71c600');
    case 'auto':
    default:
      return L10nService().translate('home_tng_0d5a90');
  }
}

class _SettingsBackgroundLayer extends StatelessWidget {
  const _SettingsBackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kSettingsBgTop, _kSettingsBgMid, _kSettingsBgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -76,
            left: -42,
            child: IgnorePointer(
              child: Container(
                width: 210,
                height: 210,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x52FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -88,
            bottom: 92,
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x14FF78A8), Color(0x00FF78A8)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTab extends StatefulWidget {
  final bool embedded;
  final bool autoOpenCountdownMode;
  final bool showGuideOnOpen;
  final Future<void> Function()? onReplayFirstSetupGuide;

  const SettingsTab({
    super.key,
    this.embedded = false,
    this.autoOpenCountdownMode = false,
    this.showGuideOnOpen = false,
    this.onReplayFirstSetupGuide,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with WidgetsBindingObserver {
  static const int _emailVerifyResendCooldownSeconds = 5 * 60;
  static const int _emailVerifyPendingWindowSeconds = 30 * 60;
  static const String _emailVerifyPendingEmailKey =
      'email_verify_pending_email';
  static const String _emailVerifyPendingSentTimeKey =
      'email_verify_pending_sent_time';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final HouseSettingsService _houseSettingsService = HouseSettingsService();
  final AuthService _authService = AuthService();
  final HouseService _houseService = HouseService();
  final MilitaryLockService _militaryLockService = MilitaryLockService();
  bool _didAutoOpenCountdownMode = false;
  final SecurityFlowGuard _securityFlowGuard = SecurityFlowGuard.instance;
  final SettingsSecurityController _settingsSecurityController =
      SettingsSecurityController();
  final StorageService _storageService = StorageService();
  final ScheduleNotifService _scheduleNotifService = ScheduleNotifService();
  final SettingsIdentityController _settingsIdentityController =
      const SettingsIdentityController();
  final SettingsNotificationsController _settingsNotificationsController =
      const SettingsNotificationsController();
  final SettingsWidgetController _settingsWidgetController =
      const SettingsWidgetController();
  final SettingsRelationshipWatcher _relationshipWatcher =
      SettingsRelationshipWatcher();

  String? _houseId;
  bool _houseIdChanged = false;
  String _houseName = L10nService().translate('home_nginhtnhyu_dbebce');
  bool _homeShowHouseName = false;
  bool _homeShowTimer = false;
  String _loveDate = '';
  String _nameU1 = L10nService().translate('home_bnnam_123ef2');
  String _nameU2 = L10nService().translate('home_bnn_babaec');
  String _avatarUrl1 = '';
  String _avatarUrl2 = '';
  String _dobU1 = '';
  String _dobU2 = '';
  String _loveUnit = L10nService().translate('home_ngyyu_722b21');
  String _relationshipMode = 'single';
  bool _isLanguageListExpanded = false;
  bool _isCoupleConnected = false;
  bool _isLoading = false;
  bool _isBootstrappingSettings = true;
  bool _isCheckingBackupStatus = false;
  bool _isManualBackupSyncing = false;
  bool _isRestoringSettingsBackup = false;
  bool _hasSettingsCloudBackup = false;
  DateTime? _settingsCloudBackupAt;
  DateTime? _settingsLocalBackupAt;
  String _settingsBackupStatusError = '';
  bool _isSavingAdvanced = false;
  bool _isSecurityLocked = false;
  bool _isCheckingSecurityLock = true;
  bool _isDevicePending = false;
  String _devicePendingMessage = '';
  int _devicePendingUnlockAtMs = 0;
  bool _isVipActive = false;
  bool _isRestoringVip = false;
  bool _googleLinked = false;
  bool _passwordLinked = false;
  bool _isMainEmailVerified = false;
  bool _hasRecoveryAnswer = false;
  bool _showHousePin = false;
  bool _showPasswordEditor = false;
  bool _isLinkingGoogle = false;
  bool _musicAutoplay = true;
  bool _notifAnniversary = true;
  bool _notifPost = true;
  bool _notifChat = true;
  bool _notifFriend = true;
  bool _notifHeart = true;
  bool _smartDiaryReminder = true;
  bool _smartCapsuleReminder = true;
  bool _smartLoveNoteReminder = true;
  bool _smartSleepReminder = true;
  bool _touchSound = true;
  bool _confettiFx = true;
  bool _showWeather = true;
  bool _showStatus = true;
  bool _isGrantingPermissions = false;
  bool _isUploadingThemeBackground = false;
  double? _themeUploadProgress;
  bool _didPromptPendingThemeBackgroundRetry = false;
  bool _isUnlockingStyle = false;
  int _countdownAdUnlockExpiryMs = 0;
  final Set<String> _deletingCustomEventIds = <String>{};
  bool _isBreakupBusy = false;
  bool _isRefreshingEmailVerification = false;
  bool _hasPendingEmailVerification = false;
  int _emailVerifyWaitSeconds = 0;
  Timer? _emailVerifyTimer;
  bool _didShowGuideOnOpen = false;
  final GlobalKey _accountGuideKey = GlobalKey();
  final GlobalKey _securityGuideKey = GlobalKey();
  final GlobalKey _themeGuideKey = GlobalKey();
  final GlobalKey _widgetGuideKey = GlobalKey();
  final GlobalKey _countdownGuideKey = GlobalKey();
  final GlobalKey _dataGuideKey = GlobalKey();
  final GlobalKey _supportGuideKey = GlobalKey();
  String _vipPlanLabel = L10nService().translate('home_giminph_5edaf7');
  String _vipExpiryLabel = L10nService().translate('home_chakchhot_27fec1');
  bool _isLifetimeVip = false;
  String _securityEmail = '';
  String _secondaryEmail = '';
  String _securityQuestion = '';
  String _activeRoleKey = '';
  String _selectedSecurityQuestion =
      L10nService().translate('home_ngysinhcab_82062b');
  String _housePin = '';
  String _bgMusicUrl = '';
  String _bgMusicTitle = '';
  String _bgMusicType = 'audio';
  bool _isSavingTheme = false;
  String _vipPlanCode = '';

  Set<String> _unlockedCountdownStyles = const <String>{};
  BreakupRequestData? _breakupRequest;
  int _pendingAccountDeletionAtMs = 0;
  String _pendingAccountDeletionUid = '';
  String? _draftThemeKey;
  String? _draftEffectKey;
  double? _draftAvatarSizePx;
  double? _draftCountdownSizePx;
  String? _draftAvatarFrameKey;
  String? _draftCountdownStyleKey;
  String? _draftFontKey;
  String? _draftHomeBlockToneKey;
  String? _draftGraphicsQualityKey;
  String? _draftWidgetThemeKey;
  String _widgetPanelTabKey = WidgetService.defaultWidgetStyleKey;
  String _widgetStyleKey = WidgetService.defaultWidgetStyleKey;
  bool _showDiaryOnWidget = true;
  bool _widgetHeartAnimated = true;
  String _widgetHeartStyleKey = _defaultWidgetHeartStyleKey;
  String _widgetHeartColorKey = 'rose';
  String _widgetPreviewSizeKey = 'medium';
  String _widgetDiaryLayoutKey = 'single';
  String _widgetSeasonModeKey = 'auto';
  String? _draftCustomBackgroundUrl;
  bool? _draftTransparentMode;
  bool _draftLiteMode = false;
  Timer? _widgetDiaryPreviewTimer;
  final ValueNotifier<int> _widgetPreviewTickNotifier = ValueNotifier<int>(0);

  // Custom Widget Event
  bool _useCustomWidgetEvent = false;
  final _customWidgetEventTitleCtrl = TextEditingController();
  final _customWidgetEventDateCtrl = TextEditingController();
  String _customWidgetEventColorHex = '#EC4899';
  double? _localCountdownSize;
  final List<String> _securityQuestions = [
    L10nService().translate('home_ngysinhcab_82062b'),
    L10nService().translate('home_convtutinb_658f22'),
    L10nService().translate('home_tngiovinch_4e1a34'),
    L10nService().translate('home_nilnutinha_433e60'),
    L10nService().translate('home_mnnyuthchn_25e124'),
  ];

  // App Lock variables
  bool _isAppLockEnabled = false;
  bool _useBiometrics = false;
  int _lockTimeout = 0; // minutes, 0 means immediately
  bool _isMilitaryMode = false;
  bool _notificationsEnabled = true;
  String _goodMorningTime = '05:55';
  String _goodNightTime = '22:15';
  String _storedLockSecret = '';
  String? _storedLockSalt;
  int? _storedLockLength;
  int? _lockConfiguredAtMs;
  final Map<String, bool> _lockScopes = {
    'app': true,
    'security': false,
    'diary': false,
    'chat': false,
    'private': false,
  };
  bool _hasActiveStandalonePanel = false;

  // Form controllers
  final _houseNameCtrl = TextEditingController();
  final _nameU1Ctrl = TextEditingController();
  final _nameU2Ctrl = TextEditingController();
  final _loveUnitCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _secondaryEmailCtrl = TextEditingController();
  final _customLockCtrl = TextEditingController();
  final _housePinCtrl = TextEditingController();
  final _recoveryQuestionCtrl = TextEditingController();
  final _recoveryAnswerCtrl = TextEditingController();
  final _autoReplyCtrl = TextEditingController();
  final _anniversaryNameCtrl = TextEditingController();
  final _anniversaryDateCtrl = TextEditingController();
  final _musicLinkCtrl = TextEditingController();
  DateTime? _draftAnniversaryDate;
  String? _anniversaryDateErrorText;
  bool _appLockSettingsLoaded = false;
  DateTime? _securityWarningDismissedUntil;
  bool _securityWarningStateLoaded = false;
  bool _securityWarningDisabled = false;
  List<DateTime> _securityWarningShownHistory = const [];

  final ValueNotifier<int> _panelRebuildNotifier = ValueNotifier<int>(0);

  Timer? _autoSaveThemeTimer;
  Timer? _uiPrefsDebounceTimer;

  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    if (_hasActiveStandalonePanel) {
      fn();
      _panelRebuildNotifier.value++;
    } else {
      super.setState(fn);
    }
  }

  BannerAd? _bottomBannerAd;

  void _loadBottomBanner() async {
    if (kIsWeb) return;
    final adMob = AdMobService();
    await adMob.initialize();
    if (!mounted) return;

    if (await adMob.isProUser()) {
      _bottomBannerAd?.dispose();
      _bottomBannerAd = null;
      if (!mounted) return;
      setState(() {});
      return;
    }

    _bottomBannerAd?.dispose();
    _bottomBannerAd = null;
    if (!mounted) return;
    _bottomBannerAd = await adMob.createBannerAd(
      onAdLoaded: (_) {
        if (!mounted) return;
        setState(() {});
      },
    );
  }

  // ignore: unused_element
  Widget _buildBottomAdBanner(BannerAd bannerAd) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        AdMobService().showInterstitialAd();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: SLColors.bgElevated.withValues(alpha: 0.72),
              borderRadius: SLRadius.lgAll,
              border: Border.all(
                color: SLColors.bgElevated.withValues(alpha: 0.45),
              ),
              boxShadow: SLShadow.subtle,
            ),
            child: ClipRRect(
              borderRadius: SLRadius.mdAll,
              child: SizedBox(
                width: bannerAd.size.width.toDouble(),
                height: bannerAd.size.height.toDouble(),
                child: AdWidget(ad: bannerAd),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startEmailVerifyTimer();
    // ⚡ Khởi tạo activeRoleKey ngay từ local để tránh nhảy lộn khi fetch Firebase
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final localRole =
          prefs.getString('il_role') == 'user2' ? 'user2' : 'user1';
      setState(() => _activeRoleKey = localRole);
    });
    _scheduleSettingsBootstrap();
  }

  void _scheduleSettingsBootstrap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_checkSecurityScopeLockReal());
      unawaited(_restorePendingEmailVerificationState());
      unawaited(_fetchSettingsData().then((_) async {
        await _maybeShowSettingsGuideOnOpen();
        await _maybeAutoOpenCountdownMode();
      }));
      unawaited(_loadAppLockSettings());
      unawaited(_loadLocalSettings());
      unawaited(_initVipServices());
      unawaited(_loadSecurityWarningDismissState());
      unawaited(UiPrefs.ensureLoaded());
      Future<void>.delayed(const Duration(seconds: 15), () {
        if (!mounted) return;
        _loadBottomBanner();
      });
    });
  }

  Future<void> _maybeAutoOpenCountdownMode() async {
    if (!widget.autoOpenCountdownMode ||
        _didAutoOpenCountdownMode ||
        !mounted) {
      return;
    }
    _didAutoOpenCountdownMode = true;
    await _openCountdownMode();
  }

  Future<void> _maybeShowSettingsGuideOnOpen() async {
    if (!widget.showGuideOnOpen || _didShowGuideOnOpen || !mounted) {
      return;
    }
    final houseId = (_houseId ?? '').trim();
    if (houseId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final guidePrefsKey = 'il_settings_setup_guide_seen_$houseId';
    if (prefs.getString(guidePrefsKey) == '1') {
      return;
    }
    _didShowGuideOnOpen = true;
    await prefs.setString(guidePrefsKey, '1');
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    await FirstSetupSpotlightGuide.show(
      context,
      steps: [
        FirstSetupSpotlightStep(
          targetKey: _accountGuideKey,
          title: L10nService().translate('home_tikhonvthn_2521e3'),
          description: L10nService().translate('home_qunltnnhtn_e09121'),
          icon: Icons.manage_accounts_rounded,
          color: const Color(0xFFF1B42A),
        ),
        FirstSetupSpotlightStep(
          targetKey: _securityGuideKey,
          title: L10nService().translate('home_bomtvxcmin_0ad4a8'),
          description: L10nService().translate('home_kimtratrng_f23b01'),
          icon: Icons.shield_rounded,
          color: const Color(0xFFD63F67),
        ),
        FirstSetupSpotlightStep(
          targetKey: _themeGuideKey,
          title: L10nService().translate('home_giaodintra_f6bf4a'),
          description: L10nService().translate('home_tychnhchnh_99bdd7'),
          icon: Icons.palette_rounded,
          color: const Color(0xFF2A73D9),
        ),
        FirstSetupSpotlightStep(
          targetKey: _widgetGuideKey,
          title: L10nService().translate('home_widgetmnhn_e51604'),
          description: L10nService().translate('home_thitlpwidg_da3a5c'),
          icon: Icons.widgets_rounded,
          color: const Color(0xFF0D7D81),
        ),
        FirstSetupSpotlightStep(
          targetKey: _countdownGuideKey,
          title: L10nService().translate('home_khnggianmn_5b94a7'),
          description: L10nService().translate('home_chnhgiaodi_5dfb72'),
          icon: Icons.timelapse_rounded,
          color: const Color(0xFFB85A2B),
        ),
        FirstSetupSpotlightStep(
          targetKey: _dataGuideKey,
          title: L10nService().translate('home_dliuhthng_59a15f'),
          description: L10nService().translate('home_qunlthngbo_ae24f2'),
          icon: Icons.hub_rounded,
          color: const Color(0xFF1565C0),
        ),
        FirstSetupSpotlightStep(
          targetKey: _supportGuideKey,
          title: L10nService().translate('home_htrvphpl_5ab721'),
          description: L10nService().translate('home_mtrungtmht_085e44'),
          icon: Icons.support_agent_rounded,
          color: const Color(0xFF6A46C6),
        ),
      ],
    );
  }

  void _startWidgetPreviewTicker() {
    if (_widgetDiaryPreviewTimer != null) {
      return;
    }
    _widgetPreviewTickNotifier.value = 0;
    _widgetDiaryPreviewTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _widgetPreviewTickNotifier.value = _widgetPreviewTickNotifier.value + 1;
    });
  }

  void _stopWidgetPreviewTicker() {
    _widgetDiaryPreviewTimer?.cancel();
    _widgetDiaryPreviewTimer = null;
    if (_widgetPreviewTickNotifier.value != 0) {
      _widgetPreviewTickNotifier.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshMainEmailVerificationStatus(
        showSuccessToast: false,
        showPendingToast: false,
      ));
    }
  }

  @override
  void dispose() {
    _bottomBannerAd?.dispose();
    // ✅ FIX: Cancel auto-save timer to ensure settings persist
    _autoSaveThemeTimer?.cancel();
    _uiPrefsDebounceTimer?.cancel();
    _stopWidgetPreviewTicker();
    _emailVerifyTimer?.cancel();

    // ⚡ Save any pending theme settings before dispose
    _saveThemeSettings(silent: true).ignore();

    _localCountdownSize = null;

    _panelRebuildNotifier.dispose();
    _widgetPreviewTickNotifier.dispose();
    _relationshipWatcher.dispose();
    _houseNameCtrl.dispose();
    _nameU1Ctrl.dispose();
    _nameU2Ctrl.dispose();
    _loveUnitCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _secondaryEmailCtrl.dispose();
    _customLockCtrl.dispose();
    _housePinCtrl.dispose();
    _recoveryQuestionCtrl.dispose();
    _recoveryAnswerCtrl.dispose();
    _autoReplyCtrl.dispose();
    _anniversaryNameCtrl.dispose();
    _anniversaryDateCtrl.dispose();
    _musicLinkCtrl.dispose();
    _customWidgetEventTitleCtrl.dispose();
    _customWidgetEventDateCtrl.dispose();
    SettingsSyncService().backupSettingsToCloud();
    super.dispose();
  }

  // ignore: unused_element

  // ignore: unused_element

  // ignore: unused_element

  // ignore: unused_element

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSecurityLock) {
      return const Stack(
        fit: StackFit.expand,
        children: [
          _SettingsBackgroundLayer(),
          Center(
            child: CircularProgressIndicator(color: Color(0xFFFF78A8)),
          ),
        ],
      );
    }

    return _buildSettingsScaffold();
  }

  Future<void> _addCustomAnniversary() async {
    final eventName = _anniversaryNameCtrl.text.trim();
    if (_houseId == null || _houseId!.trim().isEmpty) {
      _showToast(L10nService().translate('home_hyvonhtrck_f42333'),
          success: false);
      return;
    }
    if (eventName.isEmpty) {
      _showToast(L10nService().translate('err_enter_event_name'),
          success: false);
      return;
    }
    final dateValidationError = DateInputUtils.validationError(
      _anniversaryDateCtrl.text,
      firstYear: 2020,
      lastYear: 2100,
    );
    if (dateValidationError != null) {
      setState(() => _anniversaryDateErrorText = dateValidationError);
      _showToast(dateValidationError, success: false);
      return;
    }
    final typedAnniversaryDate = _draftAnniversaryDate ??
        DateInputUtils.parse(
          _anniversaryDateCtrl.text,
          firstYear: 2020,
          lastYear: 2100,
        );
    if (typedAnniversaryDate == null) {
      _showToast(L10nService().translate('err_select_event_date'),
          success: false);
      return;
    }

    try {
      await _scheduleNotifService.addCustomEvent(
        houseId: _houseId!,
        name: eventName,
        date: typedAnniversaryDate,
        repeat: true,
      );
      if (!mounted) return;
      setState(() {
        _anniversaryNameCtrl.clear();
        _anniversaryDateCtrl.clear();
        _draftAnniversaryDate = null;
        _anniversaryDateErrorText = null;
      });
      _showToast(L10nService().translate('event_added_success'), success: true);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: L10nService().translate('err_add_event'),
        ).message,
        success: false,
      );
    }
  }

  String? _extractCustomEventId(UpcomingEvent event) {
    if (event.source != 'custom' || !event.eventKey.startsWith('cust:')) {
      return null;
    }
    return event.eventKey.substring(5);
  }

  Future<void> _deleteCustomAnniversary(UpcomingEvent event) async {
    final eventId = _extractCustomEventId(event);
    if (eventId == null || _houseId == null || _houseId!.trim().isEmpty) {
      _showToast(L10nService().translate('err_delete_event'), success: false);
      return;
    }

    final confirmed = await SLNotice.showConfirmDialog(
      context,
      title: L10nService().translate('theme_event_delete_title'),
      message: L10nService().format(
        'theme_event_delete_message',
        {'name': event.title},
      ),
      confirmText: L10nService().translate('home_xa_4ed187'),
      cancelText: L10nService().translate('home_hy_1e4050'),
      isDanger: true,
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingCustomEventIds.add(eventId);
    });

    try {
      await _scheduleNotifService.deleteCustomEvent(_houseId!, eventId);
      if (!mounted) return;
      _showToast(L10nService().translate('event_deleted_success'),
          success: true);
    } catch (e) {
      if (!mounted) return;
      _showToast(
        AppErrorMapper.resolve(
          e,
          fallbackMessage: L10nService().translate('err_delete_event'),
        ).message,
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingCustomEventIds.remove(eventId);
        });
      }
    }
  }

  String _formatThemeDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  TextStyle _themeFontStyle(
    String fontKey, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    Color color = const Color(0xFF444444),
    double? height,
  }) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
    return SLTheme.textStyleForKey(fontKey, textStyle: baseStyle);
  }

  BoxDecoration _previewHomeCardDecoration(String toneKey, bool isDark) {
    final color = switch (toneKey) {
      'mist' => const Color(0xFFF7FBFF).withValues(alpha: isDark ? 0.64 : 0.86),
      'rose' => const Color(0xFFFFF2F7).withValues(alpha: isDark ? 0.62 : 0.9),
      'glass' => Colors.white.withValues(alpha: isDark ? 0.18 : 0.74),
      _ => Colors.white.withValues(alpha: isDark ? 0.22 : 0.82),
    };
    final border = switch (toneKey) {
      'mist' => const Color(0xFFDBF0FF),
      'rose' => const Color(0xFFF8D7E4),
      'glass' => Colors.white.withValues(alpha: 0.42),
      _ => Colors.white.withValues(alpha: 0.54),
    };

    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ImgBB references removed to enhance security and transition to Supabase Storage.

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _buildDevicePendingScreen(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF8BBD0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD81B60).withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.devices_rounded,
              size: 56,
              color: Color(0xFFD81B60),
            ),
            const SizedBox(height: 14),
            Text(
              L10nService().translate('home_thitbangch_1e00c8'),
              style: SLTheme.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFD81B60),
              ),
            ),
            const SizedBox(height: 8),
            // Prefer the computed pending message so the unlock date is visible.
            Text(
              _devicePendingMessage.isNotEmpty
                  ? _devicePendingMessage
                  : 'Thiết bị mới cần được duyệt bởi thiết bị quen (đã dùng lâu) trước khi chỉnh sửa các mục trong Cài đặt.\n\nBạn vẫn có thể đổi avatar ở màn hình chính. Các khu vực khác trong ứng dụng vẫn hoạt động bình thường. Nếu không có thiết bị cũ, thời điểm tự được tin cậy sẽ hiển thị bên dưới khi hệ thống trả về.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF8BBD0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFFD81B60),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      L10nService().translate('home_hngdncduyt_35af24'),
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _buildStepRow(
                    '1',
                    L10nService().translate('home_msoullocke_b59902'),
                  ),
                  const SizedBox(height: 6),
                  _buildStepRow(
                    '2',
                    L10nService().translate('home_vocitbomtq_b29ae5'),
                  ),
                  const SizedBox(height: 6),
                  _buildStepRow(
                    '3',
                    'Tìm thiết bị này trong danh sách và nhấn ${L10nService().translate('home_duyt_a4db4d')}.',
                  ),
                  const SizedBox(height: 6),
                  _buildStepRow(
                    '4',
                    _formatManagedPendingUnlockDate(_devicePendingUnlockAtMs)
                            .isNotEmpty
                        ? 'Nếu không có thiết bị cũ, hãy đợi đến ${_formatManagedPendingUnlockDate(_devicePendingUnlockAtMs)} để thiết bị tự được tin cậy và có thể đăng nhập/chỉnh sửa bình thường.'
                        : L10nService().translate('home_nukhngcthi_6bcda1'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildGradientBtn(
              label: L10nService().translate('home_quaylicitc_3d387a'),
              gradient: const [Color(0xFFFF6F91), Color(0xFFD81B60)],
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 10),
            _buildGradientBtn(
              label: L10nService().translate('home_yucuhtr_60da9e'),
              gradient: const [Color(0xFF7B61FF), Color(0xFF5C4DCC)],
              onTap: () async {
                await _openSupportContact();
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await _authService.signOut();
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
              label: Text(
                L10nService().translate('home_ngxut_0b3c82'),
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptEmailDialogWidget extends StatefulWidget {
  final String title;
  final String hint;
  final String initialValue;

  const _PromptEmailDialogWidget({
    required this.title,
    required this.hint,
    this.initialValue = '',
  });

  @override
  State<_PromptEmailDialogWidget> createState() =>
      _PromptEmailDialogWidgetState();
}

class _PromptEmailDialogWidgetState extends State<_PromptEmailDialogWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        widget.title,
        style: SLTheme.quicksand(fontWeight: FontWeight.w900),
      ),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L10nService().translate('cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD81B60),
            foregroundColor: Colors.white,
          ),
          child: Text(L10nService().translate('continue_action')),
        ),
      ],
    );
  }
}
