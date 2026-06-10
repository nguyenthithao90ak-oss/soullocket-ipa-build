import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/services/offline_cache_service.dart';

import '../../utils/services/admob_service.dart';
import '../../utils/services/critical_data_sync_service.dart';
import '../../utils/services/device_manager_service.dart';
import '../../utils/services/encryption_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/interaction_metrics_service.dart';
import '../../utils/services/love_insight_service.dart';
import '../../utils/services/military_lock_service.dart';
import '../../utils/services/location_service.dart';
import '../../utils/services/notification_service.dart';
import '../../utils/services/presence_service.dart';
import '../../utils/services/security_service.dart';
import '../../utils/services/session/app_background_session_tracker.dart';
import '../../utils/services/session/session_connectivity_coordinator.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/widget_service.dart';
import '../../utils/services/role_utils.dart';

class AppEntryAuthState {
  final bool isAuthenticated;
  final bool isCheckingAuth;
  final bool isCompromised;

  const AppEntryAuthState({
    required this.isAuthenticated,
    required this.isCheckingAuth,
    this.isCompromised = false,
  });
}

class AppEntryResumeResult {
  final bool shouldResetToHome;
  final AppEntryAuthState? authState;

  const AppEntryResumeResult({
    this.shouldResetToHome = false,
    this.authState,
  });
}

class AppEntryHouseSessionResult {
  final bool didScheduleInitialAppOpenAd;

  const AppEntryHouseSessionResult({
    this.didScheduleInitialAppOpenAd = false,
  });
}

class AppEntryController {
  AppEntryController({
    HouseService? houseService,
    MilitaryLockService? militaryLockService,
    PresenceService? presenceService,
    DeviceManagerService? deviceManagerService,
    AdMobService? adMobService,
    CriticalDataSyncService? criticalDataSyncService,
    LoveInsightService? loveInsightService,
    InteractionMetricsService? interactionMetricsService,
  })  : _houseService = houseService ?? HouseService(),
        _militaryLockService = militaryLockService ?? MilitaryLockService(),
        _presenceService = presenceService ?? PresenceService(),
        _deviceManagerService = deviceManagerService ?? DeviceManagerService(),
        _adMobService = adMobService ?? AdMobService(),
        _criticalDataSyncService =
            criticalDataSyncService ?? CriticalDataSyncService(),
        _loveInsightService = loveInsightService ?? LoveInsightService(),
        _interactionMetricsService =
            interactionMetricsService ?? InteractionMetricsService();

  static const String _startupPermissionPromptedPrefsKey =
      'il_startup_permission_prompted_v2';
  static const String _notificationPermissionPromptedPrefsKey =
      'il_notification_permission_prompted_v1';
  static const String _locationPermissionPromptedPrefsKey =
      'il_location_permission_prompted_v1';
  static const Duration _deviceRegistrationCooldown = Duration(seconds: 15);

  final HouseService _houseService;
  final MilitaryLockService _militaryLockService;
  final PresenceService _presenceService;
  final DeviceManagerService _deviceManagerService;
  final AdMobService _adMobService;
  final CriticalDataSyncService _criticalDataSyncService;
  final LoveInsightService _loveInsightService;
  final InteractionMetricsService _interactionMetricsService;
  final AppBackgroundSessionTracker _backgroundSessionTracker =
      const AppBackgroundSessionTracker();
  late final SessionConnectivityCoordinator _sessionConnectivityCoordinator =
      SessionConnectivityCoordinator(
    presenceService: _presenceService,
  );

  SharedPreferences? _prefs;
  DateTime? _lastPausedAt;
  String? _currentHouseId;
  String? _currentRole;
  bool _isAuthenticating = false;
  Future<void>? _deviceRegistrationInFlight;
  DateTime? _lastDeviceRegistrationStartedAt;

  String? get currentHouseId => _currentHouseId;
  String? get currentRole => _currentRole;
  bool get hasPendingResume => _lastPausedAt != null;

