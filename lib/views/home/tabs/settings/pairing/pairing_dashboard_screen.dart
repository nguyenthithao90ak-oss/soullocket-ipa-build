import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_create_code_sheet.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_enter_code_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

import 'package:soullocket_app/core/constants/app_firebase_paths.dart';
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
  String? _startDateStr;
  bool _settingsReceived = false;
  bool _membersReceived = false;
  bool _settingsPaired = false;
  bool _membersPaired = false;
  bool _hasResolvedPairing = false;
  bool _loadError = false;
  int _loadGeneration = 0;
  Timer? _loadTimer;
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
  }

  @override
  void dispose() {
    _loadGeneration++;
    _loadTimer?.cancel();
    _settingsSub?.cancel();
    _membersSub?.cancel();
    _connectionDateSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHouseId() async {
    final generation = ++_loadGeneration;
    _loadTimer?.cancel();
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
      _startDateStr = null;
      _myHouseId = null;
      _nameU1 = null;
      _nameU2 = null;
      _avatarU1 = null;
      _avatarU2 = null;
      _incomingRequestsStream = null;
    });
    bool isCurrent() => mounted && generation == _loadGeneration;
    void handleLoadError(Object error) {
      if (!isCurrent() || _hasResolvedPairing) return;
      setState(() {
        _isLoading = false;
        _loadError = true;
      });
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
            _avatarU1 = settings['avatarU1']?.toString();
            _avatarU2 = settings['avatarU2']?.toString();
          });
          _applyPairingStatus();
        }, onError: handleLoadError);

    // Theo dõi thành viên liên tục để trạng thái không bị lùi về chưa ghép
    // khi settings được cập nhật nhưng cờ isPaired ở dữ liệu cũ còn thiếu.
    _membersSub = FirebaseDatabase.instance
        .ref('houses/$houseId/members')
        .onValue
        .listen((event) {
          if (!isCurrent()) return;
          final value = event.snapshot.value;
          final members = value is Map ? value : const {};
          _membersReceived = true;
          _membersPaired = members.length >= 2;
          _applyPairingStatus();
        }, onError: handleLoadError);

    _connectionDateSub = FirebaseDatabase.instance
        .ref('houses/$houseId/coupleConnectedAt')
        .onValue
        .listen(
          (event) {
            if (!isCurrent()) return;
            final date = parsePairingConnectionDate(event.snapshot.value);
            setState(() {
              _startDateStr = date == null
                  ? null
                  : '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}/${date.year}';
            });
          },
          onError: (Object error) {
            if (isCurrent()) setState(() => _startDateStr = null);
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
        SnackBar(
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD81B60).withValues(alpha: 0.2),
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFD81B60),
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _t('pairing_ui_congrats_title'),
                    style: SLTheme.quicksand(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD81B60),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('pairing_ui_congrats_body'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD81B60),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _t('pairing_ui_congrats_action'),
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCFA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SLColors.ink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              _t('pairing_ui_guide_title'),
              style: SLTheme.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: SLColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
                children: [
                  _buildGuideStep(
                    icon: Icons.person_add_alt_1_rounded,
                    title: _t('pairing_ui_guide_step_1_title'),
                    content: _t('pairing_ui_guide_step_1_body'),
                  ),
                  _buildGuideStep(
                    icon: Icons.login_rounded,
                    title: _t('pairing_ui_guide_step_2_title'),
                    content: _t('pairing_ui_guide_step_2_body'),
                  ),
                  _buildGuideStep(
                    icon: Icons.check_circle_outline_rounded,
                    title: _t('pairing_ui_guide_step_3_title'),
                    content: _t('pairing_ui_guide_step_3_body'),
                  ),
                  _buildGuideStep(
                    icon: Icons.favorite_rounded,
                    title: _t('pairing_ui_guide_step_4_title'),
                    content: _t('pairing_ui_guide_step_4_body'),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF0E7E2))),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A333D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(
                  _t('pairing_ui_guide_done'),
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9ED),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: SLColors.primary, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SLColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: SLColors.textSecond,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFAF9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _t('pairing_ui_dashboard_nav_title'),
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SLColors.ink,
          ),
        ),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: SLColors.ink,
            size: 19,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading && !_loadError && !_isPaired)
            IconButton(
              tooltip: _t('pairing_ui_dashboard_help'),
              icon: const Icon(
                Icons.help_outline_rounded,
                color: SLColors.textSecond,
                size: 22,
              ),
              onPressed: _showDetailedGuide,
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFFCFAF9)),
        child: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: SLColors.primary),
                )
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
            const Icon(Icons.cloud_off_outlined, color: SLColors.textSecond),
            const SizedBox(height: 16),
            Text(
              _t('pairing_ui_state_load_error'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(color: SLColors.textSecond, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadHouseId,
              child: Text(_t('pairing_ui_state_retry')),
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
            Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFEEE5E4)),
              ),
              child: Column(
                children: [
                  _buildActionRow(
                    title: _t('pairing_ui_dashboard_create_action'),
                    subtitle: _t('pairing_ui_dashboard_create_subtitle'),
                    icon: Icons.add_link_rounded,
                    onTap: _showCreateCodeSheet,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 74, right: 16),
                    child: Divider(height: 1, color: Color(0xFFF1EBE9)),
                  ),
                  _buildActionRow(
                    title: _t('pairing_ui_dashboard_enter_action'),
                    subtitle: _t('pairing_ui_dashboard_enter_subtitle'),
                    icon: Icons.qr_code_scanner_rounded,
                    onTap: _showEnterCodeSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildSecurityNote(),
            const SizedBox(height: 32),
            Row(
              children: [
                Text(
                  _t('pairing_ui_dashboard_requests_title'),
                  style: SLTheme.quicksand(
                    color: SLColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Divider(height: 1, color: Color(0xFFECE3E1)),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                      color: const Color(0xFFFBE8EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF4D9DF)),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFFAD516B),
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
                      color: const Color(0xFFF3ECE7),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE8DDD5)),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF947568),
                      size: 27,
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFCFAF9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFC5637C),
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
            color: SLColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Text(
            _t('pairing_ui_dashboard_subtitle'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: SLColors.textSecond,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
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
          color: Color(0xFF927C82),
          size: 14,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _t('pairing_ui_dashboard_security_short'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: SLColors.textSecond,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPairedState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildAvatarWidget(
                          _avatarU1,
                          _nameU1 ?? _t('role_male'),
                          'user1',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 24, 8, 0),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFB9516D),
                          size: 28,
                        ),
                      ),
                      Expanded(
                        child: _buildAvatarWidget(
                          _avatarU2,
                          _nameU2 ?? _t('role_female'),
                          'user2',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEEE5E4)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _t('pairing_start_date'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SLColors.textSecond,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _startDateStr ?? _t('pairing_no_info'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: _startDateStr == null ? 16 : 26,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB9516D),
                          ),
                        ),
                      ],
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

  Future<void> _updateAvatar(String role) async {
    if (_myHouseId == null) return;
    final picker = StoragePickerService();
    final xFile = await picker.pickImage();
    if (xFile == null) return;

    if (mounted) setState(() => _isLoading = true);
    try {
      final url = await StorageService.instance.uploadImage(
        _myHouseId!,
        'avatars',
        xFile,
      );
      if (url != null) {
        final key = role == 'user1' ? 'avatarU1' : 'avatarU2';
        await FirebaseDatabase.instance
            .ref(AppFirebasePaths.houseSettings(_myHouseId!))
            .child(key)
            .set(url);
      }
    } catch (e) {
      debugPrint('Upload avatar error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAvatarWidget(String? url, String label, String role) {
    return GestureDetector(
      onTap: () => _updateAvatar(role),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  color: Colors.grey.shade100,
                ),
                child: url != null && url.isNotEmpty
                    ? ClipOval(
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            memCacheHeight: 300,
                            placeholder: (context, url) => const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 40,
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.grey, size: 40),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD81B60),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2C1B22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$title. $subtitle',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEDF0),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFFB9516D), size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SLColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: SLColors.textSecond,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFAE969E),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_incomingRequestsStream == null) return _buildEmptyRequestsView();

    return StreamBuilder<List<PairingRequest>>(
      stream: _incomingRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SLColors.dangerLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: SLColors.danger.withValues(alpha: 0.32),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 19,
                  color: SLColors.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t('pairing_ui_requests_error'),
                    style: SLTheme.quicksand(
                      color: const Color(0xFF9A344C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFDFC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: SLColors.textSecond,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              _t('pairing_ui_requests_empty_title'),
              style: SLTheme.quicksand(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: SLColors.textSecond,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(PairingRequest request) {
    final isResponding = _respondingRequestId == request.requestId;
    final hasActiveResponse = _respondingRequestId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SLColors.paper,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE8CBD4)),
        boxShadow: [
          BoxShadow(
            color: SLColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
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
                        color: const Color(0xFFEAB4C1),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.pink.shade50,
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
                              color: Color(0xFFD81B60),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2C1B22),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (request.guestEmail.isNotEmpty) ...[
                      Text(
                        request.guestEmail,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SLColors.textSecond,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ] else
                      const SizedBox(height: 5),
                    Text(
                      _t('pairing_ui_request_from'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: SLColors.primary,
                      ),
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
                child: OutlinedButton(
                  onPressed: isResponding || hasActiveResponse
                      ? null
                      : () => _respondToRequest(request, accept: false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: SLColors.textSecond,
                    side: const BorderSide(color: SLColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    _t('pairing_ui_request_reject'),
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isResponding || hasActiveResponse
                      ? null
                      : () => _respondToRequest(request, accept: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: SLColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: isResponding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _t('pairing_ui_request_accept'),
                          style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
