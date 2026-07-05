import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/pairing_service.dart';
import 'package:soullocket_app/utils/services/role_utils.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_create_code_sheet.dart';
import 'package:soullocket_app/views/home/tabs/settings/pairing/pairing_enter_code_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/core/constants/app_firebase_paths.dart';

class PairingDashboardScreen extends StatefulWidget {
  const PairingDashboardScreen({super.key});

  @override
  State<PairingDashboardScreen> createState() => _PairingDashboardScreenState();
}

class _PairingDashboardScreenState extends State<PairingDashboardScreen> {
  String? _myHouseId;
  bool _isPaired = false;
  String? _partnerName;
  bool _isLoading = true;
  StreamSubscription? _settingsSub;

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
      });
    }

    _settingsSub?.cancel();
    _settingsSub = FirebaseDatabase.instance
        .ref(AppFirebasePaths.houseSettings(houseId))
        .onValue
        .listen((event) async {
      final snap = event.snapshot;
      if (!snap.exists) return;
      final settings = Map<String, dynamic>.from(snap.value as Map);

      // Trong mô hình Shared Account, chỉ cần có houseId là xem như đã ghép nối.
      bool isPaired = true;
      String? pName;

      if (isPaired) {
        final myRole = await RoleUtils.currentRole();
        pName = myRole == 'user1' ? settings['nameU2'] : settings['nameU1'];
      }

      if (mounted) {
        setState(() {
          _isPaired = isPaired;
          _partnerName = pName ?? 'Người ấy';
          _isLoading = false;
        });
      }
    });
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
          'Ghép Nối Tổ Ấm',
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD81B60).withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: const Icon(Icons.favorite_rounded, color: Color(0xFFD81B60), size: 64),
          ),
          SLSpacing.h32,
          Text(
            'Đang ghép nối với',
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          SLSpacing.h8,
          Text(
            _partnerName ?? 'Người ấy',
            style: SLTheme.quicksand(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
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
              color: color.withOpacity(0.1),
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
                color: color.withOpacity(0.1),
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
    return StreamBuilder<List<PairingRequest>>(
      stream: PairingService.instance.listenToIncomingRequests(_myHouseId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    'Không có yêu cầu nào',
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final requests = snapshot.data!.where((r) => r.status == 'pending').toList();

        if (requests.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    'Không có yêu cầu nào',
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: requests.map((r) => _buildRequestTile(r)).toList(),
        );
      },
    );
  }

  Widget _buildRequestTile(PairingRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            child: request.guestAvatar.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: request.guestAvatar,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.person, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.guestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2C1B22),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Muốn ghép nối với bạn',
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => PairingService.instance.rejectRequest(request.requestId),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50)),
                onPressed: () => PairingService.instance.acceptRequest(request.requestId),
              ),
            ],
          )
        ],
      ),
    );
  }
}
