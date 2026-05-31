import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/app_error_mapper.dart';
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
      debugPrint('Load admin overview failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('admin_chathtidli_78f16e'),
      ).message}');
      if (!mounted) return;
      setState(() {
        _errorText = context.tr('admin_chathtidli_78f16e');
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
                ? context.tr('admin_btchbotrto_981636')
                : context.tr('admin_ttchbotrto_4c7512'),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Toggle maintenance failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('admin_chathcpnht_68b279'),
      ).message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('admin_chathcpnht_68b279')),
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
            value ? context.tr('admin_btbotrcngn_270bad') : context.tr('admin_ttbotrcngn_9c7665'),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Toggle community maintenance failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('admin_chathcpnht_df06b6'),
      ).message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('admin_chathcpnht_df06b6')),
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
                                                    context.tr('admin_dashboardt_954f1f')),
                                                SLSpacing.h12,
                                                Text(
                                                  context.tr('admin_theodinhan_44dfc9'),
                                                  style: SLTheme.quicksand(
                                                    color: Colors.white,
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SLSpacing.h12,
                                                Text(
                                                  context.tr('admin_hinthdliuc_0d6528'),
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
                                                                      context.tr('admin_thng_c10b85'),
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
                                                  context.tr('admin_trngthihth_caf17e'),
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
                                                                      ? context.tr('admin_botrtonban_65c143')
                                                                      : context.tr('admin_botrtonban_b4ed8c'),
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
                                                                      ? context.tr('admin_ngidngthng_2c78b3')
                                                                      : context.tr('admin_hthnghotng_006fd9'),
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
                                                                      ? context.tr('admin_botrcngnga_b6fd85')
                                                                      : context.tr('admin_botrcngnga_5e948f'),
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
                                                                      ? context.tr('admin_tnhnngcngn_3e9b83')
                                                                      : context.tr('admin_tnhnngcngn_f6dcf7'),
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
                                          title: context.tr('admin_tngnh_c8a1f6'),
                                          value: '$_totalHouses',
                                          subtitle: context.tr('admin_bnghihouse_ec7358'),
                                          color: const Color(0xFF4F8CFF),
                                          icon: Icons.home_work_rounded,
                                        ),
                                        AdminStatCard(
                                          width: cardWidth,
                                          title: context.tr('admin_boco_2e9037'),
                                          value: '$_totalReports',
                                          subtitle: context.tr('admin_bnghirepor_e7df60'),
                                          color: const Color(0xFFFF6B81),
                                          icon: Icons.report_problem_rounded,
                                        ),
                                        AdminStatCard(
                                          width: cardWidth,
                                          title: context.tr('admin_bivit_998bbe'),
                                          value: '$_totalFeeds',
                                          subtitle: context.tr('admin_bnghisocia_bab4d4'),
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
                                                  context.tr('admin_nhanhgncho_02d993'),
                                                  style: SLTheme.quicksand(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SLSpacing.h16,
                                                OverviewListTile(
                                                  icon: Icons
                                                      .verified_user_rounded,
                                                  title: context.tr('admin_ngnhpadmin_eb6486'),
                                                  subtitle:
                                                      context.tr('admin_xcthcbngfi_f16353'),
                                                ),
                                                SLSpacing.h12,
                                                OverviewListTile(
                                                  icon: Icons.insights_rounded,
                                                  title: context.tr('admin_dashboardt_954f1f'),
                                                  subtitle:
                                                      context.tr('admin_hinthhouse_105d2e'),
                                                ),
                                                SLSpacing.h12,
                                                OverviewListTile(
                                                  icon: Icons.toggle_on_rounded,
                                                  title:
                                                      context.tr('admin_maintenanc_96cb53'),
                                                  subtitle:
                                                      context.tr('admin_btttnhanht_822a70'),
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
                                                  context.tr('admin_phinngnhp_d906a2'),
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
                                                      context.tr('admin_chacemail_4d9065'),
                                                ),
                                                SLSpacing.h12,
                                                const MetaRow(
                                                  label: 'Claim',
                                                  value: 'admin / super_admin',
                                                ),
                                                SLSpacing.h12,
                                                MetaRow(
                                                  label: context.tr('admin_cpnht_3b7db4'),
                                                  value: _lastUpdatedAt == null
                                                      ? context.tr('admin_chatidliu_16f82f')
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