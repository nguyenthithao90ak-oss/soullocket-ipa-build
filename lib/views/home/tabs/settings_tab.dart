// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
library settings_tab;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/document_viewer_screen.dart';
import '../screens/global_search_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/notification_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:permission_handler/permission_handler.dart' as app_permission;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import '../../../core/sl_theme.dart';
import '../../../services/house_settings_service.dart';
import '../../../services/location_service.dart';
import '../../../services/music_service.dart';
import '../../../services/purchase_service.dart';
import '../../../services/schedule_notif_service.dart';
import '../../../services/settings_sync_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/countdown_space_service.dart';
import '../../../models/data_export_result.dart';
import '../../../utils/services/data_export_service.dart';
import '../../../services/friends_service.dart';
import '../../app_entry.dart';
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
import '../../utilities/tarot_screen.dart';
import '../../utilities/voice_screen.dart';
import '../../utilities/wheel_screen.dart';
import '../../utilities/wishlist_screen.dart';
import '../../utilities/diary_export_screen.dart';
import 'package:local_auth/local_auth.dart';
import '../../utilities/device_manager_screen.dart';
// import '../../auth/qr_authorize_scanner_screen.dart';
import '../../utilities/user_support_chat_screen.dart';
import 'settings/settings_gift_links_manager_screen.dart';
import '../../../services/l10n_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/device_manager_service.dart';
import '../../../services/security_flow_guard.dart';
import '../../../services/admob_service.dart';
import '../../../services/breakup_service.dart';
import '../../../services/house_service.dart';
import '../../../services/military_lock_service.dart';
import '../../../services/push_notification_helper.dart';
import '../../../services/qr_payload_codec.dart';
import '../../../services/sound_service.dart';
import 'settings/controllers/settings_security_controller.dart';
import 'settings/security/security_otp_dialogs.dart';
import '../../../widgets/legacy_web_ui.dart';
import '../../../widgets/pin_pad_setup_modal.dart';
import '../../../services/widget_service.dart';
import '../../../models/house_settings.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/soul_locket_brand.dart';
import '../../../utils/flexible_date_input.dart';
import '../../../utils/sl_notice.dart';
import '../../../utils/services/pending_upload_service.dart';
import '../../../utils/services/app_lifecycle_presence_guard.dart';
import '../../../widgets/soul_locket_brand_mark.dart';
import '../../visitors/visitor_profile_screen.dart';
import 'settings/account/identity_panel.dart';
import 'settings/controllers/settings_identity_controller.dart';
import 'settings/relationship/relationship_actions.dart';

part 'settings/settings_shared_widgets.dart';
part 'settings/settings_state_helpers.dart';
part 'settings/settings_persistence.dart';
part 'settings/settings_account_section.dart';
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
part 'settings/settings_countdown_mode_screen.dart';
part 'settings/countdown_mode_state_handlers.dart';
part 'settings/countdown_mode_view_section.dart';
part 'settings/countdown_mode_models_part.dart';
part 'settings/countdown_mode_snapshot_codec_part.dart';
part 'settings/countdown_mode_editor_part.dart';
part 'settings/countdown_mode_editor_helpers_part.dart';
part 'settings/countdown_mode_dialogs_part.dart';
part 'settings/countdown_mode_shell_part.dart';
part 'settings/countdown_mode_widgets_part.dart';
part 'settings/countdown_mode_theme_part.dart';
part 'settings/countdown_mode_layout_section.dart';
part 'settings/settings_notifications_section.dart';
part 'settings/settings_relationship_section.dart';
part 'settings/settings_support_legal_section.dart';
part 'settings/settings_data_health_section.dart';
part 'settings/settings_shell.dart';

const Color _kSettingsBgBase = Color(0xFFDCE4EE);
const Color _kSettingsBgTop = Color(0xFFEAF0F6);
const Color _kSettingsBgMid = Color(0xFFDCE4EE);
const Color _kSettingsBgBottom = Color(0xFFCDD8E6);
const Color _kSettingsHeaderBg = Color(0xFFE7EDF4);
const Color _kSettingsHeaderSurface = Color(0xFFF9FBFD);
const Color _kSettingsHeaderBorder = Color(0xFFBEC9D7);
const Color _kSettingsActionTileBg = Color(0xFFEAF0F5);
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
];
const String _defaultWidgetHeartStyleKey = '❤️';

const List<String> _widgetPreviewSizeKeys = <String>[
  'small',
  'medium',
  'large',
];
const List<String> _widgetStyleKeys = <String>[
  'classic',
  'countdown',
];
const String _widgetPanelTabIconKey = 'icon';
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

