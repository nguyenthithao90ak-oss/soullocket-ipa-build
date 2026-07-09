import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_create_code_sheet.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_enter_code_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soullocket_app/core/constants/app_firebase_paths.dart';
import 'package:soullocket_app/utils/services/storage_picker_service.dart';
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
  int _diaryCount = 0;
  String? _avatarU1;
  String? _avatarU2;
  String? _nameU1;
  String? _nameU2;
  String? _startDateStr;
  bool _hasCheckedMembers = false;
  StreamSubscription? _settingsSub;
  Stream<List<PairingRequest>>? _incomingRequestsStream;

  @override
  void initState() {
    super.initState();
    _loadHouseId();
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
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
        _incomingRequestsStream ??= PairingService.instance.listenToIncomingRequests(houseId);
      });
    }

    _settingsSub?.cancel();
    _settingsSub = FirebaseDatabase.instance
        .ref('houses/$houseId')
        .onValue
        .listen((event) async {
      final snap = event.snapshot;
      if (!snap.exists) return;
      final houseData = Map<String, dynamic>.from(snap.value as Map);
      final settings = houseData['settings'] is Map
          ? Map<String, dynamic>.from(houseData['settings'] as Map)
          : {};

      bool isPaired = settings['isPaired'] == true;

      // Check real members count to guarantee paired status
      if (!isPaired && !_hasCheckedMembers) {
        _hasCheckedMembers = true;
        try {
          final membersSnap = houseData['members'];
          if (membersSnap is Map) {
            if (membersSnap.length >= 2) {
              isPaired = true;
              // Background update
              FirebaseDatabase.instance.ref('houses/$houseId/settings/isPaired').set(true);
              FirebaseDatabase.instance.ref('houses/$houseId/settings/relationshipMode').set('couple');
              try {
                FirebaseDatabase.instance.ref('single_match_active_pool/$houseId').remove();
                FirebaseDatabase.instance.ref('houses/$houseId/settings/singleMatch/enabled').set(false);
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isPaired = isPaired;
          _isLoading = false;
          _nameU1 = settings['nameU1']?.toString() ?? L10nService().translate('role_male');
          _nameU2 = settings['nameU2']?.toString() ?? L10nService().translate('role_female');
          _avatarU1 = settings['avatarU1']?.toString();
          _avatarU2 = settings['avatarU2']?.toString();
          
          final rawDate = houseData['createdAt'] ?? settings['createdAt'];
          if (rawDate != null) {
            try {
              final startDate = DateTime.fromMillisecondsSinceEpoch(int.parse(rawDate.toString()));
              _startDateStr = '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}';
            } catch (_) {}
          }
          
          if (_startDateStr == null || _startDateStr!.isEmpty) {
            final startDateVal = settings['startDate']?.toString();
            if (startDateVal != null && startDateVal.isNotEmpty) {
              try {
                final parsed = DateTime.parse(startDateVal);
                _startDateStr = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
              } catch (_) {}
            }
          }
        });
      }
    });

    // Chỉ đếm số lượng nhật ký (Firestore) 1 lần khi tải trang, không bỏ vào listener RTDB
    try {
      final countQuery = await FirebaseFirestore.instance
          .collection('houses')
          .doc(houseId)
          .collection('diaries')
          .count()
          .get();
      if (mounted) {
        setState(() {
          final count = countQuery.count ?? 0;
          _diaryCount = count >= 300 ? 300 : count;
        });
      }
    } catch (_) {}
  }

  void _showCreateCodeSheet() {
    if (_myHouseId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          L10nService().translate('settings_partner_connect'),
          style: SLTheme.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF2C1B22),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2C1B22), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isPaired
              ? _buildPairedState()
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildActionCard(
                      title: 'Tạo mã ghép nối',
                      subtitle: 'Tạo mã gồm 12 số để gửi cho người ấy.',
                      icon: Icons.qr_code_rounded,
                      color: const Color(0xFFD81B60),
                      onTap: _showCreateCodeSheet,
                    ),
                    SLSpacing.h16,
                    _buildActionCard(
                      title: 'Nhập mã ghép nối',
                      subtitle: 'Nhập mã do người ấy tạo để xin vào nhà chung.',
                      icon: Icons.keyboard_alt_outlined,
                      color: const Color(0xFF2196F3),
                      onTap: _showEnterCodeSheet,
                    ),
                    SLSpacing.h32,
                    Text(
                      'YÊU CẦU ĐANG CHỜ DUYỆT',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SLSpacing.h12,
                    _buildRequestsList(),
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
            const Color(0xFFFFE4E1).withValues(alpha: 0.5),
            const Color(0xFFF0F8FF),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatarWidget(_avatarU1, _nameU1 ?? L10nService().translate('role_male'), 'user1'),
              const SizedBox(width: 16),
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: const [
                    Icon(Icons.favorite_rounded, color: Color(0xFFD81B60), size: 52),
                    Positioned(
                      top: -10,
                      left: -10,
                      child: Text('✨', style: TextStyle(fontSize: 22)),
                    ),
                    Positioned(
                      bottom: -5,
                      right: -10,
                      child: Text('🎀', style: TextStyle(fontSize: 20)),
                    ),
                    Positioned(
                      top: 5,
                      right: -15,
                      child: Text('💖', style: TextStyle(fontSize: 18)),
                    ),
                    Positioned(
                      bottom: -10,
                      left: 5,
                      child: Text('🌸', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildAvatarWidget(_avatarU2, _nameU2 ?? L10nService().translate('role_female'), 'user2'),
            ],
          ),
          SLSpacing.h32,
          Text(
            L10nService().translate('pairing_start_date'),
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600,
            ),
          ),
          SLSpacing.h8,
          Text(
            _startDateStr ?? L10nService().translate('pairing_no_info'),
            style: SLTheme.quicksand(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          SLSpacing.h16,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD81B60).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_rounded, color: Color(0xFFD81B60), size: 20),
                const SizedBox(width: 8),
                Text(
                  L10nService().format(
                    _diaryCount >= 300 
                        ? 'pairing_diary_count_more_than_300' 
                        : 'pairing_diary_count',
                    {'count': _diaryCount},
                  ),
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  color: Colors.grey.shade100,
                ),
                child: url != null && url.isNotEmpty
                    ? ClipOval(
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            memCacheHeight: 200,
                            placeholder: (context, url) => const Icon(Icons.person, color: Colors.grey, size: 40),
                            errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.grey, size: 40),
                          ),
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.grey, size: 40),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFD81B60), size: 16),
              ),
            ],
          ),
        SLSpacing.h8,
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 13,
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
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2C1B22),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
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
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyRequestsView();
        }

        final requests = snapshot.data!.where((r) => r.status == 'pending').toList();

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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0F2F5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mail_outline_rounded, size: 36, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có yêu cầu nào',
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2C1B22),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Các yêu cầu xin ghép nối sẽ hiển thị tại đây.',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(PairingRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFFFF0F5), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFE4E1), width: 2),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade100,
                  child: request.guestAvatar.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: request.guestAvatar,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            memCacheWidth: 150,
                            memCacheHeight: 150,
                          ),
                        )
                      : const Icon(Icons.person_rounded, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 2),
                    Text(
                      'Đã gửi yêu cầu ghép nối',
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
                  onTap: () => PairingService.instance.rejectRequest(request.requestId),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16),
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
                  onTap: () => PairingService.instance.acceptRequest(request.requestId),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8FB1), Color(0xFFD81B60)],
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
                      'Chấp nhận',
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
