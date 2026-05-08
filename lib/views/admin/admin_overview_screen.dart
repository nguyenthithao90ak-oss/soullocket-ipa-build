import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../services/auth_service.dart';
import 'widgets/admin_shared_widgets.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key, required this.user});

  final firebase_auth.User user;

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isMaintenanceMode = false;
  bool _isCommunityMaintenanceMode = false;
  int _totalHouses = 0;
  int _bannedHouses = 0;
  int _vipHouses = 0;
  int _totalReports = 0;
  int _totalFeeds = 0;
  int _totalSupportTickets = 0;
  int _unreadSupportTickets = 0;
  DateTime? _lastUpdatedAt;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        _db.child('houses').get(),
        _db.child('reports').get(),
        _db.child('social_feed').get(),
        _db.child('support_tickets').get(),
        _db.child(AppConfig.maintenanceModePath).get(),
        _db.child(AppConfig.communityMaintenanceModePath).get(),
      ]);

      final supportRaw = results[3].value;
      final supportMap = supportRaw is Map
          ? Map<dynamic, dynamic>.from(supportRaw)
          : <dynamic, dynamic>{};

      var totalTickets = 0;
      var unreadTickets = 0;
      supportMap.forEach((key, value) {
        if (key == 'general_chat' || value is! Map) {
          return;
        }
        totalTickets += 1;
        final item = Map<dynamic, dynamic>.from(value);
        unreadTickets += (item['unread_admin'] as num?)?.toInt() ?? 0;
      });

      var banned = 0;
      var vip = 0;
      final housesRaw = results[0].value;
      if (housesRaw is Map) {
        final nowTs = DateTime.now().millisecondsSinceEpoch;
        housesRaw.forEach((key, value) {
          if (value is Map) {
            if (value['isBanned'] == true) banned++;
            final proUntil =
                int.tryParse(value['proUntil']?.toString() ?? '0') ?? 0;
            if (proUntil > nowTs) vip++;
          }
        });
      }

      if (!mounted) return;
      setState(() {
        _totalHouses = results[0].children.length;
        _bannedHouses = banned;
        _vipHouses = vip;
        _totalReports = results[1].children.length;
        _totalFeeds = results[2].children.length;
        _totalSupportTickets = totalTickets;
        _unreadSupportTickets = unreadTickets;
        _isMaintenanceMode = results[4].value == true;
        _isCommunityMaintenanceMode = results[5].value == true;
        _lastUpdatedAt = DateTime.now();
        _errorText = null;
      });
    } catch (error) {
      debugPrint('Load admin overview failed: $error');
      if (!mounted) return;
      setState(() {
        _errorText = 'Chưa thể tải dữ liệu tổng quan lúc này.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _toggleMaintenance(bool value) async {
    try {
      await Future.wait([
        _db.child(AppConfig.maintenanceModePath).set(value),
        _db.child(AppConfig.legacyMaintenanceModePath).set(value),
      ]);
      if (!mounted) return;
      setState(() => _isMaintenanceMode = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Đã bật chế độ bảo trì toàn bộ.'
                : 'Đã tắt chế độ bảo trì toàn bộ.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Toggle maintenance failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể cập nhật trạng thái bảo trì lúc này.'),
        ),
      );
    }
  }

  Future<void> _toggleCommunityMaintenance(bool value) async {
    try {
      await _db.child(AppConfig.communityMaintenanceModePath).set(value);
      if (!mounted) return;
      setState(() => _isCommunityMaintenanceMode = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Đã bật bảo trì Cộng Đồng.' : 'Đã tắt bảo trì Cộng Đồng.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Toggle community maintenance failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể cập nhật bảo trì cộng đồng lúc này.'),
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        SLSpacing.w8,
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: SLSpacing.all24,
              child: Column(
                children: [
                  AdminTopBar(
                    user: widget.user,
                    isRefreshing: _isRefreshing,
                    lastUpdatedAt: _lastUpdatedAt,
                    onRefresh: () => _loadOverview(refresh: true),
                    onSignOut: _handleSignOut,
                  ),
                  SLSpacing.h24,
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isCompact =
                                        constraints.maxWidth < 880;
                                    return Flex(
                                      direction: isCompact
                                          ? Axis.vertical
                                          : Axis.horizontal,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          flex: 8,
                                          child: AdminGlassCard(
                                            padding: const EdgeInsets.all(28),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                sectionTag(
                                                    'Dashboard tổng quan'),
                                                SLSpacing.h12,
                                                Text(
                                                  'Theo dõi nhanh sức khỏe hệ thống admin',
                                                  style: SLTheme.quicksand(
                                                    color: Colors.white,
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SLSpacing.h12,
                                                Text(
                                                  'Hiển thị dữ liệu chính từ Firebase Realtime Database và trạng thái vận hành hiện tại.',
                                                  style: SLTheme.quicksand(
                                                    color:
                                                        const Color(0xFFB7C1D6),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.6,
                                                  ),
                                                ),
                                                SLSpacing.h24,
                                                if (_totalHouses > 0)
                                                  SizedBox(
                                                    height: 200,
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: PieChart(
                                                            PieChartData(
                                                              sectionsSpace: 0,
                                                              centerSpaceRadius:
                                                                  40,
                                                              sections: [
                                                                PieChartSectionData(
                                                                  color: Colors
                                                                      .amber,
                                                                  value: _vipHouses
                                                                      .toDouble(),
                                                                  title: 'PRO',
                                                                  radius: 30,
                                                                  titleStyle: const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .black),
                                                                ),
                                                                PieChartSectionData(
                                                                  color: Colors
                                                                      .red,
                                                                  value: _bannedHouses
                                                                      .toDouble(),
                                                                  title:
                                                                      'Banned',
                                                                  radius: 30,
                                                                  titleStyle: const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                PieChartSectionData(
                                                                  color: Colors
                                                                      .blue,
                                                                  value: (_totalHouses -
                                                                          _vipHouses -
                                                                          _bannedHouses)
                                                                      .toDouble(),
                                                                  title:
                                                                      'Thường',
                                                                  radius: 30,
                                                                  titleStyle: const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        SLSpacing.w16,
                                                        Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            _buildLegend(
                                                                Colors.amber,
                                                                'Nhà PRO ($_vipHouses)'),
                                                            SLSpacing.h8,
                                                            _buildLegend(
                                                                Colors.blue,
                                                                'Nhà Thường (${_totalHouses - _vipHouses - _bannedHouses})'),
                                                            SLSpacing.h8,
                                                            _buildLegend(
                                                                Colors.red,
                                                                'Đã khóa ($_bannedHouses)'),
                                                          ],
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: isCompact ? 0 : 24,
                                          height: isCompact ? 24 : 0,
                                        ),
                                        Expanded(
                                          flex: 5,
                                          child: AdminGlassCard(
                                            padding: SLSpacing.all24,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Trạng thái hệ thống',
                                                  style: SLTheme.quicksand(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SLSpacing.h16,
                                                Container(
                                                  padding: SLSpacing.all16,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF10182A),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFF28334F),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  _isMaintenanceMode
                                                                      ? 'Bảo trì toàn bộ (ĐANG BẬT)'
                                                                      : 'Bảo trì toàn bộ (ĐANG TẮT)',
                                                                  style: SLTheme
                                                                      .quicksand(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        15,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                  ),
                                                                ),
                                                                SLSpacing.h8,
                                                                Text(
                                                                  _isMaintenanceMode
                                                                      ? 'Người dùng thường sẽ bị chặn và đăng xuất.'
                                                                      : 'Hệ thống hoạt động bình thường.',
                                                                  style: SLTheme
                                                                      .quicksand(
                                                                    color: const Color(
                                                                        0xFF9AA8C4),
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Switch(
                                                            value:
                                                                _isMaintenanceMode,
                                                            activeThumbColor:
                                                                const Color(
                                                                    0xFFFF4B91),
                                                            onChanged:
                                                                _toggleMaintenance,
                                                          ),
                                                        ],
                                                      ),
                                                      SLSpacing.h16,
                                                      const Divider(
                                                          color: Color(
                                                              0xFF28334F)),
                                                      SLSpacing.h16,
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  _isCommunityMaintenanceMode
                                                                      ? 'Bảo trì Cộng Đồng (ĐANG BẬT)'
                                                                      : 'Bảo trì Cộng Đồng (ĐANG TẮT)',
                                                                  style: SLTheme
                                                                      .quicksand(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        15,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                  ),
                                                                ),
                                                                SLSpacing.h8,
                                                                Text(
                                                                  _isCommunityMaintenanceMode
                                                                      ? 'Tính năng Cộng Đồng bị chặn truy cập.'
                                                                      : 'Tính năng Cộng Đồng hoạt động bình thường.',
                                                                  style: SLTheme
                                                                      .quicksand(
                                                                    color: const Color(
                                                                        0xFF9AA8C4),
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Switch(
                                                            value:
                                                                _isCommunityMaintenanceMode,
                                                            activeThumbColor:
                                                                const Color(
                                                                    0xFFFF4B91),
                                                            onChanged:
                                                                _toggleCommunityMaintenance,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                if (_errorText != null) ...[
                                  SLSpacing.h24,
                                  AdminGlassCard(
                                    padding: SLSpacing.all16,
                                    child: Text(
                                      _errorText!,
                                      style: SLTheme.quicksand(
                                        color: const Color(0xFFFFC6D2),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                SLSpacing.h24,
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final compact = constraints.maxWidth < 980;
                                    final cardWidth = compact
                                        ? (constraints.maxWidth - 16) / 2
                                        : (constraints.maxWidth - 48) / 4;
                                    return Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        AdminStatCard(
                                          width: cardWidth,
                                          title: 'Tổng nhà',
                                          value: '$_totalHouses',
                                          subtitle: 'Bản ghi houses',
                                          color: const Color(0xFF4F8CFF),
                                          icon: Icons.home_work_rounded,
                                        ),
                                        AdminStatCard(
                                          width: cardWidth,
                                          title: 'Báo cáo',
                                          value: '$_totalReports',
                                          subtitle: 'Bản ghi reports',
                                          color: const Color(0xFFFF6B81),
                                          icon: Icons.report_problem_rounded,
                                        ),
                                        AdminStatCard(
                                          width: cardWidth,
                                          title: 'Bài viết',
                                          value: '$_totalFeeds',
                                          subtitle: 'Bản ghi social_feed',
                                          color: const Color(0xFF00C896),
                                          icon: Icons.dynamic_feed_rounded,
                                        ),
                                        AdminStatCard(
                                          width: cardWidth,
                                          title: 'Ticket support',
                                          value: '$_totalSupportTickets',
                                          subtitle:
                                              '$_unreadSupportTickets tin chưa đọc',
                                          color: const Color(0xFFB388FF),
                                          icon: Icons.support_agent_rounded,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                SLSpacing.h24,
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isCompact =
                                        constraints.maxWidth < 900;
                                    return Flex(
                                      direction: isCompact
                                          ? Axis.vertical
                                          : Axis.horizontal,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: AdminGlassCard(
                                            padding: SLSpacing.all24,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Nhanh gọn cho giai đoạn 1',
                                                  style: SLTheme.quicksand(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SLSpacing.h16,
                                                const OverviewListTile(
                                                  icon: Icons
                                                      .verified_user_rounded,
                                                  title: 'Đăng nhập admin',
                                                  subtitle:
                                                      'Xác thực bằng Firebase Auth và kiểm tra custom claim.',
                                                ),
                                                SLSpacing.h12,
                                                const OverviewListTile(
                                                  icon: Icons.insights_rounded,
                                                  title: 'Dashboard tổng quan',
                                                  subtitle:
                                                      'Hiển thị houses, reports, feed và support tickets.',
                                                ),
                                                SLSpacing.h12,
                                                const OverviewListTile(
                                                  icon: Icons.toggle_on_rounded,
                                                  title:
                                                      'Maintenance ngay trên dashboard',
                                                  subtitle:
                                                      'Bật tắt nhanh trạng thái bảo trì hệ thống.',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: isCompact ? 0 : 24,
                                          height: isCompact ? 24 : 0,
                                        ),
                                        Expanded(
                                          child: AdminGlassCard(
                                            padding: SLSpacing.all24,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Phiên đăng nhập',
                                                  style: SLTheme.quicksand(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SLSpacing.h16,
                                                MetaRow(
                                                  label: 'UID',
                                                  value: widget.user.uid,
                                                ),
                                                SLSpacing.h12,
                                                MetaRow(
                                                  label: 'Email',
                                                  value: widget.user.email ??
                                                      'Chưa có email',
                                                ),
                                                SLSpacing.h12,
                                                const MetaRow(
                                                  label: 'Claim',
                                                  value: 'admin / super_admin',
                                                ),
                                                SLSpacing.h12,
                                                MetaRow(
                                                  label: 'Cập nhật',
                                                  value: _lastUpdatedAt == null
                                                      ? 'Chưa tải dữ liệu'
                                                      : formatDateTime(
                                                          _lastUpdatedAt!),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
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
}
