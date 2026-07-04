import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import '../../utils/services/auth_service.dart';
import 'widgets/admin_shared_widgets.dart';
import '../../core/sl_theme.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key, required this.user});

  final firebase_auth.User user;

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorText;
  DateTime? _lastUpdatedAt;

  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    final hasExistingData = _logs.isNotEmpty;

    if (refresh || hasExistingData) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final snapshot = await _db
          .child('admin_system/audit_log')
          .limitToLast(100)
          .get()
          .timeout(const Duration(seconds: 8));
      final List<Map<String, dynamic>> loaded = [];

      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              final logData = Map<String, dynamic>.from(value);
              logData['id'] = key.toString();
              loaded.add(logData);
            }
          });
        }
      }

      // Sắp xếp mới nhất lên đầu
      loaded.sort(
          (a, b) => (b['ts'] as num? ?? 0).compareTo(a['ts'] as num? ?? 0));

      if (!mounted) return;
      setState(() {
        _logs = loaded;
        _lastUpdatedAt = DateTime.now();
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
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

  String _formatAction(String action) {
    switch (action) {
      case 'ban_perm':
        return 'Khóa vĩnh viễn';
      case 'unban':
        return 'Mở khóa';
      case 'add_vip':
        return 'Cấp PRO';
      case 'toggle_maintenance':
        return 'Bật/Tắt bảo trì toàn hệ thống';
      case 'toggle_community_maintenance':
        return 'Bật/Tắt bảo trì Cộng đồng';
      case 'update_community_maintenance_info':
        return 'Cập nhật lời nhắn bảo trì';
      case 'global_notification':
        return 'Gửi thông báo toàn Server';
      case 'direct_notification':
        return 'Gửi thông báo trực tiếp';
      default:
        return action;
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('ban')) return Colors.red;
    if (action.contains('vip')) return Colors.amber;
    if (action.contains('notification')) return const Color(0xFF00C896);
    return Colors.blue;
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
                    title: 'Lịch sử thao tác (Audit Logs)',
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
                    child: _isLoading && _logs.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : AdminGlassCard(
                            padding: const EdgeInsets.all(0),
                            child: _logs.isEmpty
                                ? const Center(
                                    child: Text('Chưa có lịch sử thao tác nào.',
                                        style: TextStyle(color: Colors.grey)),
                                  )
                                : ListView.separated(
                                    itemCount: _logs.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(
                                            color: Color(0xFF2A364E),
                                            height: 1),
                                    itemBuilder: (context, index) {
                                      final log = _logs[index];
                                      final actionStr =
                                          log['action']?.toString() ??
                                              'unknown';
                                      final ts = int.tryParse(
                                              log['ts']?.toString() ?? '0') ??
                                          0;
                                      final timeStr = ts > 0
                                          ? formatDateTime(DateTime
                                              .fromMillisecondsSinceEpoch(ts))
                                          : 'N/A';

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 24, vertical: 12),
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              _getActionColor(actionStr)
                                                  .withValues(alpha: 0.2),
                                          child: Icon(Icons.history,
                                              color:
                                                  _getActionColor(actionStr)),
                                        ),
                                        title: Text(
                                          _formatAction(actionStr),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SLSpacing.h4,
                                            Text(
                                              'Thời gian: $timeStr | Actor: ${log['actorRole'] ?? 'unknown'}',
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12),
                                            ),
                                            if (log['targetId'] != null)
                                              Text(
                                                  'Target ID: ${log['targetId']}',
                                                  style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12)),
                                            if (log['reason'] != null &&
                                                log['reason']
                                                    .toString()
                                                    .isNotEmpty)
                                              Text('Lý do: ${log['reason']}',
                                                  style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12)),
                                            if (log['title'] != null)
                                              Text(
                                                  'Tiêu đề TB: ${log['title']}',
                                                  style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12)),
                                          ],
                                        ),
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
