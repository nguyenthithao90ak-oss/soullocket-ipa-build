import 'package:soullocket_app/widgets/sl_image_crop_file.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/breakup_notice_copy.dart';
import 'package:soullocket_app/widgets/sl_settings_kit.dart';
import 'package:soullocket_app/widgets/getting_started_guide.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/utils/services/breakup_service.dart';
import 'package:soullocket_app/utils/services/role_utils.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_create_code_sheet.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_cute_kit.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_enter_code_sheet.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_quick_connect_sheet.dart';
import 'pairing_connection_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:soullocket_app/utils/services/storage/storage_picker_service.dart';
import 'package:soullocket_app/utils/services/infrastructure/storage_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_connection_date.dart';
import 'pairing_display_cache.dart';
import 'pairing_shortcut_state.dart';
import '../../../../../utils/services/offline_cache_service.dart';
import '../relationship/relationship_actions.dart';

class PairingDashboardScreen extends StatefulWidget {
  const PairingDashboardScreen({super.key});

  @override
  State<PairingDashboardScreen> createState() => _PairingDashboardScreenState();
}

class _PairingDashboardScreenState extends State<PairingDashboardScreen> {
  String? _myHouseId;
  bool _isPaired = false;
  bool _isLoading = true;
  String? _avatarU1;
  String? _avatarU2;
  String? _nameU1;
  String? _nameU2;
  bool _genderSwapped = false;
  Object? _connectedAt;
  Map _members = const {};
  bool _connectionDateReceived = false;
  bool _connectionDateError = false;
  String? _uploadingRole;
  String? _scopeUid;
  bool _settingsReceived = false;
  bool _membersReceived = false;
  bool _settingsPaired = false;
  bool _membersPaired = false;
  bool _hasResolvedPairing = false;
  bool _loadError = false;
  int _loadGeneration = 0;
  Timer? _loadTimer;
  Timer? _dateTimer;
  StreamSubscription<User?>? _authSub;
  StreamSubscription? _settingsSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _connectionDateSub;
  Stream<List<PairingRequest>>? _incomingRequestsStream;
  String? _respondingRequestId;
  PairingShortcutState _displayCacheState = PairingShortcutState();
  final SettingsRelationshipWatcher _breakupWatcher =
      SettingsRelationshipWatcher();
  BreakupRequestData? _breakupRequest;
  bool _breakupBusy = false;

  String _t(String key) => context.tr(key);