String _widgetHeartStyleLabel(String emoji) {
  switch (emoji) {
    case '🤍':
      return '🤍 Tim trắng';
    case '🤎':
      return '🤎 Tim nâu';
    case '♥️':
      return '♥️ Tim cổ điển';
    case '❣️':
      return '❣️ Tim nhấn mạnh';
    case '❤️':
      return '❤️ Tim đỏ';
    case '💞':
      return '💞 Tim xoay đôi';
    case '🖤':
      return '🖤 Tim đen';
    case '💟':
      return '💟 Tim viền';
    case '❤️‍🔥':
      return '❤️‍🔥 Tim rực cháy';
    case '🩷':
      return '🩷 Tim hồng';
    case '🩶':
      return '🩶 Tim xám';
    case '🩵':
      return '🩵 Tim xanh';
    case '💘':
      return '💘 Tim mũi tên';
    case '❤️‍🩹':
      return '❤️‍🩹 Tim chữa lành';
    case '💓':
    default:
      return '💓 Tim đập';
  }
}

String _widgetPreviewSizeLabel(String key) {
  switch (key) {
    case 'small':
      return 'Nhỏ';
    case 'large':
      return 'Lớn';
    case 'medium':
    default:
      return 'Vừa';
  }
}

String _widgetStyleLabel(String key) {
  switch (key) {
    case 'countdown':
      return 'Dem ngay';
    case 'classic':
    default:
      return 'Mac dinh';
  }
}

String _widgetDiaryLayoutLabel(String key) {
  switch (key) {
    case 'duo':
      return '2 ảnh đôi';
    case 'grid':
      return 'Collage 4 ảnh';
    case 'single':
    default:
      return '1 ảnh lớn';
  }
}

String _widgetSeasonModeLabel(String key) {
  switch (key) {
    case 'none':
      return 'Tắt hiệu ứng dịp';
    case 'valentine':
      return 'Valentine';
    case 'anniversary':
      return 'Kỷ niệm yêu';
    case 'birthday':
      return 'Sinh nhật';
    case 'auto':
    default:
      return 'Tự động';
  }
}

class _SettingsBackgroundLayer extends StatelessWidget {
  const _SettingsBackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
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
    );
  }
}

class SettingsTab extends StatefulWidget {
  final bool embedded;
  final bool autoOpenCountdownMode;

