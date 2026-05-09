import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import '../../services/auth_service.dart';
import '../../utils/app_error_mapper.dart';
import 'widgets/admin_shared_widgets.dart';
import '../../core/sl_theme.dart';

class AdminRewardsScreen extends StatefulWidget {
  const AdminRewardsScreen({super.key, required this.user});

  final firebase_auth.User user;

  @override
  State<AdminRewardsScreen> createState() => _AdminRewardsScreenState();
}

class _AdminRewardsScreenState extends State<AdminRewardsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorText;
  DateTime? _lastUpdatedAt;

  List<Map<String, dynamic>> _usersPoints = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final snapshot = await _db.child('users').get();
      final List<Map<String, dynamic>> loaded = [];

      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map && value.containsKey('points')) {
              final userData = Map<String, dynamic>.from(value);
              userData['uid'] = key.toString();
              loaded.add(userData);
            }
          });
        }
      }

      loaded.sort((a, b) =>
          (b['points'] as num? ?? 0).compareTo(a['points'] as num? ?? 0));

      if (!mounted) return;
      setState(() {
        _usersPoints = loaded;
        _lastUpdatedAt = DateTime.now();
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = AppErrorMapper.resolve(
          error,
          fallbackMessage:
              'Chưa thể tải dữ liệu điểm thưởng. Hãy kiểm tra kết nối rồi thử lại.',
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

  void _showAdjustPointsDialog(Map<String, dynamic> user) {
    final pointsCtrl =
        TextEditingController(text: user['points']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Chỉnh sửa điểm thưởng',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('UID: ${user['uid']}',
                style: const TextStyle(color: Colors.grey)),
            SLSpacing.h16,
            TextField(
              controller: pointsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Số điểm mới',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFF4B91))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4B91)),
            onPressed: () async {
              final newPoints = int.tryParse(pointsCtrl.text.trim());
              if (newPoints != null) {
                try {
                  await _db.child('users/${user['uid']}/points').set(newPoints);

                  await _db.child('admin_system/audit_log').push().set({
                    'ts': ServerValue.timestamp,
                    'action': 'update_points',
                    'targetId': user['uid'],
                    'oldPoints': user['points'],
                    'newPoints': newPoints,
                    'actorRole': 'web_admin',
                  });

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật điểm')));
                  _loadData(refresh: true);
                } catch (e) {
                  debugPrint('Update reward points failed: ${AppErrorMapper.resolve(
                    e,
                    fallbackMessage: 'Chưa thể cập nhật điểm lúc này.',
                  ).message}');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Chưa thể cập nhật điểm lúc này. Vui lòng thử lại.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
                    title: 'Quản lý Điểm Thưởng (Ads & Games)',
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
                        : _usersPoints.isEmpty
                            ? const Center(
                                child: Text('Không có dữ liệu điểm thưởng',
                                    style: TextStyle(color: Colors.white)))
                            : AdminGlassCard(
                                padding: const EdgeInsets.all(0),
                                child: ListView.separated(
                                  itemCount: _usersPoints.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                          color: Color(0xFF2A364E), height: 1),
                                  itemBuilder: (context, index) {
                                    final u = _usersPoints[index];
                                    final uid = u['uid']?.toString() ?? '';
                                    final points =
                                        u['points']?.toString() ?? '0';

                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 8),
                                      title: Text('UID: $uid',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text('Điểm hiện tại: $points',
                                          style: const TextStyle(
                                              color: Colors.amber)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.edit_rounded,
                                            color: Color(0xFFFF4B91)),
                                        onPressed: () =>
                                            _showAdjustPointsDialog(u),
                                        tooltip: 'Chỉnh sửa điểm',
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
