import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/app_error_mapper.dart';
import 'widgets/admin_shared_widgets.dart';
import 'widgets/security_protection_rollout_panel.dart';

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key, required this.user});

  final firebase_auth.User user;

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  static const Color _maintenanceAccentColor = Color(0xFFFF4B91);

  final _db = FirebaseDatabase.instance.ref();
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorText;
  DateTime? _lastUpdatedAt;

  bool _isMaintenanceMode = false;
  bool _isCommunityMaintenanceMode = false;
  final _communityMaintenanceMsgCtrl = TextEditingController();
  final _communityMaintenanceEtaCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _targetHouseIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _communityMaintenanceMsgCtrl.dispose();
    _communityMaintenanceEtaCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _targetHouseIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        _db.child(AppConfig.maintenanceModePath).get(),
        _db.child(AppConfig.communityMaintenanceModePath).get(),
        _db.child(AppConfig.communityMaintenanceMsgPath).get(),
        _db.child(AppConfig.communityMaintenanceEtaPath).get(),
      ]);
      final maintenance = results[0].value == true;
      final communityMaintenance = results[1].value == true;
      final communityMsg = results[2].value?.toString() ?? '';
      final communityEta = results[3].value?.toString() ?? '';

      if (!mounted) return;
      setState(() {
        _isMaintenanceMode = maintenance;
        _isCommunityMaintenanceMode = communityMaintenance;
        _communityMaintenanceMsgCtrl.text = communityMsg;
        _communityMaintenanceEtaCtrl.text = communityEta;
        _lastUpdatedAt = DateTime.now();
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = AppErrorMapper.resolve(
          error,
          fallbackMessage: context.tr('admin_chathticuh_10b42f'),
        ).message;
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

  Future<void> _handleSignOut() async {
    await _authService.signOut();
  }

  Future<void> _toggleMaintenance(bool value) async {
    try {
      await Future.wait([
        _db.child(AppConfig.maintenanceModePath).set(value),
        _db.child(AppConfig.legacyMaintenanceModePath).set(value),
      ]);

      await _db.child('admin_system/audit_log').push().set({
        'ts': ServerValue.timestamp,
        'action': 'toggle_maintenance',
        'value': value,
        'actorRole': 'web_admin',
      });

      if (!mounted) return;
      setState(() => _isMaintenanceMode = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(value
                ? context.tr('admin_btbotr_26d9dd')
                : context.tr('admin_ttbotr_75a6e2'))),
      );
    } catch (error) {
      if (!mounted) return;
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('admin_chathcpnht_68b279'),
      );
      debugPrint('Toggle maintenance failed: ${errorInfo.message}');
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

      await _db.child('admin_system/audit_log').push().set({
        'ts': ServerValue.timestamp,
        'action': 'toggle_community_maintenance',
        'value': value,
        'actorRole': 'web_admin',
      });

      if (!mounted) return;
      setState(() => _isCommunityMaintenanceMode = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(value
                ? context.tr('admin_btbotrcngn_0ee821')
                : context.tr('admin_ttbotrcngn_668a0e'))),
      );
    } catch (error) {
      if (!mounted) return;
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('admin_chathcpnht_df06b6'),
      );
      debugPrint('Toggle community maintenance failed: ${errorInfo.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('admin_chathcpnht_df06b6')),
        ),
      );
    }
  }

  Future<void> _saveCommunityMaintenanceSettings() async {
    final msg = _communityMaintenanceMsgCtrl.text.trim();
    final eta = _communityMaintenanceEtaCtrl.text.trim();

    try {
      await Future.wait([
        _db.child(AppConfig.communityMaintenanceMsgPath).set(msg),
        _db.child(AppConfig.communityMaintenanceEtaPath).set(eta),
      ]);

      await _db.child('admin_system/audit_log').push().set({
        'ts': ServerValue.timestamp,
        'action': 'update_community_maintenance_info',
        'msg': msg,
        'eta': eta,
        'actorRole': 'web_admin',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('admin_luthngbobo_ffd83d'))),
      );
    } catch (error) {
      if (!mounted) return;
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: context.tr('admin_chathluthn_ed6103'),
      );
      debugPrint(
        'Save community maintenance settings failed: ${errorInfo.message}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('admin_chathluthn_ed6103')),
        ),
      );
    }
  }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final targetId = _targetHouseIdCtrl.text.trim();

    final inputErrorMsg = context.tr('admin_vuilngnhpy_5eed10');
    final noHousesMsg = context.tr('admin_khngtmthyn_fd9b5f');
    final systemAdminFrom = context.tr('admin_hthngadmin_432841');
    final errorFallback = context.tr('admin_chathgithn_2acce6');

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(inputErrorMsg)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<String> houseIds = [];

      if (targetId.isNotEmpty) {
        houseIds.add(targetId);
      } else {
        throw 'Gửi thông báo toàn hệ thống tạm thời bị khóa. Vui lòng nhập House ID cụ thể.';
      }

      // 2. Batch send to notifications node
      final batch = <Future>[];
      for (final hid in houseIds) {
        batch.add(_db.child('notifications/$hid').push().set({
          'type': 'system',
          'from': systemAdminFrom,
          'title': title,
          'msg': body, // Using msg instead of content to match push() in helper
          'ts': ServerValue.timestamp,
          'extra': {
            'immutable': true,
            'systemLocked': true,
          }
        }));
      }
      await Future.wait(batch);

      // 3. Log
      await _db.child('admin_system/audit_log').push().set({
        'ts': ServerValue.timestamp,
        'action':
            targetId.isNotEmpty ? 'direct_notification' : 'global_notification',
        'title': title,
        'body': body,
        'targetId': targetId.isNotEmpty ? targetId : 'all',
        'count': houseIds.length,
        'actorRole': 'web_admin',
      });

      if (!mounted) return;
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _targetHouseIdCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gửi thông báo đến ${houseIds.length} nhà!')),
      );
    } catch (e) {
      if (!mounted) return;
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: errorFallback,
      );
      debugPrint('Send notification failed: ${errorInfo.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorFallback),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                    title: context.tr('admin_cuhnhhthng_73c643'),
                    user: widget.user,
                    isRefreshing: _isRefreshing,
                    lastUpdatedAt: _lastUpdatedAt,
                    onRefresh: () => _loadData(refresh: true),
                    onSignOut: _handleSignOut,
                  ),
                  SLSpacing.h24,
                  if (_errorText != null)
                    Text(_errorText!,
                        style: const TextStyle(color: Colors.red)),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxWidth < 800;
                                return Column(
                                  children: [
                                    Flex(
                                      direction: isCompact
                                          ? Axis.vertical
                                          : Axis.horizontal,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: isCompact ? 0 : 1,
                                          child: AdminGlassCard(
                                            padding: SLSpacing.all24,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  context.tr(
                                                      'admin_chbotr_a5b13d'),
                                                  style: SLTheme.quicksand(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SLSpacing.h16,
                                                SwitchListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                      context.tr(
                                                          'admin_btbotrtonh_31085d'),
                                                      style: const TextStyle(
                                                          color: Colors.white)),
                                                  subtitle: Text(
                                                      context.tr(
                                                          'admin_ngidngthng_70f24c'),
                                                      style: const TextStyle(
                                                          color: Colors.grey)),
                                                  value: _isMaintenanceMode,
                                                  onChanged: _toggleMaintenance,
                                                  activeThumbColor:
                                                      _maintenanceAccentColor,
                                                ),
                                                SwitchListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                      context.tr(
                                                          'admin_botrcngngs_d286ae'),
                                                      style: const TextStyle(
                                                          color: Colors.white)),
                                                  subtitle: Text(
                                                      context.tr(
                                                          'admin_chkhatabcn_c5ab3c'),
                                                      style: const TextStyle(
                                                          color: Colors.grey)),
                                                  value:
                                                      _isCommunityMaintenanceMode,
                                                  onChanged:
                                                      _toggleCommunityMaintenance,
                                                  activeThumbColor:
                                                      _maintenanceAccentColor,
                                                ),
                                                SLSpacing.h16,
                                                TextField(
                                                  controller:
                                                      _communityMaintenanceMsgCtrl,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                  maxLines: 2,
                                                  decoration: InputDecoration(
                                                    labelText: context.tr(
                                                        'admin_linhnbotr_067aa4'),
                                                    labelStyle: const TextStyle(
                                                        color: Colors.grey),
                                                    hintText: context.tr(
                                                        'admin_mcnhtnhnng_d9687b'),
                                                    hintStyle: const TextStyle(
                                                        color: Colors.grey),
                                                    enabledBorder:
                                                        const OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: Colors.grey),
                                                    ),
                                                    focusedBorder:
                                                        const OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: Color(
                                                              0xFFFF4B91)),
                                                    ),
                                                  ),
                                                ),
                                                SLSpacing.h12,
                                                TextField(
                                                  controller:
                                                      _communityMaintenanceEtaCtrl,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                  decoration: InputDecoration(
                                                    labelText: context.tr(
                                                        'admin_dkinmlityc_02d30d'),
                                                    labelStyle: const TextStyle(
                                                        color: Colors.grey),
                                                    hintText: context.tr(
                                                        'admin_vd1530ngyh_3994f5'),
                                                    hintStyle: const TextStyle(
                                                        color: Colors.grey),
                                                    enabledBorder:
                                                        const OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: Colors.grey),
                                                    ),
                                                    focusedBorder:
                                                        const OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: Color(
                                                              0xFFFF4B91)),
                                                    ),
                                                  ),
                                                ),
                                                SLSpacing.h16,
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: ElevatedButton(
                                                    onPressed:
                                                        _saveCommunityMaintenanceSettings,
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF1E88E5), // Blue
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 24,
                                                          vertical: 12),
                                                    ),
                                                    child: Text(
                                                        context.tr(
                                                            'admin_luthngbo_188629'),
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                            width: isCompact ? 0 : 24,
                                            height: isCompact ? 24 : 0),
                                        Expanded(
                                          flex: isCompact ? 0 : 1,
                                          child: AdminGlassCard(
                                            padding: SLSpacing.all24,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  context.tr(
                                                      'admin_githngboys_2d765a'),
                                                  style: SLTheme.quicksand(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SLSpacing.h8,
                                                Text(
                                                    context.tr(
                                                        'admin_gitrctipvo_eb8f27'),
                                                    style: const TextStyle(
                                                        color: Colors.grey)),
                                                SLSpacing.h16,
                                                TextField(
                                                  controller:
                                                      _targetHouseIdCtrl,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                  decoration: InputDecoration(
                                                    labelText: context.tr(
                                                        'admin_idnhtrngnu_62421e'),
                                                    labelStyle: const TextStyle(
                                                        color: Colors.grey),
                                                    enabledBorder:
                                                        const OutlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .grey)),
                                                    focusedBorder:
                                                        const OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                                color: Color(
                                                                    0xFFFF4B91))),
                                                  ),
                                                ),
                                                SLSpacing.h16,
                                                TextField(
                                                  controller: _titleCtrl,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                  decoration: InputDecoration(
                                                    labelText: context.tr(
                                                        'admin_tiuthngbo_ea017e'),
                                                    labelStyle: const TextStyle(
                                                        color: Colors.grey),
                                                    enabledBorder:
                                                        const OutlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .grey)),
                                                    focusedBorder:
                                                        const OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                                color: Color(
                                                                    0xFFFF4B91))),
                                                  ),
                                                ),
                                                SLSpacing.h16,
                                                TextField(
                                                  controller: _bodyCtrl,
                                                  maxLines: 3,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                  decoration: InputDecoration(
                                                    labelText: context.tr(
                                                        'admin_nidung_ee7ca5'),
                                                    labelStyle: const TextStyle(
                                                        color: Colors.grey),
                                                    enabledBorder:
                                                        const OutlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .grey)),
                                                    focusedBorder:
                                                        const OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                                color: Color(
                                                                    0xFFFF4B91))),
                                                  ),
                                                ),
                                                SLSpacing.h16,
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFFFF4B91),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 16),
                                                    ),
                                                    onPressed:
                                                        _sendNotification,
                                                    icon: const Icon(
                                                        Icons.send_rounded,
                                                        color: Colors.white),
                                                    label: Text(
                                                        context.tr(
                                                            'admin_phtthngbo_b92386'),
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    SecurityProtectionRolloutPanel(
                                      actorId: (widget.user.email
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false)
                                          ? widget.user.email!.trim()
                                          : widget.user.uid,
                                      refreshSeed: _lastUpdatedAt
                                              ?.millisecondsSinceEpoch ??
                                          0,
                                    ),
                                  ],
                                );
                              },
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