  const SettingsTab({
    super.key,
    this.embedded = false,
    this.autoOpenCountdownMode = false,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with WidgetsBindingObserver {
  static const int _emailVerifyResendCooldownSeconds = 5 * 60;
  static const int _emailVerifyPendingWindowSeconds = 30 * 60;
  static const Duration _settingsSyncBannerDelay = Duration(milliseconds: 420);
  static const Duration _settingsSyncBannerMinVisible =
      Duration(milliseconds: 900);
  static const String countdownModePinnedLaunchPrefsKey =
      'il_countdown_mode_pinned_launch_v1';
  static const String _emailVerifyPendingEmailKey =
      'email_verify_pending_email';
  static const String _emailVerifyPendingSentTimeKey =
      'email_verify_pending_sent_time';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final HouseSettingsService _houseSettingsService = HouseSettingsService();
  final AuthService _authService = AuthService();
  final BreakupService _breakupService = BreakupService();
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
  final SettingsRelationshipWatcher _relationshipWatcher =
      SettingsRelationshipWatcher();

  String? _houseId;
  String _houseName = 'Ngôi Nhà Tình Yêu';
  bool _homeShowHouseName = false;
  bool _homeShowTimer = false;
  String _loveDate = '';
  String _nameU1 = 'Bạn Nam';
  String _nameU2 = 'Bạn Nữ';
  String _avatarUrl1 = '';
  String _avatarUrl2 = '';
  String _dobU1 = '';
  String _dobU2 = '';
  String _loveUnit = 'ngày yêu';
  String _relationshipMode = 'single';
  bool _isCoupleConnected = false;
  bool _isLoading = false;
  bool _isBootstrappingSettings = true;
  bool _showSettingsSyncBanner = false;
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
  final bool _showCustomLock = false;
  bool _showPasswordEditor = false;
  bool _isLinkingGoogle = false;
  bool _musicAutoplay = true;
  bool _notifAnniversary = true;
  bool _notifPost = true;
  bool _notifChat = true;
  bool _notifFriend = true;
  bool _notifHeart = true;
  bool _touchSound = true;
  bool _confettiFx = true;
  bool _showWeather = true;
  bool _showStatus = true;
  bool _isGrantingPermissions = false;
  bool _isSavingAdvanced = false;
  bool _isSavingTheme = false;
  bool _isUploadingThemeBackground = false;
  bool _didPromptPendingThemeBackgroundRetry = false;
  bool _isUnlockingStyle = false;
  int _countdownAdUnlockExpiryMs = 0;
  Set<String> _unlockedCountdownStyles = {};
  final Set<String> _deletingCustomEventIds = <String>{};
  bool _isBreakupBusy = false;
  bool _isRefreshingEmailVerification = false;
  bool _hasPendingEmailVerification = false;
  int _emailVerifyWaitSeconds = 0;
  Timer? _emailVerifyTimer;
  final GlobalKey _vipPanelKey = GlobalKey();
  String _vipPlanLabel = 'Gói miễn phí';
  String _vipExpiryLabel = 'Chưa kích hoạt';
  String _vipPlanCode = '';
  bool _isLifetimeVip = false;
  String _securityEmail = '';
  String _secondaryEmail = '';
  String _securityQuestion = '';
  String _activeRoleKey = 'user1';
  String _selectedSecurityQuestion = 'Ngày sinh của bạn?';
  String _housePin = '';
  String _bgMusicUrl = '';
  String _bgMusicTitle = '';
  String _bgMusicType = 'audio';
  BreakupRequestData? _breakupRequest;
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
  Timer? _settingsSyncBannerDelayTimer;
  Timer? _settingsSyncBannerHideTimer;
  final ValueNotifier<int> _widgetPreviewTickNotifier = ValueNotifier<int>(0);
  final List<String> _securityQuestions = const [
    'Ngày sinh của bạn?',
    'Con vật đầu tiên bạn nuôi?',
    'Tên giáo viên chủ nhiệm lớp 1?',
    'Nơi lần đầu tiên hai bạn gặp nhau?',
    'Món ăn yêu thích nhất của bạn?',
  ];

  // App Lock variables
  bool _isAppLockEnabled = false;
  bool _useBiometrics = false;
  int _lockTimeout = 0; // minutes, 0 means immediately
  bool _isMilitaryMode = false;
  bool _notificationsEnabled = true;
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
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Panel controllers - which panel is expanded
  String? _openPanel;
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

  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
    if (_hasActiveStandalonePanel) {
      _panelRebuildNotifier.value++;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startEmailVerifyTimer();
    _armSettingsSyncBanner();
    _scheduleSettingsBootstrap();
  }

  void _scheduleSettingsBootstrap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_checkSecurityScopeLockReal());
      unawaited(_restorePendingEmailVerificationState());
      unawaited(
          _fetchSettingsData().then((_) => _maybeAutoOpenCountdownMode()));
      unawaited(_loadAppLockSettings());
      unawaited(_loadLocalSettings());
      unawaited(_initVipServices());
      unawaited(_loadSecurityWarningDismissState());
      unawaited(UiPrefs.ensureLoaded());
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

  // ignore: unused_element

  // ignore: unused_element

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshMainEmailVerificationStatus(
        showSuccessToast: false,
        showPendingToast: false,
      ));
    }
  }

  // ignore: unused_element

  // ignore: unused_element

  // ignore: unused_element

  // ignore: unused_element

  // ignore: unused_element

  @override
  void dispose() {
    // ✅ FIX: Cancel auto-save timer to ensure settings persist
    _autoSaveThemeTimer?.cancel();
    _stopWidgetPreviewTicker();
    _emailVerifyTimer?.cancel();
    _settingsSyncBannerDelayTimer?.cancel();
    _settingsSyncBannerHideTimer?.cancel();

    // ⚡ Save any pending theme settings before dispose
    _saveThemeSettings(silent: true).ignore();

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
    SettingsSyncService().backupSettingsToCloud();
    super.dispose();
  }

  // ignore: unused_element

  // ignore: unused_element

  // ignore: unused_element

  // ignore: unused_element

  // ignore: unused_element

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSecurityLock) {
      return Stack(
        fit: StackFit.expand,
        children: const [
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
      _showToast('Hãy vào nhà trước khi thêm kỷ niệm.', success: false);
      return;
    }
    if (eventName.isEmpty) {
      _showToast(context.tr('err_enter_event_name'), success: false);
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
      _showToast(context.tr('err_select_event_date'), success: false);
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
      _showToast(context.tr('event_added_success'), success: true);
    } catch (e) {
      _showToast('${context.tr('err_add_event')}: $e', success: false);
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
      _showToast(context.tr('err_delete_event'), success: false);
      return;
    }

    final confirmed = await SLNotice.showConfirmDialog(
      context,
      title: context.tr('theme_event_delete_title'),
      message: L10nService().format(
        'theme_event_delete_message',
        {'name': event.title},
      ),
      confirmText: 'Xóa',
      cancelText: 'Hủy',
      isDanger: true,
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingCustomEventIds.add(eventId);
    });

    try {
      await _scheduleNotifService.deleteCustomEvent(_houseId!, eventId);
      if (!mounted) return;
      _showToast(context.tr('event_deleted_success'), success: true);
    } catch (e) {
      if (!mounted) return;
      _showToast('${context.tr('err_delete_event')}: $e', success: false);
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
      'mist' => const Color(0xFFF7FBFF).withOpacity(isDark ? 0.64 : 0.86),
      'rose' => const Color(0xFFFFF2F7).withOpacity(isDark ? 0.62 : 0.9),
      'glass' => Colors.white.withOpacity(isDark ? 0.18 : 0.74),
      _ => Colors.white.withOpacity(isDark ? 0.22 : 0.82),
    };
    final border = switch (toneKey) {
      'mist' => const Color(0xFFDBF0FF),
      'rose' => const Color(0xFFF8D7E4),
      'glass' => Colors.white.withOpacity(0.42),
      _ => Colors.white.withOpacity(0.54),
    };

    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.16 : 0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  String _themeTitleForKey(String themeKey) {
    switch (themeKey) {
      case 'theme-night':
        return context.tr('theme_night_vi');
      case 'theme-dark':
        return context.tr('theme_dark_vi');
      case 'theme-true-black':
        return 'OLED True Black (Tiết kiệm pin)';
      case 'theme-mystic-dark':
        return context.tr('theme_mystic_dark_vi');
      case 'theme-ocean':
        return context.tr('theme_ocean_vi');
      case 'theme-sunset':
        return context.tr('theme_sunset_vi');
      case 'theme-crazy-party':
        return context.tr('theme_crazy_party_vi');
      case 'theme-pink-glow':
        return context.tr('theme_pink_glow_vi');
      default:
        return context.tr('theme_default_pink_vi');
    }
  }

  // ignore: unused_element

  // ImgBB references removed to enhance security and transition to Supabase Storage.

  // ignore: unused_element

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _buildDevicePendingScreen(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF8BBD0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD81B60).withOpacity(0.12),
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
              'Thiết Bị Đang Chờ Duyệt',
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
                      'Hướng dẫn để được duyệt:',
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
                    'Mở SoulLocket trên thiết bị cũ (đã dùng lâu) của bạn.',
                  ),
                  const SizedBox(height: 6),
                  _buildStepRow(
                    '2',
                    'Vào Cài đặt → Bảo mật → Quản lý thiết bị.',
                  ),
                  const SizedBox(height: 6),
                  _buildStepRow(
                    '3',
                    'Tìm thiết bị này trong danh sách và nhấn "Duyệt".',
                  ),
                  const SizedBox(height: 6),
                  _buildStepRow(
                    '4',
                    _formatManagedPendingUnlockDate(_devicePendingUnlockAtMs)
                            .isNotEmpty
                        ? 'Nếu không có thiết bị cũ, hãy đợi đến ${_formatManagedPendingUnlockDate(_devicePendingUnlockAtMs)} để thiết bị tự được tin cậy và có thể đăng nhập/chỉnh sửa bình thường.'
                        : 'Nếu không có thiết bị cũ, ứng dụng sẽ hiển thị thời điểm tự được tin cậy ngay khi hệ thống trả về.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildGradientBtn(
              label: 'Quay lại Cài đặt chung',
              gradient: const [Color(0xFFFF6F91), Color(0xFFD81B60)],
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 10),
            _buildGradientBtn(
              label: '💬 Yêu cầu hỗ trợ',
              gradient: const [Color(0xFF7B61FF), Color(0xFF5C4DCC)],
              onTap: () async {
                await _openSupportContact();
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await _authService.signOut();
                if (!mounted) return;
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
                'Đăng xuất',
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
          child: Text(context.tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD81B60),
            foregroundColor: Colors.white,
          ),
          child: Text(context.tr('continue_action')),
        ),
      ],
    );
  }
}
