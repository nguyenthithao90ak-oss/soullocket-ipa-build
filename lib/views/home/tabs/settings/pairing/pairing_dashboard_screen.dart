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
  bool _hasCheckedMembers = false;
  StreamSubscription? _settingsSub;
  Stream<List<PairingRequest>>? _incomingRequestsStream;
  Timer? _guideTimer;

  @override
  void initState() {
    super.initState();
    _loadHouseId();
    _startGuideTimer();
  }

  void _startGuideTimer() {
    _guideTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isPaired) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.help_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bạn cần ghép nối nhưng không biết cách?\nHãy ấn vào nút [?] ở góc trái nhé!',
                    style: SLTheme.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.4),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFD81B60),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'XEM',
              textColor: Colors.white,
              onPressed: _showDetailedGuide,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _guideTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHouseId() async {
    final houseId = await HouseService().getCurrentHouseId();
    if (houseId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _myHouseId = houseId;
        _incomingRequestsStream ??=
            PairingService.instance.listenToIncomingRequests(houseId);
      });
    }

    // Safety fallback: Tắt loading sau 5s nếu mạng quá yếu hoặc không load được
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    });

    // Tối ưu hóa: Đọc createdAt một lần duy nhất
    unawaited(() async {
      try {
        final rawDateSnap = await FirebaseDatabase.instance
            .ref('houses/$houseId/createdAt')
            .get();
        if (rawDateSnap.exists && rawDateSnap.value != null) {
          final val = rawDateSnap.value;
          final ms = val is num
              ? val.toInt()
              : (double.tryParse(val.toString())?.toInt() ??
                  int.tryParse(val.toString()) ??
                  0);
          final startDate = DateTime.fromMillisecondsSinceEpoch(ms);
          if (mounted) {
            setState(() {
              _startDateStr =
                  '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}';
            });
          }
        }
      } catch (_) {}
    }());

    _settingsSub?.cancel();
    _settingsSub = FirebaseDatabase.instance
        .ref('houses/$houseId/settings')
        .onValue
        .listen((event) async {
      final snap = event.snapshot;
      if (!snap.exists || snap.value == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final settings = Map<String, dynamic>.from(snap.value as Map);
      bool isPaired = settings['isPaired'] == true;

      // Check real members count to guarantee paired status (chỉ đọc members một lần duy nhất nếu chưa paired)
      if (!isPaired && !_hasCheckedMembers) {
        _hasCheckedMembers = true;
        try {
          final membersSnap = await FirebaseDatabase.instance
              .ref('houses/$houseId/members')
              .get();
          if (membersSnap.exists && membersSnap.value is Map) {
            final membersMap = membersSnap.value as Map;
            if (membersMap.length >= 2) {
              isPaired = true;
              // Background update
              unawaited(FirebaseDatabase.instance
                  .ref('houses/$houseId/settings/isPaired')
                  .set(true));
              unawaited(FirebaseDatabase.instance
                  .ref('houses/$houseId/settings/relationshipMode')
                  .set('couple'));
              try {
                unawaited(FirebaseDatabase.instance
                    .ref('single_match_active_pool/$houseId')
                    .remove());
                unawaited(FirebaseDatabase.instance
                    .ref('houses/$houseId/settings/singleMatch/enabled')
                    .set(false));
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        if (!_isPaired && isPaired && !_isLoading) {
          _showCongratulationDialog();
        }

        setState(() {
          _isPaired = isPaired;
          _isLoading = false;
          _nameU1 = settings['nameU1']?.toString() ??
              L10nService().translate('role_male');
          _nameU2 = settings['nameU2']?.toString() ??
              L10nService().translate('role_female');
          _avatarU1 = settings['avatarU1']?.toString();
          _avatarU2 = settings['avatarU2']?.toString();

          final rawDate = settings['createdAt'];
          if (rawDate != null && _startDateStr == null) {
            try {
              final ms = rawDate is num
                  ? rawDate.toInt()
                  : (double.tryParse(rawDate.toString())?.toInt() ??
                      int.tryParse(rawDate.toString()) ??
                      0);
              final startDate = DateTime.fromMillisecondsSinceEpoch(ms);
              _startDateStr =
                  '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}';
            } catch (_) {}
          }

          if (_startDateStr == null || _startDateStr!.isEmpty) {
            final startDateVal = settings['startDate']?.toString();
            if (startDateVal != null && startDateVal.isNotEmpty) {
              try {
                final parsed = DateTime.parse(startDateVal);
                _startDateStr =
                    '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
              } catch (_) {}
            }
          }
        });
      }
    });

    // Đã xoá logic đếm nhật ký ở đây
  }

  void _showCreateCodeSheet() {
    if (_myHouseId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: PairingCreateCodeSheet(myHouseId: _myHouseId!),
      ),
    );
  }

  void _showEnterCodeSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PairingEnterCodeSheet(),
    );
    // Reload if merged
    _loadHouseId();
  }

  void _showCongratulationDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
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
                  )
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
                    child: const Icon(Icons.favorite_rounded,
                        color: Color(0xFFD81B60), size: 64),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chúc Mừng!',
                    style: SLTheme.quicksand(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD81B60),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hai bạn đã ghép nối thành công.\nHãy cùng nhau lưu giữ những khoảnh khắc tuyệt vời nhé!',
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
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Tuyệt vời',
                      style: SLTheme.quicksand(
                          fontSize: 16, fontWeight: FontWeight.w800),
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
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text(
              'Hướng dẫn ghép nối',
              style: SLTheme.quicksand(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2C1B22),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                children: [
                  _buildGuideStep(
                    icon: Icons.person_add_alt_1_rounded,
                    title: '1. Bạn chưa có nhà chung?',
                    content:
                        'Hãy chọn "Tạo mã ghép nối" để tạo một mã gồm 12 số. Sau đó, sao chép mã này và gửi cho người ấy qua tin nhắn (Zalo, Messenger, v.v.).',
                  ),
                  _buildGuideStep(
                    icon: Icons.login_rounded,
                    title: '2. Người ấy cần làm gì?',
                    content:
                        'Người ấy mở ứng dụng, vào phần "Ghép nối", chọn "Nhập mã ghép nối" và dán mã 12 số mà bạn vừa gửi để xin ghép.',
                  ),
                  _buildGuideStep(
                    icon: Icons.check_circle_outline_rounded,
                    title: '3. Phê duyệt yêu cầu',
                    content:
                        'Sau khi người ấy nhập mã, màn hình của bạn (ở mục "Yêu cầu đang chờ duyệt") sẽ hiện lên yêu cầu của họ. Bạn chỉ cần bấm "Chấp nhận"!',
                  ),
                  _buildGuideStep(
                    icon: Icons.favorite_rounded,
                    title: '4. Tận hưởng không gian riêng',
                    content:
                        'Sau khi ghép nối thành công, cả hai có thể cùng viết nhật ký, chia sẻ kỷ niệm, và sử dụng đầy đủ các tính năng dành cho cặp đôi.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(context.tr('ĐÃ HIỂU'),
                    style: SLTheme.quicksand(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(
      {required IconData icon,
      required String title,
      required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFFD81B60), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2C1B22)),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      height: 1.5),
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
      backgroundColor: const Color(0xFFFFF5F8),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              L10nService().translate('settings_partner_connect'),
              style: SLTheme.quicksand(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2C1B22),
              ),
            ),
            const SizedBox(width: 6),
            const Text('💖', style: TextStyle(fontSize: 16)),
          ],
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8FB1).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: const Color(0xFFFFD1DC), width: 1.5),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFFD81B60), size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _isPaired
          ? null
          : Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFD81B60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD81B60).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _showDetailedGuide,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        'Hướng dẫn',
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF0F5),
                    Color(0xFFFFF8FA),
                    Color(0xFFF4F6FF),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFB6C1).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE6E6FA).withValues(alpha: 0.25),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD81B60)))
                : _isPaired
                    ? _buildPairedState()
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        children: [
                          _buildActionCard(
                            title: 'Tạo mã ghép nối',
                            subtitle: 'Tạo mã gồm 12 số để gửi cho người ấy.',
                            badgeText: 'Gửi mã 💌',
                            icon: Icons.qr_code_2_rounded,
                            gradientColors: const [
                              Color(0xFFFF758C),
                              Color(0xFFFF7EB3)
                            ],
                            borderColor: const Color(0xFFFFD1DC),
                            shadowColor: const Color(0xFFFF758C),
                            onTap: _showCreateCodeSheet,
                          ),
                          SLSpacing.h16,
                          _buildActionCard(
                            title: 'Nhập mã ghép nối',
                            subtitle:
                                'Nhập mã do người ấy tạo để xin vào nhà chung.',
                            badgeText: 'Vào nhà 🏡',
                            icon: Icons.mark_email_read_rounded,
                            gradientColors: const [
                              Color(0xFF42A5F5),
                              Color(0xFF26C6DA)
                            ],
                            borderColor: const Color(0xFFB3E5FC),
                            shadowColor: const Color(0xFF42A5F5),
                            onTap: _showEnterCodeSheet,
                          ),
                          SLSpacing.h24,
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFFFD1DC),
                                      width: 1.5),
                                ),
                                child: const Icon(Icons.favorite_rounded,
                                    size: 14, color: Color(0xFFD81B60)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'YÊU CẦU ĐANG CHỜ DUYỆT',
                                style: SLTheme.quicksand(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFD81B60),
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const Spacer(),
                              const Text('✨', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                          SLSpacing.h12,
                          _buildRequestsList(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairedState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF0F5),
            const Color(0xFFFFC0CB).withValues(alpha: 0.5),
            const Color(0xFFE6E6FA).withValues(alpha: 0.8),
            const Color(0xFFF0FFFF),
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatarWidget(_avatarU1,
                  _nameU1 ?? L10nService().translate('role_male'), 'user1'),
              const SizedBox(width: 16),
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFD81B60).withValues(alpha: 0.2),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: Color(0xFFD81B60), size: 36),
                    ),
                    const Positioned(
                        top: -5,
                        left: -5,
                        child: Text('✨', style: TextStyle(fontSize: 20))),
                    const Positioned(
                        bottom: 5,
                        right: -10,
                        child: Text('🎀', style: TextStyle(fontSize: 18))),
                    const Positioned(
                        top: 10,
                        right: -15,
                        child: Text('💖', style: TextStyle(fontSize: 16))),
                    const Positioned(
                        bottom: -5,
                        left: 10,
                        child: Text('🌸', style: TextStyle(fontSize: 18))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildAvatarWidget(_avatarU2,
                  _nameU2 ?? L10nService().translate('role_female'), 'user2'),
            ],
          ),
          const SizedBox(height: 40),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD81B60).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  L10nService().translate('pairing_start_date'),
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                SLSpacing.h8,
                Text(
                  _startDateStr ?? L10nService().translate('pairing_no_info'),
                  style: SLTheme.quicksand(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                width: 96,
                height: 96,
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
                          width: 88,
                          height: 88,
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 40),
                            errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 40),
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
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
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

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: SLTheme.quicksand(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2C1B22),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gradientColors.first.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText,
                          style: SLTheme.quicksand(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: gradientColors.first,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: gradientColors.first.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right_rounded,
                  color: gradientColors.first, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_incomingRequestsStream == null) return const SizedBox.shrink();

    return StreamBuilder<List<PairingRequest>>(
      stream: _incomingRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF5350)),
            ),
            child: Text(
              'Lỗi kết nối máy chủ: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                  color: const Color(0xFFC62828),
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyRequestsView();
        }

        final requests =
            snapshot.data!.where((r) => r.status == 'pending').toList();

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
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD1DC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8FB1).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0F5), Color(0xFFFFE4E1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFFFD1DC), width: 1.5),
                ),
                child: const Center(
                  child: Text('💌', style: TextStyle(fontSize: 32)),
                ),
              ),
              const Positioned(
                top: -2,
                right: -2,
                child: Text('✨', style: TextStyle(fontSize: 16)),
              ),
              const Positioned(
                bottom: 0,
                left: -2,
                child: Text('🌸', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có yêu cầu nào 💕',
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2C1B22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Khi người ấy nhập mã ghép nối của bạn, yêu cầu sẽ xuất hiện ngay tại đây để bạn duyệt nhé!',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(PairingRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD1DC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                          color: const Color(0xFFFF8FB1), width: 2),
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
                              ),
                            )
                          : const Icon(Icons.person_rounded,
                              color: Color(0xFFD81B60), size: 30),
                    ),
                  ),
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: Text('💖', style: TextStyle(fontSize: 14)),
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
                        'Email: ${request.guestEmail}',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      'UID: ${request.requestId}',
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đã gửi yêu cầu ghép nối 💌',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD81B60),
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
                child: InkWell(
                  onTap: () =>
                      PairingService.instance.rejectRequest(request.requestId),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Từ chối',
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      PairingService.instance.acceptRequest(request.requestId),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFD81B60)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD81B60).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '💖 Chấp nhận',
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
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
