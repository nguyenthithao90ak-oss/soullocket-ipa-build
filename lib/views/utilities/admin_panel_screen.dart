import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/app_config.dart';
import '../../core/sl_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/sl_notice.dart';
import 'admin_support_chat_screen.dart';

/// ============================================================
///  AdminPanelScreen — GRA (Quản trị)
///  Bảng điều khiển dành cho Admin (Hệ thống SoulLocket)
///
///  Chức năng:
///  1. Quản lý trạng thái VIP của người dùng (add_vip).
///  2. Khóa (Ban) người dùng vi phạm (ban_perm, ban_24h, unban).
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
      debugPrint('Error loading stats: $e');
    }
  }

  void _toggleMaintenance(bool value) async {
    if (!_hasAdminAccess) {
      _showToast('Bạn không có quyền quản trị hợp lệ.');
      return;
    }
    await Future.wait([
      _db.ref(AppConfig.maintenanceModePath).set(value),
      _db.ref(AppConfig.legacyMaintenanceModePath).set(value),
    ]);
    if (!mounted) return;
    setState(() => _isMaintenanceMode = value);
    _showToast(
        value ? 'Đã bật Bảo trì hệ thống 🛠️' : 'Hệ thống đã sẵn sàng ✅');
  }

  void _adminActionDialog(String actionType) {
    final uidCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    String title = '';
    if (actionType == 'ban') title = 'Quản lý Trạng Thái User';
    if (actionType == 'add_vip') title = 'Cấp PRO Thủ Công';
    if (actionType == 'report') title = 'Xử lý Vi Phạm & Cảnh Báo';

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
                  const InputDecoration(labelText: 'Nhập User ID (Target ID)'),
            ),
            if (actionType == 'ban' || actionType == 'report')
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                    labelText: actionType == 'ban'
                        ? 'Lý do khóa'
                        : 'Nội dung cảnh báo'),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          if (actionType == 'ban') ...[
            ElevatedButton(
              onPressed: () => _executeAdminAction(
                  ctx, 'ban_perm', uidCtrl.text.trim(), reasonCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Khóa Vĩnh Viễn',
                  style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => _executeAdminAction(
                  ctx, 'ban_24h', uidCtrl.text.trim(), reasonCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child:
                  const Text('Khóa 24H', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () =>
                  _executeAdminAction(ctx, 'unban', uidCtrl.text.trim(), ''),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child:
                  const Text('Mở Khóa', style: TextStyle(color: Colors.white)),
            ),
          ],
          if (actionType == 'add_vip')
            ElevatedButton(
              onPressed: () =>
                  _executeAdminAction(ctx, 'add_vip', uidCtrl.text.trim(), ''),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('Cấp PRO 30 Ngày',
                  style: TextStyle(color: Colors.black)),
            ),
          if (actionType == 'report') ...[
            ElevatedButton(
              onPressed: () => _executeAdminAction(ctx, 'send_report',
                  uidCtrl.text.trim(), reasonCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Gửi Cảnh Báo',
                  style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => _executeAdminAction(
                  ctx, 'clear_report', uidCtrl.text.trim(), ''),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Xóa Báo Cáo',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _executeAdminAction(BuildContext dialogCtx, String action,
      String targetId, String reason) async {
    if (!_hasAdminAccess) {
      _showToast('Bạn không có quyền quản trị hợp lệ.');
      return;
    }
    if (targetId.isEmpty) {
      _showToast('Vui lòng nhập User ID');
      return;
    }
    final navigator = Navigator.of(dialogCtx);

    Map<String, dynamic> updates = {};
    String msg = "";

    try {
      if (action == 'add_vip') {
        final p = await _db.ref('houses/$targetId/proUntil').get();
        final current = int.tryParse(p.value?.toString() ?? '0') ?? 0;
        final nowTs = DateTime.now().millisecondsSinceEpoch;
        updates['houses/$targetId/proUntil'] =
            (current > nowTs ? current : nowTs) + (30 * 24 * 60 * 60 * 1000);
        msg = "Đã tặng 30 ngày PRO cho T.ID: $targetId";
      } else if (action == 'ban_perm') {
        updates['houses/$targetId/isBanned'] = true;
        updates['houses/$targetId/banReason'] =
            reason.isEmpty ? "Vi phạm nghiêm trọng" : reason;
        msg = "Đã khóa tài khoản vĩnh viễn";
      } else if (action == 'ban_24h') {
        updates['houses/$targetId/banUntil'] =
            DateTime.now().millisecondsSinceEpoch + (24 * 60 * 60 * 1000);
        msg = "Đã khóa 24 giờ";
      } else if (action == 'unban') {
        updates['houses/$targetId/isBanned'] = null;
        updates['houses/$targetId/banReason'] = null;
        updates['houses/$targetId/banUntil'] = null;
        msg = "Đã mở khóa tài khoản";
      } else if (action == 'send_report') {
        if (reason.isEmpty) {
          _showToast('Nhập nội dung cảnh báo!');
          return;
        }
        await _db.ref('notifications/$targetId').push().set({
          'type': 'warning',
          'from': 'system_admin',
          'msg': 'CẢNH BÁO VI PHẠM: $reason',
          'ts': ServerValue.timestamp,
        });
        msg = "Đã gửi cảnh báo!";
      } else if (action == 'clear_report') {
        updates['houses/$targetId/reportCount'] = 0;
        msg = "Đã làm sạch hồ sơ báo cáo";
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
      debugPrint('Admin action failed: $e');
      if (mounted) {
        _showToast(
            'Chưa thể hoàn tất thao tác quản trị lúc này. Vui lòng thử lại.');
      }
    }
  }

  void _sendGlobalNotification() async {
    if (!_hasAdminAccess) {
      _showToast('Bạn không có quyền quản trị hợp lệ.');
      return;
    }
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thông Báo Toàn Cầu 📣'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Tiêu đề')),
          TextField(
              controller: bodyCtrl,
              decoration: const InputDecoration(labelText: 'Nội dung')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
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
              _showToast('Đã phát thông báo!');
            },
            child: const Text('PHÁT TIN'),
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
              'Tài khoản hiện tại không có custom claim admin hợp lệ.',
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
                      _buildStatCard('Tổng Nhà', '$_totalHouses', Colors.blue)),
              SLSpacing.w8,
              Expanded(
                  child:
                      _buildStatCard('Báo Cáo', '$_totalReports', Colors.red)),
              SLSpacing.w8,
              Expanded(
                  child:
                      _buildStatCard('Bài Viết', '$_totalFeeds', Colors.green)),
            ],
          ),
          SLSpacing.h20,
          const Text('HỆ THỐNG',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.handyman_rounded),
              title: const Text('Chế độ Bảo trì (Maintenance)'),
              subtitle: const Text(
                  'Khi bật, người dùng bình thường không thể vào app.'),
              value: _isMaintenanceMode,
              onChanged: _toggleMaintenance,
            ),
          ),
          SLSpacing.h20,
          const Text('QUẢN LÝ NGƯỜI DÙNG',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.person_off_rounded, color: Colors.red),
                  title: const Text('Khóa / Mở Khóa User'),
                  subtitle: const Text('ban_perm, ban_24h, unban'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _adminActionDialog('ban'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.stars_rounded, color: Colors.amber),
                  title: const Text('Cấp PRO Thủ Công +30D'),
                  subtitle: const Text('add_vip'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _adminActionDialog('add_vip'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange),
                  title: const Text('Xử lý Báo Cáo & Vi Phạm'),
                  subtitle: const Text('send_report, clear_report'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _adminActionDialog('report'),
                ),
              ],
            ),
          ),
          SLSpacing.h20,
          const Text('THÔNG BÁO & HỖ TRỢ',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.campaign_rounded, color: Colors.deepPurple),
              title: const Text('Gửi thông báo toàn cục'),
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
              title: const Text('Hỗ trợ Support (AI)'),
              subtitle: const Text('Chat với người dùng có gợi ý AI'),
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
        color: color.withOpacity(0.1),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: color.withOpacity(0.5)),
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
