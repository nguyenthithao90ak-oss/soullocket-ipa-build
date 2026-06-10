import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/sl_notice.dart';
import '../../utils/app_error_mapper.dart';
import 'admin_support_chat_screen.dart';

/// ============================================================
///  AdminPanelScreen — GRA (Quản trị)
///  Bảng điều khiển dành cho Admin (Hệ thống SoulLocket)
///
///  Chức năng:
///  1. Quản lý trạng thái VIP của người dùng (add_vip).
///  2. Khóa (B?n) người dùng vi phạm (ban_perm, ban_24h, unban).
///  3. Bật/Tắt chế độ bảo trì hệ thống.
///  4. Gửi báo cáo / xóa báo cáo (send_report, clear_report).
///  5. Theo dõi thông số (houses, reports, social_feed).
/// ============================================================
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _db = FirebaseDatabase.instance;
  final _authService = AuthService();
  bool _isMaintenanceMode = false;
  bool _isCheckingAccess = true;
  bool _hasAdminAccess = false;

  int _totalHouses = 0;
  int _totalReports = 0;
  int _totalFeeds = 0;

  @override
  void initState() {
    super.initState();
    _initializeAdminAccess();
  }

  Future<void> _initializeAdminAccess() async {
    final hasAccess = await _authService.isCurrentUserAdmin(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _hasAdminAccess = hasAccess;
      _isCheckingAccess = false;
    });
    if (!hasAccess) {
      return;
    }
    _loadSystemStatus();
    _loadStats();
  }

  void _loadSystemStatus() async {
    final snapshot = await _db.ref(AppConfig.maintenanceModePath).get();
    if (!mounted) return;
    if (snapshot.exists) {
      if (!mounted) return;
      setState(() => _isMaintenanceMode = snapshot.value as bool);
    }
  }

  void _loadStats() async {
    try {
      final hSnap = await _db.ref('houses').get();
      final rSnap = await _db.ref('reports').get();
      final fSnap = await _db.ref('social_feed').get();
      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        _totalHouses = hSnap.children.length;
        _totalReports = rSnap.children.length;
        _totalFeeds = fSnap.children.length;
      });
    } catch (e) {
      debugPrint('Error loading stats: ${AppErrorMapper.resolve(e).message}');
    }
  }

  void _toggleMaintenance(bool value) async {
    if (!_hasAdminAccess) {
      _showToast(context.tr('util_bnkhngcquy_906a04'));
      return;
    }
    await Future.wait([
      _db.ref(AppConfig.maintenanceModePath).set(value),
      _db.ref(AppConfig.legacyMaintenanceModePath).set(value),
    ]);
    if (!mounted) return;
    setState(() => _isMaintenanceMode = value);
    _showToast(
        value ? context.tr('util_btbotrhthn_15c4a9') : context.tr('util_hthngsnsng_7bf976'));
  }

  void _adminActionDialog(String actionType) {
    final uidCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    String title = '';
    if (actionType == 'ban') title = context.tr('util_qunltrngth_6d5893');
    if (actionType == 'add_vip') title = context.tr('util_cpprothcng_e96db2');
    if (actionType == 'report') title = context.tr('util_xlviphmcnh_187ee5');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: uidCtrl,
              decoration:
                  InputDecoration(labelText: context.tr('util_nhpuseridt_8b5abd')),
            ),
            if (actionType == 'ban' || actionType == 'report')
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                    labelText: actionType == 'ban'
                        ? context.tr('util_ldokha_495968')
                        : context.tr('util_nidungcnhb_cdfeea')),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(context.tr('util_hy_1e4050'))),
          if (actionType == 'ban') ...[
            ElevatedButton(
              onPressed: () => _executeAdminAction(
                  ctx, 'ban_perm', uidCtrl.text.trim(), reasonCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(context.tr('util_khavnhvin_1f9874'),
                  style: const TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => _executeAdminAction(
                  ctx, 'ban_24h', uidCtrl.text.trim(), reasonCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child:
                  Text(context.tr('util_kha24h_e65f85'), style: const TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () =>
                  _executeAdminAction(ctx, 'unban', uidCtrl.text.trim(), ''),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child:
                  Text(context.tr('util_mkha_b8cf89'), style: const TextStyle(color: Colors.white)),
            ),
          ],
          if (actionType == 'add_vip')
            ElevatedButton(
              onPressed: () =>
                  _executeAdminAction(ctx, 'add_vip', uidCtrl.text.trim(), ''),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: Text(context.tr('util_cppro30ngy_df3e91'),
                  style: const TextStyle(color: Colors.black)),
            ),
          if (actionType == 'report') ...[
            ElevatedButton(
              onPressed: () => _executeAdminAction(ctx, 'send_report',
                  uidCtrl.text.trim(), reasonCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(context.tr('util_gicnhbo_e010a5'),
                  style: const TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => _executeAdminAction(
                  ctx, 'clear_report', uidCtrl.text.trim(), ''),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text(context.tr('util_xaboco_6c7ba5'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _executeAdminAction(BuildContext dialogCtx, String action,
      String targetId, String reason) async {
    final msgNoAccess = context.tr('util_bnkhngcquy_906a04');
    final msgEnterId = context.tr('util_vuilngnhpu_0f879a');
    final msgBanReasonDefault = context.tr('util_viphmnghim_40f8de');
    final msgBanPerm = context.tr('util_khatikhonv_32b914');
    final msgBan24h = context.tr('util_kha24gi_255cc6');
    final msgUnban = context.tr('util_mkhatikhon_1f76c3');
    final msgInputWarningReason = context.tr('util_nhpnidungc_0509af');
    final msgWarningSent = context.tr('util_gicnhbo_090877');
    final msgClearReports = context.tr('util_lmschhsboc_9a97c8');
    final msgActionFail = context.tr('util_chathhontt_aae5b1');

    if (!_hasAdminAccess) {
      _showToast(msgNoAccess);
      return;
    }
    if (targetId.isEmpty) {
      _showToast(msgEnterId);
      return;
    }
    final navigator = Navigator.of(dialogCtx);

    Map<String, dynamic> updates = {};
    String msg = '';

    try {
      if (action == 'add_vip') {
        final p = await _db.ref('houses/$targetId/proUntil').get();
        final current = int.tryParse(p.value?.toString() ?? '0') ?? 0;
        final nowTs = DateTime.now().millisecondsSinceEpoch;
        updates['houses/$targetId/proUntil'] =
            (current > nowTs ? current : nowTs) + (30 * 24 * 60 * 60 * 1000);
        msg = L10nService().format('util_admin_gift_pro', {'id': targetId});
      } else if (action == 'ban_perm') {
        updates['houses/$targetId/isBanned'] = true;
        updates['houses/$targetId/banReason'] =
            reason.isEmpty ? msgBanReasonDefault : reason;
        msg = msgBanPerm;
      } else if (action == 'ban_24h') {
        updates['houses/$targetId/banUntil'] =
            DateTime.now().millisecondsSinceEpoch + (24 * 60 * 60 * 1000);
        msg = msgBan24h;
      } else if (action == 'unban') {
        updates['houses/$targetId/isBanned'] = null;
        updates['houses/$targetId/banReason'] = null;
        updates['houses/$targetId/banUntil'] = null;
        msg = msgUnban;
      } else if (action == 'send_report') {
        if (reason.isEmpty) {
          _showToast(msgInputWarningReason);
          return;
        }
        await _db.ref('notifications/$targetId').push().set({
          'type': 'warning',
          'from': 'system_admin',
          'msg': L10nService().format('util_admin_violation_warning', {'reason': reason}),
          'ts': ServerValue.timestamp,
        });
        msg = msgWarningSent;
      } else if (action == 'clear_report') {
        updates['houses/$targetId/reportCount'] = 0;
        msg = msgClearReports;
      }

      if (updates.isNotEmpty) {
        await _db.ref().update(updates);
      }

      // Xử lý Audit Log (giữ chuẩn như trong admin-tools.js)
      await _db.ref('admin_system/audit_log').push().set({
        'ts': ServerValue.timestamp,
        'action': action,
        'targetId': targetId,
        'actorRole': 'support_app',
        'reason': reason,
      });

      if (navigator.mounted) navigator.pop();
      if (mounted) _showToast(msg);
    } catch (e) {
      debugPrint('Admin action failed: ${AppErrorMapper.resolve(e).message}');
      if (mounted) {
        _showToast(msgActionFail);
      }
    }
  }

  void _sendGlobalNotification() async {
    if (!_hasAdminAccess) {
      _showToast(context.tr('util_bnkhngcquy_906a04'));
      return;
    }
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('util_thngbotonc_2400f7')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: context.tr('util_tiu_ae4b89'))),
          TextField(
              controller: bodyCtrl,
              decoration: InputDecoration(labelText: context.tr('util_nidung_ee7ca5'))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(context.tr('util_hy_1e4050'))),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              await _db.ref('global_notifications').push().set({
                'title': titleCtrl.text.trim(),
                'body': bodyCtrl.text.trim(),
                'ts': ServerValue.timestamp,
              });
              if (navigator.mounted) {
                navigator.pop();
              }
              if (!mounted) return;
              _showToast(context.tr('util_phtthngbo_a8bd12'));
            },
            child: Text(context.tr('util_phttin_ec0f14')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD81B60)),
        ),
      );
    }

    if (!_hasAdminAccess) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Admin Control Panel',
            style: SLTheme.quicksand(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: SLSpacing.all24,
            child: Text(
              context.tr('util_tikhonhint_16bd79'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Control Panel',
            style: SLTheme.quicksand(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: SLSpacing.all16,
        children: [
          Row(
            children: [
              Expanded(
                  child:
                      _buildStatCard(context.tr('util_tngnh_389194'), '$_totalHouses', Colors.blue)),
              SLSpacing.w8,
              Expanded(
                  child:
                      _buildStatCard(context.tr('util_boco_42b48b'), '$_totalReports', Colors.red)),
              SLSpacing.w8,
              Expanded(
                  child:
                      _buildStatCard(context.tr('util_bivit_3f3e59'), '$_totalFeeds', Colors.green)),
            ],
          ),
          SLSpacing.h20,
          Text(context.tr('util_hthng_d531ac'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.handyman_rounded),
              title: Text(context.tr('util_chbotrmain_ab57dd')),
              subtitle: Text(
                  context.tr('util_khibtngidn_fd6b9d')),
              value: _isMaintenanceMode,
              onChanged: _toggleMaintenance,
            ),
          ),
          SLSpacing.h20,
          Text(context.tr('util_qunlngidng_f278a4'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.person_off_rounded, color: Colors.red),
                  title: Text(context.tr('util_khamkhause_0e9623')),
                  subtitle: const Text('ban_perm, ban_24h, unban'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _adminActionDialog('ban'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.stars_rounded, color: Colors.amber),
                  title: Text(context.tr('util_cpprothcng_218fd1')),
                  subtitle: const Text('add_vip'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _adminActionDialog('add_vip'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange),
                  title: Text(context.tr('util_xlbocoviph_05fa0a')),
                  subtitle: const Text('send_report, clear_report'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _adminActionDialog('report'),
                ),
              ],
            ),
          ),
          SLSpacing.h20,
          Text(context.tr('util_thngbohtr_fc83ad'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.campaign_rounded, color: Colors.deepPurple),
              title: Text(context.tr('util_githngboto_e32a3e')),
              subtitle: const Text('Broadcasting alerts to all users.'),
              trailing: const Icon(Icons.send),
              onTap: _sendGlobalNotification,
            ),
          ),
          SLSpacing.h8,
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.support_agent_rounded, color: Colors.blue),
              title: Text(context.tr('util_htrsupport_95d335')),
              subtitle: Text(context.tr('util_chatvingid_cbf855')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminSupportChatScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          SLSpacing.h4,
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    SLNotice.showInfo(context, msg);
  }
}
