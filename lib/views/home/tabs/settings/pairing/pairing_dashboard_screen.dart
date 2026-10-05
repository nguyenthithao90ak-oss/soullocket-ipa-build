import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_settings_kit.dart';
import 'package:soullocket_app/widgets/getting_started_guide.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/utils/services/role_utils.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_create_code_sheet.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_enter_code_sheet.dart';
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
    super.dispose();
  }

  Future<void> _loadHouseId() async {
    final generation = ++_loadGeneration;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _scopeUid = uid;
    _loadTimer?.cancel();
    _dateTimer?.cancel();
    unawaited(_settingsSub?.cancel());
    unawaited(_membersSub?.cancel());
    unawaited(_connectionDateSub?.cancel());
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

    _loadTimer = Timer(const Duration(seconds: 8), () {
      handleLoadError(TimeoutException('Pairing state unavailable'));
    });
    String? houseId;
    try {
      houseId = await HouseService().getCurrentHouseId(preferFresh: true);
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
    _incomingRequestsStream = PairingService.instance.listenToIncomingRequests(
      houseId,
    );

    // Đây là màn đọc trạng thái. Không tự ghi isPaired hay sửa chế độ ghép nối.
    _settingsSub = FirebaseDatabase.instance
        .ref('houses/$houseId/settings')
        .onValue
        .listen((event) {
          if (!isCurrent()) return;
          final value = event.snapshot.value;
          final settings = value is Map ? value : const {};
          setState(() {
            _settingsReceived = true;
            _settingsPaired = settings['isPaired'] == true;
            _nameU1 = settings['nameU1']?.toString();
            _nameU2 = settings['nameU2']?.toString();
            _genderSwapped = RoleUtils.readGenderSwapped(settings);
            _avatarU1 = pairingAvatarUrl(settings, 'user1');
            _avatarU2 = pairingAvatarUrl(settings, 'user2');
          });
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
            _membersReceived = true;
            _membersPaired = members.length >= 2;
            _members = members;
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: PairingCreateCodeSheet(myHouseId: _myHouseId!),
      ),
    );
  }

  void _showEnterCodeSheet() async {
    if (_isPaired || _isLoading || _loadError) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
            const SizedBox(height: 26),
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
      final xFile = await StoragePickerService().pickImage();
      if (xFile == null || !isCurrent()) return;
      final currentHouseId = await HouseService().getCurrentHouseId(
        preferFresh: true,
      );
      if (!isCurrent() || currentHouseId != houseId) return;
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
      setState(() {
        if (role == 'user1') {
          _avatarU1 = url;
        } else {
          _avatarU2 = url;
        }
      });
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

  Widget _buildRequestsList() {
    if (_incomingRequestsStream == null) return _buildEmptyRequestsView();

    return StreamBuilder<List<PairingRequest>>(
      stream: _incomingRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SLSettingsNotice(
            tone: SLSettingsTone.danger,
            icon: Icons.cloud_off_outlined,
            message: _t('pairing_ui_requests_error'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyRequestsView();
        }

        final requests = snapshot.data!
            .where((r) => r.status == 'pending')
            .toList();

        if (requests.isEmpty) {
          return _buildEmptyRequestsView();
        }

        return Column(
          children: requests.map((r) => _buildRequestTile(r)).toList(),
        );
      },
    );
  }

  Widget _buildEmptyRequestsView() {
    return SLSettingsNotice(
      tone: SLSettingsTone.neutral,
      icon: Icons.mark_email_read_outlined,
      message: _t('pairing_ui_requests_empty_title'),
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