  Future<SharedPreferences> getPrefs() async {
    return _prefs ??= OfflineCacheService.getPrefsSync() ?? await SharedPreferences.getInstance();
  }

  void dispose() {
    _sessionConnectivityCoordinator.dispose();
  }

  void scheduleDeferredStartupTasks({
    required bool Function() isMounted,
  }) {
    Future.delayed(const Duration(milliseconds: 100), () async {
      if (!isMounted()) return;
      try {
        await NotificationService().initialize();
      } catch (e) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage:
              L10nService().translate('app_entry_khngthkhit_1be321'),
        );
        debugPrint('[AppEntry] Notification init failed: ${errorInfo.message}');
      }
    });
  }

  Future<AppEntryAuthState> bootstrap({
    required BuildContext context,
  }) async {
    try {
      debugPrint('[AppEntry] bootstrap start');
      final preResults = await Future.wait<dynamic>([
        _resolveCompromisedAuthState().timeout(const Duration(seconds: 3)),
        _applyStaleSessionPolicy(),
      ]).timeout(const Duration(seconds: 5));

      final compromisedState = preResults[0] as AppEntryAuthState?;
      if (compromisedState != null) {
        debugPrint('[AppEntry] bootstrap blocked by compromised state');
        return compromisedState;
      }
      if (!context.mounted) {
        return const AppEntryAuthState(
          isAuthenticated: true,
          isCheckingAuth: false,
        );
      }

      final lockState = await checkAppLock(context: context, isResuming: false)
          .timeout(const Duration(seconds: 8));
      debugPrint('[AppEntry] bootstrap finished');
      return lockState ??
          const AppEntryAuthState(
            isAuthenticated: true,
            isCheckingAuth: false,
          );
    } catch (e, _) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('app_entry_khngthkhin_190761'),
      );
      debugPrint(
          '[AppEntry] Bootstrap failed or timed out: ${errorInfo.message}');
      return const AppEntryAuthState(
        isAuthenticated: true,
        isCheckingAuth: false,
      );
    }
  }

  Future<AppEntryAuthState?> checkAppLock({
    required BuildContext context,
    bool isResuming = false,
  }) async {
    if (_isAuthenticating) return null;
    _isAuthenticating = true;

    try {
      debugPrint('[AppEntry] checkAppLock start (isResuming: $isResuming)');
      final houseId =
          _currentHouseId ?? await _houseService.getCurrentHouseId();
      final effectiveLockSettings = await _militaryLockService
          .getEffectiveLockSettings(houseId: houseId)
          .timeout(const Duration(seconds: 3));
      final isAppLockEnabled = effectiveLockSettings.enabled;
      final isScopeAppEnabled =
          effectiveLockSettings.isScopeEnabled(LockScope.app);
      final lockTimeoutMins = effectiveLockSettings.timeoutMinutes;

      if (!isAppLockEnabled ||
          !isScopeAppEnabled ||
          !effectiveLockSettings.hasConfiguredSecret) {
        debugPrint('[AppEntry] checkAppLock bypassed');
        return const AppEntryAuthState(
          isAuthenticated: true,
          isCheckingAuth: false,
        );
      }

      if (isResuming && _lastPausedAt != null && lockTimeoutMins > 0) {
        final diff = DateTime.now().difference(_lastPausedAt!);
        if (diff.inMinutes < lockTimeoutMins) {
          debugPrint('[AppEntry] checkAppLock skipped by timeout window');
          return const AppEntryAuthState(
            isAuthenticated: true,
            isCheckingAuth: false,
          );
        }
      }

      if (isResuming || !_militaryLockService.isScopeUnlocked(LockScope.app)) {
        _militaryLockService.lockAllScopes();
      }

      if (!context.mounted) return null;
      final authSuccess = await _militaryLockService
          .requestUnlock(
        context: context,
        scope: LockScope.app,
        houseId: houseId,
        title: context.tr('app_entry_khangdng_a0f538'),
        reason: MilitaryLockService.scopeReason(LockScope.app),
      )
          .timeout(const Duration(seconds: 8), onTimeout: () {
        debugPrint('[AppEntry] requestUnlock timed out, fail-open');
        return true;
      });
      debugPrint('[AppEntry] checkAppLock resolved: $authSuccess');
      return AppEntryAuthState(
        isAuthenticated: authSuccess,
        isCheckingAuth: false,
      );
    } catch (e, _) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('app_entry_khngthkimt_8544a4'),
      );
      debugPrint('[AppEntry] checkAppLock failed: ${errorInfo.message}');
      return const AppEntryAuthState(
        isAuthenticated: true,
        isCheckingAuth: false,
      );
    } finally {
      _isAuthenticating = false;
    }
  }

  void didHaveMemoryPressure() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint(
      L10nService().translate('app_entry_appentryht_a627df'),
    );
  }

  Future<void> handleAppBackgrounded({
    bool keepPresenceOnline = false,
  }) async {
    final pausedAt = DateTime.now();
    _lastPausedAt = pausedAt;
    await _persistBackgroundTimestamp(pausedAt);
    unawaited(_adMobService.pauseAutoInterstitialScheduler());
    EncryptionService().notifyAppBackgrounded();
    if (keepPresenceOnline) {
      unawaited(_sessionConnectivityCoordinator.goOnlineNow());
      return;
    }
    _sessionConnectivityCoordinator.scheduleOffline(pausedAt: pausedAt);
  }

  Future<AppEntryResumeResult> handleAppResumed({
    required BuildContext context,
  }) async {
    final compromisedState = await _resolveCompromisedAuthState();
    if (compromisedState != null) {
      _lastPausedAt = null;
      return AppEntryResumeResult(authState: compromisedState);
    }

    await _refreshPresenceContext();
    await _sessionConnectivityCoordinator.goOnlineNow();

    _scheduleDeviceRegistration();

    final shouldResetToHome = await _applyStaleSessionPolicy(
      keepInMemoryTimestamp: true,
    );
    if (shouldResetToHome) {
      return const AppEntryResumeResult(shouldResetToHome: true);
    }

    if (!context.mounted) {
      return const AppEntryResumeResult();
    }

    final authState = await checkAppLock(context: context, isResuming: true);
    if (authState?.isAuthenticated != true) {
      _lastPausedAt = null;
      return AppEntryResumeResult(authState: authState);
    }

    await _runGuarded(
      'record app open metric on resume',
      () => _recordAppOpenMetric(),
    );
    await _runGuarded(
      'refresh widget shell on resume',
      () => WidgetService.refreshWidgetShell(),
    );
    await _adMobService.resumeAutoInterstitialScheduler();
    _lastPausedAt = null;
    return AppEntryResumeResult(authState: authState);
  }

  Future<void> refreshForegroundPresence() async {
    await _refreshPresenceContext();
    await _sessionConnectivityCoordinator.goOnlineNow();
  }

  Future<AppEntryAuthState?> _resolveCompromisedAuthState() async {
    try {
      final isCompromised = await SecurityService()
          .isDeviceCompromised()
          .timeout(const Duration(seconds: 2), onTimeout: () {
        debugPrint('[AppEntry] isDeviceCompromised timed out, assume safe');
        return false;
      });
      if (!isCompromised) {
        return null;
      }

      return const AppEntryAuthState(
        isAuthenticated: false,
        isCheckingAuth: false,
        isCompromised: true,
      );
    } catch (e, _) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('app_entry_khngthkimt_823050'),
      );
      debugPrint('[AppEntry] isDeviceCompromised failed: ${errorInfo.message}');
      return null;
    }
  }

  Future<void> handleSignedOutSession() async {
    await _runGuarded(
      'reset widget state after sign out',
      () => WidgetService.resetWidgetState(),
    );
    await _runGuarded(
      'stop auto interstitial scheduler after sign out',
      () => _adMobService.stopAutoInterstitialScheduler(clearPersisted: true),
    );
    await _runGuarded(
      'clear presence session after sign out',
      clearPresenceSession,
    );
  }

  Future<void> handleMissingHouseSession() async {
    await _runGuarded(
      'stop auto interstitial scheduler without house context',
      () => _adMobService.stopAutoInterstitialScheduler(clearPersisted: true),
    );
  }

  Future<AppEntryHouseSessionResult> prepareSignedInHouseSession({
    required BuildContext context,
    required String houseId,
    required bool hasTriggeredInitialAppOpenAd,
  }) async {
    var didScheduleInitialAppOpenAd = false;

    _scheduleDeviceRegistration();

    if (_currentHouseId != houseId) {
      unawaited(
        _runGuarded(
          'prime presence in background',
          () => primePresenceInBackground(houseId),
        ),
      );
    }

    unawaited(
      _runGuarded(
        'sync critical user data',
        () => _criticalDataSyncService.syncCurrentUserData(houseId: houseId),
      ),
    );

    unawaited(
      _runGuarded(
        'initialize AdMob',
        () => _adMobService.initialize(),
      ),
    );

    unawaited(_runGuarded('preload rewarded ad', () async {
      _adMobService.preloadRewardedAd();
    }));
    unawaited(_runGuarded('preload soul game rewarded ad', () async {
      _adMobService.preloadSoulGameRewardedAd();
    }));

    if (!hasTriggeredInitialAppOpenAd) {
      didScheduleInitialAppOpenAd = true;
      Future<void>.delayed(const Duration(seconds: 4), () async {
        await _runGuarded(
          'show deferred startup app open ad after home stabilizes',
          () => _adMobService.showAppOpenAdIfEligible(),
        );
      });
    }

    unawaited(
      _runGuarded(
        'start auto interstitial scheduler',
        () => _adMobService.startAutoInterstitialScheduler(),
      ),
    );
    unawaited(
      _runGuarded(
        'record app open metric',
        () => _recordAppOpenMetric(houseId: houseId),
      ),
    );

    unawaited(
      _runGuarded('check smart reminders', () async {
        final prefs = await getPrefs();
        final relMode = prefs.getString('il_rel_mode') ?? 'couple';
        await _loveInsightService.checkAndNotifySmartReminders(
          houseId,
          relMode,
        );
      }),
    );

    unawaited(
      _runGuarded(
        'request startup permissions',
        () => requestStartupPermissionsIfNeeded(context),
      ),
    );

    unawaited(
      _runGuarded(
        'refresh widget shell after home session',
        () => WidgetService.refreshWidgetShell(),
      ),
    );

    return AppEntryHouseSessionResult(
      didScheduleInitialAppOpenAd: didScheduleInitialAppOpenAd,
    );
  }

  Future<void> requestStartupPermissionsIfNeeded(BuildContext context) async {
    if (kIsWeb || !context.mounted) return;
    final activeContext = context;

    final prefs = await getPrefs();
    final hasLegacyPrompted =
        prefs.getBool(_startupPermissionPromptedPrefsKey) ?? false;
    final hasPromptedNotification =
        prefs.getBool(_notificationPermissionPromptedPrefsKey) ?? false;
    final hasPromptedLocation =
        prefs.getBool(_locationPermissionPromptedPrefsKey) ?? false;
    if (!activeContext.mounted) return;

    if (!activeContext.mounted) return;

    var notificationGranted = false;
    if (!hasPromptedNotification) {
      notificationGranted =
          await NotificationService().requestPermissionAndInit();
      await prefs.setBool(_notificationPermissionPromptedPrefsKey, true);
      if (!activeContext.mounted) return;
    }

    var locationGranted = false;
    if (!hasPromptedLocation) {
      locationGranted =
          await LocationService().requestPermission(context: activeContext);
      await prefs.setBool(_locationPermissionPromptedPrefsKey, true);
    }

    if ((locationGranted || notificationGranted) && !hasLegacyPrompted) {
      await prefs.setBool(_startupPermissionPromptedPrefsKey, true);
    }
  }

  Future<void> clearPresenceSession() async {
    await _sessionConnectivityCoordinator.clearPresenceSession();
    _currentHouseId = null;
    _currentRole = null;
  }

  Future<void> primePresenceInBackground(String houseId) async {
    try {
      await _initPresence(houseId).timeout(const Duration(seconds: 3));
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('app_entry_khngthkhit_44915f'),
      );
      debugPrint('[AppEntry] Presence init deferred: ${errorInfo.message}');
    }
  }

  Future<bool> _applyStaleSessionPolicy({
    bool keepInMemoryTimestamp = false,
  }) async {
    final prefs = await getPrefs();
    final result = await _backgroundSessionTracker.applyResumePolicy(
      prefs,
      inMemoryPausedAt: _lastPausedAt,
      keepInMemoryTimestamp: keepInMemoryTimestamp,
    );
    _lastPausedAt = result.resolvedPausedAt;
    return result.shouldResetToHome;
  }

  Future<void> _persistBackgroundTimestamp(DateTime timestamp) async {
    final prefs = await getPrefs();
    await _backgroundSessionTracker.persistBackgroundTimestamp(
      prefs,
      timestamp,
    );
  }

  Future<void> _initPresence(String houseId) async {
    final prefs = await getPrefs();
    final role = RoleUtils.normalizeNullable(prefs.getString('il_role')) ??
        RoleUtils.normalizeNullable(_currentRole) ??
        'user1';
    _currentHouseId = houseId;
    _currentRole = role;
    _sessionConnectivityCoordinator.updatePresenceTarget(
      houseId: houseId,
      role: role,
      deviceType: 'flutter',
    );
    await _sessionConnectivityCoordinator.goOnlineNow();
  }

  Future<void> _refreshPresenceContext() async {
    final prefs = await getPrefs();
    final role = _normalizeRole(prefs.getString('il_role')) ??
        _normalizeRole(_currentRole) ??
        'user1';
    final houseId = await _houseService.getCurrentHouseId();
    _currentHouseId = houseId;
    _currentRole = houseId == null || houseId.isEmpty ? null : role;
    _sessionConnectivityCoordinator.updatePresenceTarget(
      houseId: _currentHouseId,
      role: _currentRole,
      deviceType: 'flutter',
    );
  }

  Future<void> _recordAppOpenMetric({
    String? houseId,
    String? role,
  }) async {
    final resolvedHouseId = (houseId ?? _currentHouseId ?? '').trim();
    if (resolvedHouseId.isEmpty) {
      return;
    }

    final resolvedRole = _normalizeRole(role) ??
        _normalizeRole(_currentRole) ??
        await _prefsRole;
    if (resolvedRole == null) {
      return;
    }

    await _interactionMetricsService.recordAppOpen(
      houseId: resolvedHouseId,
      role: resolvedRole,
    );
  }

  Future<String?> get _prefsRole async {
    final prefs = await getPrefs();
    return _normalizeRole(prefs.getString('il_role'));
  }

  String? _normalizeRole(String? value) {
    final role = value?.trim();
    if (role == 'user1' || role == 'user2') {
      return role;
    }
    return null;
  }

  void _scheduleDeviceRegistration() {
    final now = DateTime.now();
    final inFlight = _deviceRegistrationInFlight;
    if (inFlight != null) {
      return;
    }

    final lastStartedAt = _lastDeviceRegistrationStartedAt;
    if (lastStartedAt != null &&
        now.difference(lastStartedAt) < _deviceRegistrationCooldown) {
      return;
    }

    _lastDeviceRegistrationStartedAt = now;
    final future = _runGuarded(
      'register current device',
      () => _deviceManagerService.registerCurrentDevice(),
    );
    _deviceRegistrationInFlight = future;
    future.whenComplete(() {
      if (identical(_deviceRegistrationInFlight, future)) {
        _deviceRegistrationInFlight = null;
      }
    });
  }

  Future<void> _runGuarded(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e, _) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('app_entry_tcvnnchath_7a7b99'),
      );
      debugPrint('[AppEntry] $label failed: ${errorInfo.message}');
    }
  }
}
