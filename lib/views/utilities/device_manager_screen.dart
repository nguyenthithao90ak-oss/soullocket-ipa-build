import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/sl_theme.dart';
import '../../services/device_manager_service.dart';
import '../../utils/sl_notice.dart';

/// ============================================================
///  DeviceManagerScreen — GRA (UI + Logic)
///  Màn hình Quản lý Thiết bị Đăng nhập
///  Dựa theo openDeviceManager() trong bundle.js (~30415)
/// ============================================================
class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({super.key});

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  final _svc = DeviceManagerService();
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;
  String _currentDeviceId = '';
  bool _currentDeviceCanManageDevices = false;
  bool _securityDeviceSignalsAllowed = true;
  String _loadMessage = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    _currentDeviceId = await _svc.getCurrentDeviceIdentifier();
    final trustState = await _svc.getCurrentDeviceTrustState(autoApprove: true);
    _currentDeviceCanManageDevices = trustState.isTrusted || trustState.isAdmin;
    await _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);

    // Auto register current device when opening screen
    // This ensures current device info and IP are up to date and listed
    try {
      _securityDeviceSignalsAllowed = await _svc.isSecurityDeviceSignalsAllowed();
      await _svc.registerCurrentDevice();
    } catch (e) {
      debugPrint('Error auto registering device: $e');
      _loadMessage = 'Chưa thể đồng bộ thiết bị lên máy chủ.';
    }

    List<Map<String, dynamic>> devices = const [];
    try {
      devices = await _svc.loadDevices();
    } catch (e) {
      debugPrint('Load devices failed: $e');
      _loadMessage = 'Chưa thể tải danh sách thiết bị từ máy chủ.';
    }
    if (devices.isEmpty) {
      final currentSnapshot = await _svc.getCurrentDeviceSnapshot();
      devices = [
        {
          ...currentSnapshot,
          'deviceId': _currentDeviceId,
          'status': _securityDeviceSignalsAllowed ? 'pending' : 'local_only',
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_admin': false,
        }
      ];
      _loadMessage = _securityDeviceSignalsAllowed
          ? (_loadMessage.isNotEmpty
              ? _loadMessage
              : 'Chưa có dữ liệu máy chủ, đang hiển thị thiết bị hiện tại.')
          : 'Bạn chưa bật quyền tín hiệu bảo mật thiết bị nên danh sách chỉ hiển thị trên máy này.';
    }
    final currentDevice = devices.cast<Map<String, dynamic>?>().firstWhere(
          (device) => device?['deviceId'] == _currentDeviceId,
          orElse: () => null,
        );
    final currentStatus = currentDevice?['status']?.toString();
    final currentIsAdmin = currentDevice?['is_admin'] == true;
    final canManageFromList = currentIsAdmin || currentStatus == 'approved';
    if (mounted) {
      setState(() {
        _devices = devices;
        _currentDeviceCanManageDevices =
            _currentDeviceCanManageDevices || canManageFromList;
        _isLoading = false;
      });
    }
  }

  Future<void> _approve(String id) async {
    if (!_currentDeviceCanManageDevices) {
      _showToast('Thiết bị hiện tại chưa đủ quyền quản lý.');
      return;
    }
    try {
      await _svc.approveDevice(id);
      _showToast('Đã duyệt thiết bị');
      await _loadDevices();
    } catch (e) {
      debugPrint('Approve device failed: $e');
      _showToast('Chưa thể duyệt thiết bị lúc này. Vui lòng thử lại.');
    }
  }

  Future<void> _block(String id) async {
    if (!_currentDeviceCanManageDevices) {
      _showToast('Thiết bị hiện tại chưa đủ quyền quản lý.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chặn thiết bị'),
        content: const Text('Bạn có chắc muốn chặn thiết bị này không?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Chặn', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _svc.blockDevice(id);
        _showToast('Đã chặn thiết bị');
        await _loadDevices();
      } catch (e) {
        debugPrint('Block device failed: $e');
        _showToast('Chưa thể chặn thiết bị lúc này. Vui lòng thử lại.');
      }
    }
  }

  Future<void> _delete(String id) async {
    if (!_currentDeviceCanManageDevices) {
      _showToast('Thiết bị hiện tại chưa đủ quyền quản lý.');
      return;
    }
    try {
      await _svc.deleteDevice(id);
      _showToast('Đã xóa thiết bị');
      await _loadDevices();
    } catch (e) {
      debugPrint('Delete device failed: $e');
      _showToast('Chưa thể xóa thiết bị lúc này. Vui lòng thử lại.');
    }
  }

  void _showToast(String msg) {
    SLNotice.showInfo(context, msg);
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return 'Không rõ';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch((ts as num).toInt());
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return 'Không rõ';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF4CAF50);
      case 'blocked':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'local_only':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status, [Map<String, dynamic>? device]) {
    switch (status) {
      case 'approved':
        return 'Đã duyệt';
      case 'blocked':
        return 'Đã chặn';
      case 'pending':
        final firstSeen = (device?['first_seen'] as num?)?.toInt() ?? 0;
        if (firstSeen <= 0) return 'Chờ duyệt';
        final autoApproveAtMs =
            firstSeen + DeviceManagerService.pendingAutoTrustDelay.inMilliseconds;
        final remainingMs =
            autoApproveAtMs - DateTime.now().millisecondsSinceEpoch;
        if (remainingMs <= 0) {
          return 'Sắp được duyệt';
        }
        final remainingHours =
            (remainingMs / Duration.millisecondsPerHour).ceil();
        return 'Còn $remainingHours giờ sẽ được duyệt';
      case 'local_only':
        return 'Chỉ trên máy này';
      default:
        return 'Không rõ';
    }
  }

  IconData _platformIcon(String? platform) {
    switch (platform) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.apple;
      case 'web':
        return Icons.web;
      default:
        return Icons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Quản lý Thiết bị',
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFFD81B60),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F0FF), Color(0xFFFFE4EE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD81B60)))
            : _devices.isEmpty
                ? _buildEmpty()
                : _buildList(),
      ),
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD81B60).withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFFD81B60)),
          SLSpacing.w8,
          Expanded(
            child: Text(
              _loadMessage,
              style: SLTheme.quicksand(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.devices_other, size: 72, color: Color(0xFFD81B60)),
          SLSpacing.h16,
          Text(
            'Chưa có thiết bị nào đăng nhập',
            style: SLTheme.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
      itemCount: _devices.length + (_loadMessage.isNotEmpty ? 1 : 0),
      itemBuilder: (context, i) {
        if (_loadMessage.isNotEmpty && i == 0) {
          return _buildNoticeCard();
        }
        final device = _devices[i - (_loadMessage.isNotEmpty ? 1 : 0)];
        final status = device['status'] as String?;
        final id = device['deviceId'] as String? ?? '';
        final isMe = id == _currentDeviceId;
        final isAdmin = device['is_admin'] == true;
        final canTakeAction = !isMe && _currentDeviceCanManageDevices;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFE3F2FD) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    isMe ? Colors.blue : _statusColor(status).withOpacity(0.4),
                width: 2),
            boxShadow: [
              BoxShadow(
                  color: _statusColor(status).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _statusColor(status).withOpacity(0.2),
                  _statusColor(status).withOpacity(0.05)
                ]),
                shape: BoxShape.circle,
              ),
              child: Icon(_platformIcon(device['platform']),
                  color: _statusColor(status), size: 28),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    device['model'] ?? 'Thiết bị không rõ',
                    style: SLTheme.quicksand(
                        fontWeight: FontWeight.w900, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMe)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Bạn',
                      style: SLTheme.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (isAdmin && !isMe)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Admin',
                      style: SLTheme.quicksand(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SLSpacing.h4,
                Text(device['os'] ?? '',
                    style:
                        SLTheme.quicksand(fontSize: 12, color: Colors.black54)),
                SLSpacing.gapH(2),
                Text('Lần cuối: ${_formatTs(device['last_seen'])}',
                    style:
                        SLTheme.quicksand(fontSize: 11, color: Colors.black45)),
                if (device['ip'] != null && device['ip'] != 'unknown') ...[
                  SLSpacing.gapH(2),
                  Text('IP: ${device['ip']}',
                      style: SLTheme.quicksand(
                          fontSize: 11, color: Colors.black45)),
                ],
                if (device['location'] != null &&
                    device['location'] != 'unknown') ...[
                  SLSpacing.gapH(2),
                  Text('Vị trí: ${device['location']}',
                      style: SLTheme.quicksand(
                          fontSize: 11, color: Colors.black45)),
                ],
                if (device['ipSource'] != null &&
                    device['ipSource'] != 'unknown') ...[
                  SLSpacing.gapH(2),
                  Text('Nguồn IP: ${device['ipSource']}',
                      style:
                          SLTheme.quicksand(fontSize: 10, color: Colors.grey)),
                ],
                SLSpacing.h8,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: SLRadius.mdAll,
                  ),
                  child: Text(
                    _statusLabel(status, device),
                    style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _statusColor(status)),
                  ),
                ),
              ],
            ),
            children: [
              if (canTakeAction)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (status != 'approved')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approve(id),
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: const Text('Duyệt'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      if (status != 'approved') SLSpacing.w8,
                      if (status != 'blocked')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _block(id),
                            icon: const Icon(Icons.block, size: 18),
                            label: const Text('Chặn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      if (status != 'blocked') SLSpacing.w8,
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _delete(id),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Xóa'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!canTakeAction)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    isMe
                        ? 'Đây là thiết bị bạn đang dùng nên không thể tự chặn hoặc tự xóa.'
                        : 'Thiết bị hiện tại của bạn chưa đủ quyền để quản lý danh sách này.',
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