  @override
  void initState() {
    super.initState();
    _loadHouseId();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted && user?.uid != _scopeUid) _loadHouseId();
    });
  }

  @override
  void dispose() {
    _loadGeneration++;
    _loadTimer?.cancel();
    _dateTimer?.cancel();
    _authSub?.cancel();
    _settingsSub?.cancel();
    _membersSub?.cancel();
    _connectionDateSub?.cancel();
    _breakupWatcher.dispose();
    super.dispose();
  }

  Future<void> _loadHouseId() async {
    final generation = ++_loadGeneration;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _scopeUid = uid;
    final prefs = OfflineCacheService.getPrefsSync();
    final cachedHouseId = uid != null && prefs?.getString('il_auth_uid') == uid
        ? prefs?.getString('il_house_id')?.trim()
        : null;
    final cachedState = cachedHouseId == null
        ? PairingShortcutState()
        : PairingDisplayCache.restore(
            uid: uid,
            houseId: cachedHouseId,
            prefs: prefs,
          );
    final cachedSettings = cachedState.settings;
    _loadTimer?.cancel();
    _dateTimer?.cancel();
    unawaited(_settingsSub?.cancel());
    unawaited(_membersSub?.cancel());
    unawaited(_connectionDateSub?.cancel());
    _breakupWatcher.dispose();
    setState(() {
      _isLoading = true;
      _loadError = false;
      _hasResolvedPairing = false;
      _settingsReceived = false;
      _membersReceived = false;
      _settingsPaired = false;
      _membersPaired = false;
      _isPaired = false;
      _connectedAt = null;
      _members = const {};
      _connectionDateReceived = false;
      _connectionDateError = false;
      _uploadingRole = null;
      _myHouseId = null;
      _nameU1 = null;
      _nameU2 = null;
      _avatarU1 = null;
      _avatarU2 = null;
      _incomingRequestsStream = null;
      _breakupRequest = null;
      _breakupBusy = false;
      _displayCacheState = cachedState;
      _myHouseId = cachedHouseId;
      _isPaired = cachedState.ready && cachedState.paired;
      _hasResolvedPairing = cachedState.ready;
      _isLoading = !cachedState.ready;
      if (cachedState.ready) {
        _nameU1 = cachedSettings['nameU1']?.toString();
        _nameU2 = cachedSettings['nameU2']?.toString();
        _genderSwapped = RoleUtils.readGenderSwapped(cachedSettings);
        _avatarU1 = pairingAvatarUrl(cachedSettings, 'user1');
        _avatarU2 = pairingAvatarUrl(cachedSettings, 'user2');
      }
    });
    bool isCurrent() =>
        mounted &&
        generation == _loadGeneration &&
        FirebaseAuth.instance.currentUser?.uid == uid;
    void handleLoadError(Object error) {
      if (!isCurrent()) return;
      final revoked =
          error is FirebaseException && error.code == 'permission-denied';
      if (_hasResolvedPairing && !revoked) return;
      if (revoked) {
        _loadGeneration++;
        _loadTimer?.cancel();
        _dateTimer?.cancel();
        unawaited(_settingsSub?.cancel());
        unawaited(_membersSub?.cancel());
        unawaited(_connectionDateSub?.cancel());
      }
      setState(() {
        _isLoading = false;
        _loadError = true;
        if (revoked) {
          _myHouseId = null;
          _incomingRequestsStream = null;
          _connectedAt = null;
          _members = const {};
          _nameU1 = null;
          _nameU2 = null;
          _avatarU1 = null;
          _avatarU2 = null;
          _isPaired = false;
        }
      });
    }

    if (uid == null) {
      setState(() {
        _isLoading = false;
        _loadError = true;
      });
      return;
    }

    if (!cachedState.ready) {
      _loadTimer = Timer(const Duration(seconds: 8), () {
        handleLoadError(TimeoutException('Pairing state unavailable'));
      });
    }
    String? houseId;
    try {
      houseId = await HouseService().getCurrentHouseId(preferFresh: false);
    } catch (error) {
      handleLoadError(error);
      return;
    }
    if (!isCurrent()) return;
    if (houseId == null) {
      _loadTimer?.cancel();
      setState(() => _isLoading = false);
      return;
    }
    _myHouseId = houseId;
    void rememberDisplay() {
      if (!isCurrent()) return;
      unawaited(
        PairingDisplayCache.remember(
          uid: uid,
          houseId: houseId!,
          state: _displayCacheState,
        ).catchError((Object error) {
          debugPrint('[Pairing] Display cache unavailable: $error');
        }),
      );
    }

    _incomingRequestsStream = PairingService.instance.listenToIncomingRequests(
      houseId,
    );
    _breakupWatcher.bind(
      houseId: houseId,
      onChanged: (request) {
        if (!isCurrent()) return;
        setState(() => _breakupRequest = request);
      },
      getFallbackRequest: () => _breakupRequest,
    );

    // Đây là màn đọc trạng thái. Không tự ghi isPaired hay sửa chế độ ghép nối.
    _settingsSub = FirebaseDatabase.instance
        .ref('houses/$houseId/settings')
        .onValue
        .listen((event) {
          if (!isCurrent()) return;
          final value = event.snapshot.value;
          final settings = value is Map ? value : const {};
          _displayCacheState.applySettings(settings);
          setState(() {
            _settingsReceived = true;
            _settingsPaired = settings['isPaired'] == true;
            _nameU1 = settings['nameU1']?.toString();
            _nameU2 = settings['nameU2']?.toString();
            _genderSwapped = RoleUtils.readGenderSwapped(settings);
            _avatarU1 = pairingAvatarUrl(settings, 'user1');
            _avatarU2 = pairingAvatarUrl(settings, 'user2');
          });
          rememberDisplay();
          _applyPairingStatus();
        }, onError: handleLoadError);

    // Theo dõi thành viên liên tục để trạng thái không bị lùi về chưa ghép
    // khi settings được cập nhật nhưng cờ isPaired ở dữ liệu cũ còn thiếu.
    _membersSub = FirebaseDatabase.instance
        .ref('houses/$houseId/members')
        .onValue
        .listen(
          (event) {
            if (!isCurrent()) return;
            final value = event.snapshot.value;
            final members = value is Map ? value : const {};
            _displayCacheState.applyMembers(members);
            _membersReceived = true;
            _membersPaired = members.length >= 2;
            _members = members;
            rememberDisplay();
            _applyPairingStatus();
          },
          onError: (Object error) {
            if (!isCurrent()) return;
            setState(() {
              _membersReceived = true;
              _connectionDateError = true;
            });
            handleLoadError(error);
          },
        );

    _dateTimer = Timer(const Duration(seconds: 8), () {
      if (isCurrent() && !_connectionDateReceived) {
        setState(() {
          _connectionDateReceived = true;
          _connectionDateError = true;
        });
      }
    });
    _connectionDateSub = FirebaseDatabase.instance
        .ref('houses/$houseId/coupleConnectedAt')
        .onValue
        .listen(
          (event) {
            if (!isCurrent()) return;
            _dateTimer?.cancel();
            setState(() {
              _connectedAt = event.snapshot.value;
              _connectionDateReceived = true;
              _connectionDateError = false;
            });
          },
          onError: (Object error) {
            if (!isCurrent()) return;
            _dateTimer?.cancel();
            setState(() {
              _connectedAt = null;
              _connectionDateReceived = true;
              _connectionDateError = true;
            });
          },
        );
  }

  void _applyPairingStatus() {
    final paired = _settingsPaired || _membersPaired;
    if (!paired && (!_settingsReceived || !_membersReceived)) return;
    final justConnected = _hasResolvedPairing && !_isPaired && paired;
    _loadTimer?.cancel();
    setState(() {
      _isPaired = paired;
      _hasResolvedPairing = true;
      _isLoading = false;
      _loadError = false;
    });
    if (justConnected) _showCongratulationDialog();
  }

  void _showCreateCodeSheet() {
    if (_myHouseId == null || _isPaired || _isLoading || _loadError) return;
    final houseId = _myHouseId!;
    showPairingCuteDialog<void>(
      context,
      builder: (_) => PairingCreateCodeSheet(myHouseId: houseId),
    );
  }

  Future<void> _showQuickConnectSheet() async {
    final houseId = _myHouseId;
    if (houseId == null || _isPaired || _isLoading || _loadError) return;
    await PairingQuickConnectSheet.show(context, houseId: houseId);
  }

  void _showEnterCodeSheet() async {
    if (_isPaired || _isLoading || _loadError) return;
    await showPairingCuteDialog<bool>(
      context,
      builder: (_) => const PairingEnterCodeSheet(),
    );
    // Reload if merged
    if (mounted) _loadHouseId();
  }

  Future<void> _respondToRequest(
    PairingRequest request, {
    required bool accept,
  }) async {
    if (_respondingRequestId != null) {
      return;
    }
    setState(() => _respondingRequestId = request.requestId);
    try {
      if (accept) {
        await PairingService.instance.acceptRequest(request.requestId);
      } else {
        await PairingService.instance.rejectRequest(request.requestId);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final fallbackKey = accept
          ? 'pairing_ui_request_accept_error'
          : 'pairing_ui_request_reject_error';
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            AppErrorMapper.resolve(
              error,
              fallbackMessage: _t(fallbackKey),
            ).message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingRequestId = null);
      }
    }
  }

  void _showCongratulationDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: _t('pairing_ui_congrats_title'),
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: SLSettingsColors.surface,
                borderRadius: BorderRadius.circular(SLSettingsRadius.sheet),
                boxShadow: [
                  BoxShadow(
                    color: SLSettingsColors.ink.withValues(alpha: 0.16),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: SLSettingsColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: SLSettingsColors.accent,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _t('pairing_ui_congrats_title'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: SLSettingsColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('pairing_ui_congrats_body'),
                    textAlign: TextAlign.center,
                    style: SLSettingsText.body(SLSettingsColors.inkSecondary),
                  ),
                  const SizedBox(height: 32),
                  SLSettingsButton(
                    label: _t('pairing_ui_congrats_action'),
                    icon: Icons.favorite_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetailedGuide() {
    showGettingStartedArticle(context, GettingStartedTopic.pairing);
  }

  @override
  Widget build(BuildContext context) {
    final colors = PairingPalette(
      Theme.of(context).brightness == Brightness.dark,
    );
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _t('pairing_ui_dashboard_nav_title'),
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        ),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: SLSettingsBackButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              isDark: colors.dark,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          if (!_isLoading && !_loadError && !_isPaired)
            IconButton(
              tooltip: _t('pairing_ui_dashboard_help'),
              icon: Icon(
                Icons.help_outline_rounded,
                color: colors.muted,
                size: 22,
              ),
              onPressed: _showDetailedGuide,
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(color: colors.background),
        child: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError
              ? _buildLoadError()
              : _isPaired
              ? _buildPairedState()
              : _buildUnpairedState(),
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SLSettingsIconTile(
              icon: Icons.cloud_off_outlined,
              color: SLSettingsColors.slate,
              filled: false,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              _t('pairing_ui_state_load_error'),
              textAlign: TextAlign.center,
              style: SLSettingsText.body(SLSettingsColors.inkSecondary),
            ),
            const SizedBox(height: 16),
            SLSettingsButton(
              label: _t('pairing_ui_state_retry'),
              icon: Icons.refresh_rounded,
              variant: SLSettingsButtonVariant.tonal,
              expand: false,
              onPressed: _loadHouseId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnpairedState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          children: [
            _buildPairingIntro(),
            const SizedBox(height: 22),
            SLSettingsButton(
              key: const ValueKey<String>('pairing-dashboard-quick-connect'),
              label: _t('pairing_ui_dashboard_start_title'),
              icon: Icons.favorite_rounded,
              onPressed: _showQuickConnectSheet,
            ),
            const SizedBox(height: 14),
            SLSettingsGroup(
              margin: EdgeInsets.zero,
              autoDividers: true,
              children: [
                _buildActionRow(
                  title: _t('pairing_ui_dashboard_create_action'),
                  subtitle: _t('pairing_ui_dashboard_create_subtitle'),
                  icon: Icons.add_link_rounded,
                  color: SLSettingsColors.rose,
                  onTap: _showCreateCodeSheet,
                ),
                _buildActionRow(
                  title: _t('pairing_ui_dashboard_enter_action'),
                  subtitle: _t('pairing_ui_dashboard_enter_subtitle'),
                  icon: Icons.qr_code_scanner_rounded,
                  color: SLSettingsColors.teal,
                  onTap: _showEnterCodeSheet,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSecurityNote(),
            _buildRequestsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingIntro() {
    return Column(
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 126,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: SLSettingsColors.accentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SLSettingsColors.surface,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: SLSettingsColors.accentStrong,
                      size: 27,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: SLSettingsColors.surfaceMuted,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SLSettingsColors.surface,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: SLSettingsColors.inkSecondary,
                      size: 27,
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: SLSettingsColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: SLSettingsColors.accent,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 17),
        Text(
          _t('pairing_ui_dashboard_title'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            color: SLSettingsColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Text(
            _t('pairing_ui_dashboard_subtitle'),
            textAlign: TextAlign.center,
            style: SLSettingsText.caption(SLSettingsColors.inkSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          color: SLSettingsColors.inkTertiary,
          size: 14,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _t('pairing_ui_dashboard_security_short'),
            textAlign: TextAlign.center,
            style: SLSettingsText.caption(SLSettingsColors.inkTertiary),
          ),
        ),
      ],
    );
  }

  Map? _currentMember() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return null;
    final direct = _members[uid];
    if (direct is Map) return direct;
    for (final value in _members.values) {
      if (value is Map && value['uid']?.toString() == uid) return value;
    }
    return null;
  }

  String _currentRole() {
    final role = _currentMember()?['role']?.toString().trim().toLowerCase();
    if (role == 'user2') return 'user2';
    return 'user1';
  }

  String _currentName() {
    final value = _currentMember()?['displayName']?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
    final role = _currentRole();
    final saved = role == 'user2' ? _nameU2 : _nameU1;
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    return _t(
      RoleUtils.defaultNameKey(role, genderSwapped: _genderSwapped),
    );
  }

  Future<bool> _confirmBreakupAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showBreakupMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(content: Text(message)),
    );
  }

  Future<void> _requestBreakupFromPairing() async {
    final houseId = _myHouseId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (houseId == null || uid == null || _breakupBusy) return;
    final confirmed = await _confirmBreakupAction(
      title: _t('home_chiatayxad_3b2b07'),
      message: BreakupNoticeCopy.requestConfirmation(isSingle: false),
      confirmLabel: _t('home_xcnhngiyuc_81446c'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _breakupBusy = true);
    try {
      final result = await SettingsRelationshipActionRunner().requestBreakup(
        houseId: houseId,
        role: _currentRole(),
        userName: _currentName(),
        userUid: uid,
        isSingleRelationship: false,
        pinRequired: false,
      );
      if (mounted) {
        _breakupRequest = result.request ?? _breakupRequest;
        _showBreakupMessage(result.message);
      }
      await _breakupWatcher.refresh(
        houseId: houseId,
        onChanged: (request) {
          if (mounted) setState(() => _breakupRequest = request);
        },
        evaluate: false,
      );
    } catch (error) {
      if (mounted) {
        _showBreakupMessage(
          AppErrorMapper.resolve(
            error,
            fallbackMessage: _t('home_chathrtliy_6cc6e9'),
          ).message,
        );
      }
    } finally {
      if (mounted) setState(() => _breakupBusy = false);
    }
  }

  Future<void> _approveBreakupFromPairing() async {
    final houseId = _myHouseId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (houseId == null || uid == null || _breakupBusy) return;
    final confirmed = await _confirmBreakupAction(
      title: _t('home_bnkiaangch_b287d3'),
      message: BreakupNoticeCopy.approveConfirmation,
      confirmLabel: _t('breakup_approve_now'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _breakupBusy = true);
    try {
      final result = await BreakupService().approveBreakup(
        houseId: houseId,
        role: _currentRole(),
        userName: _currentName(),
        currentUid: uid,
      );
      if (mounted) {
        _breakupRequest = result.request ?? _breakupRequest;
        _showBreakupMessage(result.message);
      }
      await _breakupWatcher.refresh(
        houseId: houseId,
        onChanged: (request) {
          if (mounted) setState(() => _breakupRequest = request);
        },
        evaluate: false,
      );
    } catch (error) {
      if (mounted) {
        _showBreakupMessage(
          AppErrorMapper.resolve(
            error,
            fallbackMessage: _t('breakup_no_pending'),
          ).message,
        );
      }
    } finally {
      if (mounted) setState(() => _breakupBusy = false);
    }
  }

  Future<void> _withdrawBreakupFromPairing() async {
    final houseId = _myHouseId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (houseId == null || uid == null || _breakupBusy) return;
    final confirmed = await _confirmBreakupAction(
      title: _t('home_rtliyucu_29ae92'),
      message: _t('home_bnchcchnmu_a5cf3b'),
      confirmLabel: _t('home_rtliyucu_29ae92'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _breakupBusy = true);
    try {
      final result = await SettingsRelationshipActionRunner().withdrawBreakup(
        houseId: houseId,
        role: _currentRole(),
        userName: _currentName(),
        currentUid: uid,
      );
      if (mounted) {
        _breakupRequest = result.request ?? _breakupRequest;
        _showBreakupMessage(result.message);
      }
      await _breakupWatcher.refresh(
        houseId: houseId,
        onChanged: (request) {
          if (mounted) setState(() => _breakupRequest = request);
        },
        evaluate: false,
      );
    } catch (error) {
      if (mounted) {
        _showBreakupMessage(
          AppErrorMapper.resolve(
            error,
            fallbackMessage: _t('home_chathrtliy_6cc6e9'),
          ).message,
        );
      }
    } finally {
      if (mounted) setState(() => _breakupBusy = false);
    }
  }

  Widget _buildPairedState() {
    String nameForRole(String? saved, String role, String fallback) {
      if (saved != null && saved.trim().isNotEmpty) return saved.trim();
      for (final value in _members.values) {
        if (value is Map && value['role'] == role) {
          final name = value['displayName'];
          if (name is String && name.trim().isNotEmpty) return name.trim();
        }
      }
      return _t(fallback);
    }

    final connection = resolvePairingConnectionDetails(
      connectedAt: _connectedAt,
      members: _members,
      now: DateTime.now(),
    );
    return PairingConnectedView(
      firstName: nameForRole(
        _nameU1,
        'user1',
        RoleUtils.defaultNameKey('user1', genderSwapped: _genderSwapped),
      ),
      secondName: nameForRole(
        _nameU2,
        'user2',
        RoleUtils.defaultNameKey('user2', genderSwapped: _genderSwapped),
      ),
      firstAvatar: _avatarU1,
      secondAvatar: _avatarU2,
      connection: connection,
      connectionLoading:
          connection == null &&
          !_connectionDateError &&
          (!_connectionDateReceived || !_membersReceived),
      connectionError: _connectionDateError,
      uploadingRole: _uploadingRole,
      onEditFirst: () => _updateAvatar('user1'),
      onEditSecond: () => _updateAvatar('user2'),
      onRetry: _loadHouseId,
      breakupRequest: _breakupRequest,
      breakupBusy: _breakupBusy,
      currentUid: FirebaseAuth.instance.currentUser?.uid,
      onRequestBreakup: () => unawaited(_requestBreakupFromPairing()),
      onApproveBreakup: () => unawaited(_approveBreakupFromPairing()),
      onWithdrawBreakup: () => unawaited(_withdrawBreakupFromPairing()),
    );
  }

  Future<void> _updateAvatar(String role) async {
    if (_myHouseId == null || _isLoading || _uploadingRole != null) return;
    final houseId = _myHouseId!;
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    final generation = _loadGeneration;
    if (ownerUid == null) return;
    bool isCurrent() =>
        mounted &&
        generation == _loadGeneration &&
        _myHouseId == houseId &&
        FirebaseAuth.instance.currentUser?.uid == ownerUid;
    setState(() => _uploadingRole = role);
    try {
      var xFile = await StoragePickerService().pickImage(preserveOriginal: true);
      if (xFile == null || !mounted || !isCurrent()) return;
      xFile = await cropAndConfirmImage(
        context: context,
        image: xFile,
        aspectRatio: 1,
        circular: true,
        maxOutputSize: const Size(1080, 1080),
        titleKey: 'home_chnhavatar_d974c0',
        isScopeCurrent: isCurrent,
      );
      if (xFile == null || !isCurrent()) return;
      final currentHouseId = await HouseService().getCurrentHouseId(
        preferFresh: true,
      );
      if (!isCurrent() || currentHouseId != houseId) return;
      final oldAvatarUrl = (role == 'user1' ? _avatarU1 : _avatarU2)?.trim() ?? '';
      final upload = await StorageService.instance.uploadPublicImage(
        houseId,
        'home_avatar',
        xFile,
        role: role,
        quality: 84,
        minWidth: 512,
        minHeight: 512,
      );
      if (!mounted || !isCurrent()) return;
      final url = upload?.downloadUrl.trim() ?? '';
      if (url.isEmpty) throw StateError('Avatar finalize not confirmed');
      await discardConfirmedCropImage(xFile);
      if (!isCurrent()) return;
      if (oldAvatarUrl.isNotEmpty && oldAvatarUrl != url) {
        await StorageService.instance.deletePublicImageByUrl(houseId, oldAvatarUrl);
      }
      if (!mounted || !isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            _t(
              role == 'user1'
                  ? 'home_cpnhtavata_af1e5c'
                  : 'home_cpnhtavata_182b34',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted || !isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            AppErrorMapper.resolve(
              error,
              fallbackMessage: _t('pairing_ui_avatar_upload_error'),
            ).message,
          ),
        ),
      );
    } finally {
      if (isCurrent()) setState(() => _uploadingRole = null);
    }
  }

  Widget _buildActionRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color color = SLSettingsColors.rose,
  }) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$title. $subtitle',
      onTap: onTap,
      child: SLSettingsRow(
        icon: icon,
        iconColor: color,
        title: title,
        subtitle: subtitle,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
        onTap: onTap,
      ),
    );
  }

  /// Mã đúng giờ được tự chấp nhận, nên mục này chỉ hiện khi còn yêu cầu cũ
  /// đang chờ duyệt (tạo trước khi server cập nhật) hoặc khi không tải được.
  Widget _buildRequestsList() {
    if (_incomingRequestsStream == null) return const SizedBox.shrink();

    return StreamBuilder<List<PairingRequest>>(
      stream: _incomingRequestsStream,
      builder: (context, snapshot) {
        final Widget body;
        if (snapshot.hasError) {
          body = SLSettingsNotice(
            tone: SLSettingsTone.danger,
            icon: Icons.cloud_off_outlined,
            message: _t('pairing_ui_requests_error'),
          );
        } else {
          final requests = (snapshot.data ?? const <PairingRequest>[])
              .where((r) => r.status == 'pending')
              .toList();
          if (requests.isEmpty) return const SizedBox.shrink();
          body = Column(
            children: requests.map((r) => _buildRequestTile(r)).toList(),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _t('pairing_ui_dashboard_requests_title').toUpperCase(),
                style: SLSettingsText.sectionLabel(
                  SLSettingsColors.inkTertiary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            body,
          ],
        );
      },
    );
  }

  Widget _buildRequestTile(PairingRequest request) {
    final isResponding = _respondingRequestId == request.requestId;
    final hasActiveResponse = _respondingRequestId != null;
    return SLSettingsCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SLSettingsColors.accentSoft,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: SLSettingsColors.accentSoft,
                      child: request.guestAvatar.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: request.guestAvatar,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                memCacheWidth: 300,
                                memCacheHeight: 300,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: SLSettingsColors.accent,
                              size: 30,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.guestName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: SLSettingsColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (request.guestEmail.isNotEmpty) ...[
                      Text(
                        request.guestEmail,
                        style: SLSettingsText.caption(
                          SLSettingsColors.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ] else
                      const SizedBox(height: 5),
                    SLSettingsPill(
                      label: _t('pairing_ui_request_from'),
                      tone: SLSettingsTone.accent,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SLSettingsButton(
                  label: _t('pairing_ui_request_reject'),
                  variant: SLSettingsButtonVariant.secondary,
                  onPressed: isResponding || hasActiveResponse
                      ? null
                      : () => _respondToRequest(request, accept: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SLSettingsButton(
                  label: _t('pairing_ui_request_accept'),
                  loading: isResponding,
                  onPressed: isResponding || hasActiveResponse
                      ? null
                      : () => _respondToRequest(request, accept: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
