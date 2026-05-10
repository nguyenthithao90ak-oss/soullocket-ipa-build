import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../services/auth_service.dart';
import '../services/deeplink_service.dart';
import '../services/house_service.dart';
import '../services/image_picker_recovery_service.dart';
import '../services/military_lock_service.dart';
import '../services/offline_cache_service.dart';
import '../services/storage_service.dart';
import '../services/widget_action_service.dart';
import '../utils/services/app_lifecycle_presence_guard.dart';
import '../utils/app_error_mapper.dart';
import 'app_entry/app_entry_access_resolver.dart';
import 'app_entry/app_entry_home_asset_preparer.dart';
import 'app_entry/app_entry_controller.dart';
import 'app_entry/app_entry_deeplink_handler.dart';
import 'app_entry/widgets/blocked_scaffold.dart';
import 'app_entry/widgets/locked_scaffold.dart';
import 'app_entry/widgets/loading_scaffold.dart';
import 'auth/auth_action_screen.dart';
import 'auth/lock_appeal_screen.dart';
import 'consent/consent_gate.dart';
import 'home/home_screen.dart';
import 'house_onboarding_screen.dart';
import 'login_screen.dart';
import 'home/tabs/diary/controllers/diary_memory_controller.dart';

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> with WidgetsBindingObserver {
  static const Duration _webAuthStreamGracePeriod =
      Duration(milliseconds: 1200);

  final _authService = AuthService();
  final _houseService = HouseService();

  late final AppEntryController _appEntryController;
  late final AppEntryAccessResolver _accessResolver;
  late final AppEntryDeeplinkHandler _deeplinkHandler;
  late final AppEntryHomeAssetPreparer _homeAssetPreparer;
  late final Stream<User?> _authStream;

  StreamSubscription? _maintenanceSub;

  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;
  bool _isCompromised = false;
  bool _splashRemoved = false;
  bool _authStreamTimeout = false;
  bool _hasTriggeredInitialAppOpenAd = false;

  String? _lastUserId;
  Future<AppEntryAccessState>? _accessStateFuture;
  AppEntryAccessState? _initialAccessState;
  OverlayEntry? _privacyGuardEntry;

  @override
  void initState() {
    super.initState();
    _appEntryController = AppEntryController(houseService: _houseService);
    _accessResolver = AppEntryAccessResolver(
      authService: _authService,
      houseService: _houseService,
      getPrefs: _appEntryController.getPrefs,
    );
    _deeplinkHandler = AppEntryDeeplinkHandler(houseService: _houseService);
    _homeAssetPreparer = AppEntryHomeAssetPreparer();
    _authStream = FirebaseAuth.instance.authStateChanges();

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(WidgetActionService().initialize());
      unawaited(() async {
        await ImagePickerRecoveryService.instance.primeLostData();
        if (!mounted ||
            !ImagePickerRecoveryService.instance.hasPendingRecoveredImages) {
          return;
        }
        _showRootSnackBar(
          'Đã khôi phục ảnh đang chọn trước đó. Mở lại chức năng ảnh để tiếp tục.',
        );
      }());

      if (!kIsWeb) {
        _appEntryController.scheduleDeferredStartupTasks(
          isMounted: () => mounted,
        );
      }

      if (kIsWeb && DeeplinkService.isSupportedGiftUri(Uri.base)) {
        unawaited(
          _deeplinkHandler.handleInitialWebGiftLink(
            context: context,
            uri: Uri.base,
            showSnackBar: _showRootSnackBar,
          ),
        );
      }

      if (!(kIsWeb &&
          (DeeplinkService.isSupportedAuthUri(Uri.base) ||
              DeeplinkService.isSupportedGiftUri(Uri.base)))) {
        unawaited(
          _deeplinkHandler.initialize(
            context: context,
            showSnackBar: _showRootSnackBar,
          ),
        );
      }

      unawaited(_bootstrapAppEntry());
    });

    _listenToMaintenance();
    _scheduleAuthStreamTimeout();
  }

  void _scheduleAuthStreamTimeout() {
    if (!kIsWeb && FirebaseAuth.instance.currentUser == null) {
      _authStreamTimeout = true;
      return;
    }

    Future.delayed(_webAuthStreamGracePeriod, () {
      if (!mounted || _authStreamTimeout) return;
      setState(() {
        _authStreamTimeout = true;
      });
    });
  }

  void _removeSplashOnce() {
    if (_splashRemoved || kIsWeb) return;
    _splashRemoved = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  void _listenToMaintenance() {
    _maintenanceSub = FirebaseDatabase.instance
        .ref('sys_settings/is_maintenance')
        .onValue
        .listen((event) async {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final isMaintenance = event.snapshot.value == true;
      final isAdmin = await _authService.isUserAdmin(user);
      if (!mounted || isAdmin) return;

      setState(() {
        if (isMaintenance) {
          _initialAccessState = const AppEntryAccessState(
            isAdmin: false,
            isMaintenance: true,
          );
          _accessStateFuture = Future.value(_initialAccessState);
          return;
        }

        _accessStateFuture = _accessResolver.resolveAccessState(
          user: user,
          userId: user.uid,
          onBackgroundState: (state) {
            _handleBackgroundAccessState(
              state,
              userId: user.uid,
              cachedHouseId: null,
            );
          },
        );
      });
    }, onError: (Object error, StackTrace stackTrace) {
      final message = error.toString();
      if (message.contains('permission-denied')) {
        return;
      }
      debugPrint(
        '[AppEntry] Maintenance listener error: ${AppErrorMapper.resolve(error).message}',
      );
    });
  }

  void _applyAuthState(AppEntryAuthState state) {
    if (state.isAuthenticated && !_isAuthenticated) {
      unawaited(DiaryMemoryController().clearPendingUploadState(notify: false));
    }
    setState(() {
      _isAuthenticated = state.isAuthenticated;
      _isCheckingAuth = state.isCheckingAuth;
      _isCompromised = state.isCompromised;
    });
  }

  void _handleBackgroundAccessState(
    AppEntryAccessState state, {
    required String? userId,
    required String? cachedHouseId,
  }) {
    if (!mounted || _lastUserId != userId) return;
    setState(() {
      _accessStateFuture = Future.value(state);
    });
  }

  void _configureAccessResolution(User user) {
    final prefs = OfflineCacheService.getPrefsSync();
    final cachedHouseId = prefs?.getString('il_auth_uid') == user.uid
        ? prefs?.getString('il_house_id')
        : null;
    final resolution = _accessResolver.createResolution(
      user: user,
      cachedHouseId: cachedHouseId,
      onBackgroundState: _handleBackgroundAccessState,
    );
    _initialAccessState = resolution.initialState;
    _accessStateFuture = resolution.future;
  }

  Future<void> _refreshCurrentUserAccess() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _lastUserId = null;
        _initialAccessState = null;
        _accessStateFuture = null;
        _hasTriggeredInitialAppOpenAd = false;
      });
      return;
    }

    setState(() {
      _lastUserId = user.uid;
      _configureAccessResolution(user);
    });
  }

  void _showRootSnackBar(
    String message, {
    bool isSuccess = false,
  }) {
    if (!mounted) return;
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..clearSnackBars()
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor:
                isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          ),
        );
    } catch (e) {
      // Context may not be valid after widget disposal
    }
  }

  Future<void> _bootstrapAppEntry() async {
    final authState = await _appEntryController.bootstrap(context: context);
    if (!mounted) return;
    _applyAuthState(authState);
  }

  void _prepareHomeAssets(String houseId) {
    final future = _homeAssetPreparer.prepareIfNeeded(houseId);
    if (future != null) {
      unawaited(future);
    }
  }

  Widget _buildSignedInHouseContent(BuildContext context, String houseId) {
    _prepareHomeAssets(houseId);

    _removeSplashOnce();
    return ConsentGate(
      onReady: () async {
        unawaited(() async {
          try {
            debugPrint(
              '[AppEntry] prepareSignedInHouseSession start: $houseId',
            );
            final sessionResult =
                await _appEntryController.prepareSignedInHouseSession(
              context: context,
              houseId: houseId,
              hasTriggeredInitialAppOpenAd: _hasTriggeredInitialAppOpenAd,
            );
            if (sessionResult.didScheduleInitialAppOpenAd) {
              _hasTriggeredInitialAppOpenAd = true;
            }
            debugPrint(
              '[AppEntry] prepareSignedInHouseSession finished: $houseId',
            );
          } catch (e) {
            debugPrint(
              '[AppEntry] prepareSignedInHouseSession failed: '
              '${AppErrorMapper.resolve(e).message}',
            );
          }
        }());
      },
      child: const HomeScreen(),
    );
  }

  Future<void> _checkAppLock({bool isResuming = false}) async {
    final authState = await _appEntryController.checkAppLock(
      context: context,
      isResuming: isResuming,
    );
    if (!mounted || authState == null) return;
    _applyAuthState(authState);
  }

  Future<void> _handleAppResumed() async {
    final result = await _appEntryController.handleAppResumed(
      context: context,
    );
    if (!mounted) return;

    final authState = result.authState;
    if (authState != null) {
      _applyAuthState(authState);
    }

    if (!result.shouldResetToHome) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil(
        (route) => route.isFirst,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _maintenanceSub?.cancel();
    _appEntryController.dispose();
    _removePrivacyGuard();
    super.dispose();
  }

  void _showPrivacyGuard() {
    if (_privacyGuardEntry != null || !mounted) return;
    final overlay = Overlay.of(context);
    _privacyGuardEntry = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security_rounded, color: Colors.white, size: 64),
              SizedBox(height: 16),
              Text(
                'Chống nhìn trộm đang bật',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    overlay.insert(_privacyGuardEntry!);
  }

  void _removePrivacyGuard() {
    _privacyGuardEntry?.remove();
    _privacyGuardEntry = null;
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    _appEntryController.didHaveMemoryPressure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb && StorageService.shouldIgnoreWebLifecyclePulse) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _removePrivacyGuard();
      if (_appEntryController.hasPendingResume) {
        unawaited(_handleAppResumed());
      } else {
        unawaited(_appEntryController.refreshForegroundPresence());
      }
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      if (MilitaryLockService.isAuthenticatingBiometrics) return;

      unawaited(() async {
        if (await MilitaryLockService().isMilitaryModeEnabled()) {
          _showPrivacyGuard();
        }
      }());

      if (state != AppLifecycleState.inactive) {
        unawaited(
          _appEntryController.handleAppBackgrounded(
            keepPresenceOnline:
                AppLifecyclePresenceGuard.shouldKeepPresenceOnline,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    if (kIsWeb && DeeplinkService.isSupportedAuthUri(Uri.base)) {
      _removeSplashOnce();
      return AuthActionScreen(initialUri: Uri.base);
    }

    if (_isCheckingAuth) {
      return const LoadingScaffold();
    }

    if (_isCompromised) {
      _removeSplashOnce();
      return const BlockedScaffold(
        title: 'Thiết bị không an toàn',
        message:
            'Thiết bị của bạn đang trong trạng thái Root hoặc dùng phần mềm Fake GPS.\n\nĐể bảo vệ dữ liệu cá nhân, SoulLocket tự động vô hiệu hóa trên môi trường này.',
        showActions: false,
      );
    }

    if (!_isAuthenticated) {
      _removeSplashOnce();
      return LockedScaffold(onUnlock: _checkAppLock);
    }

    return StreamBuilder<User?>(
      stream: _authStream,
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            !_authStreamTimeout) {
          return const LoadingScaffold();
        }

        if (snapshot.hasError) {
          _removeSplashOnce();
          return BlockedScaffold(
            title: 'Lỗi xác thực',
            message: kDebugMode
                ? 'Không thể kết nối hệ thống xác thực. Vui lòng thử lại.\n${AppErrorMapper.resolve(snapshot.error).message}'
                : 'Không thể kiểm tra đăng nhập. Hãy kiểm tra mạng rồi mở lại ứng dụng.',
            onSignOut: () async {},
          );
        }

        final user = snapshot.data;
        if (user == null) {
          unawaited(_appEntryController.handleSignedOutSession());
          _lastUserId = null;
          _hasTriggeredInitialAppOpenAd = false;
          _initialAccessState = null;
          _accessStateFuture = null;
          _removeSplashOnce();
          return const ConsentGate(child: LoginScreen());
        }

        if (_accessStateFuture == null || _lastUserId != user.uid) {
          _lastUserId = user.uid;
          _configureAccessResolution(user);
        }

        return FutureBuilder<AppEntryAccessState>(
          initialData: _initialAccessState,
          future: _accessStateFuture,
          builder: (context, accessSnap) {
            final accessState = accessSnap.data;

            if (accessSnap.connectionState == ConnectionState.waiting) {
              final cachedHouseId = accessState?.houseId;
              if (cachedHouseId != null && cachedHouseId.isNotEmpty) {
                return _buildSignedInHouseContent(context, cachedHouseId);
              }
              return const LoadingScaffold();
            }

            if (accessSnap.hasError) {
              _removeSplashOnce();
              return BlockedScaffold(
                title: 'Lỗi hệ thống',
                message:
                    'Không thể tải thông tin tài khoản.\n${AppErrorMapper.resolve(accessSnap.error).message}',
                onSignOut: () async {
                  await _authService.signOut();
                },
              );
            }

            if (accessState?.isMaintenance == true &&
                accessState?.isAdmin != true) {
              _removeSplashOnce();
              return const BlockedScaffold(
                title: 'Bảo trì hệ thống',
                message:
                    'Chúng tôi đang bảo trì hệ thống để nâng cấp trải nghiệm tốt hơn. Vui lòng quay lại sau ít phút.',
                showActions: false,
              );
            }

            if (accessState?.blockReason != null) {
              _removeSplashOnce();
              return BlockedScaffold(
                title: 'Tài khoản bị khóa',
                message: accessState!.blockReason!,
                onSignOut: () async {
                  await _authService.signOut();
                },
                onAppeal: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LockAppealScreen(),
                    ),
                  );
                },
              );
            }

            final houseId = accessState?.houseId;
            if (houseId == null || houseId.isEmpty) {
              unawaited(_appEntryController.handleMissingHouseSession());
              _hasTriggeredInitialAppOpenAd = false;
              _removeSplashOnce();
              return ConsentGate(
                child: HouseOnboardingScreen(
                  autoCreateOnly: true,
                  initialHouseName: 'Chúng mình',
                  onHouseCreated: _refreshCurrentUserAccess,
                  onSignedOut: _refreshCurrentUserAccess,
                ),
              );
            }

            return _buildSignedInHouseContent(context, houseId);
          },
        );
      },
    );
  }
}
