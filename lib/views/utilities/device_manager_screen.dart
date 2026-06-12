import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:intl/intl.dart';

import '../../core/sl_theme.dart';
import '../../services/device_manager_service.dart';
import '../../utils/app_error_mapper.dart';
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
  bool _isSyncingDevices = false;
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
    final msgFallback = context.tr('util_chathtithn_526c2d');
    try {
      _currentDeviceId = await _svc.getCurrentDeviceIdentifier();
      final currentSnapshot = await _svc.getCurrentDeviceSnapshot();
      if (!mounted) return;
      setState(() {
        _devices = [
          {
            ...currentSnapshot,
            'deviceId': _currentDeviceId,
            'status': 'local_only',
            'last_seen': DateTime.now().millisecondsSinceEpoch,
            'is_admin': false,
          }
        ];
        _loadMessage = context.tr('util_angngbdanh_0b2773');
        _isLoading = false;
        _isSyncingDevices = true;
      });
      final trustState =
          await _svc.getCurrentDeviceTrustState(autoApprove: true);
      if (!mounted) return;
      _currentDeviceCanManageDevices =
          trustState.isTrusted || trustState.isAdmin;
      unawaited(_loadDevices());
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: msgFallback,
      );
      debugPrint('Init device manager failed: ${errorInfo.message}');
      if (!mounted) return;
      setState(() {
        _loadMessage = errorInfo.message;
        _isLoading = false;
        _isSyncingDevices = false;
      });
    }
  }

  Future<void> _loadDevices() async {
    if (!mounted) return;
    setState(() {
      _isSyncingDevices = true;
      if (_devices.isEmpty) {
        _isLoading = true;
      }
    });
    final msgRegisterFail = context.tr('util_chathngbth_d39079');
    final msgLoadFail = context.tr('util_chathtidan_e58038');
    final msgOnlyCurrentDevice = context.tr('util_nubntngngn_2e56cd');
    final msgNoDevices = context.tr('util_chacdliumy_af1225');

    try {
      _securityDeviceSignalsAllowed =
          await _svc.isSecurityDeviceSignalsAllowed();
      if (!_securityDeviceSignalsAllowed) {
        await _svc.setSecurityDeviceSignalsAllowed(true);
        _securityDeviceSignalsAllowed = true;
      }
      await _svc.registerCurrentDevice();
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: msgRegisterFail,
      );
      debugPrint('Error auto registering device: ${errorInfo.message}');
      _loadMessage = errorInfo.message;
    }

    List<Map<String, dynamic>> devices = const [];
    try {
      devices = await _svc.loadDevices();
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: msgLoadFail,
      );
      debugPrint('Load devices failed: ${errorInfo.message}');
      _loadMessage = errorInfo.message;
    }

    final hasCurrentDevice = devices.any(
        (device) => device['deviceId']?.toString().trim() == _currentDeviceId);
    if (!hasCurrentDevice) {
      final currentSnapshot = await _svc.getCurrentDeviceSnapshot();
      if (!mounted) return;
      devices = [
        ...devices,
        {
          ...currentSnapshot,
          'deviceId': _currentDeviceId,
          'status': _securityDeviceSignalsAllowed ? 'pending' : 'local_only',
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_admin': false,
        }
      ];
      if (_loadMessage.isEmpty && devices.length == 1) {
        _loadMessage = msgOnlyCurrentDevice;
      }
    }

    if (devices.isEmpty) {
      final currentSnapshot = await _svc.getCurrentDeviceSnapshot();
      if (!mounted) return;
      devices = [
        {
          ...currentSnapshot,
          'deviceId': _currentDeviceId,
          'status': _securityDeviceSignalsAllowed ? 'pending' : 'local_only',
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_admin': false,
        }
      ];
      _loadMessage = _loadMessage.isNotEmpty
          ? _loadMessage
          : msgNoDevices;
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
        _isSyncingDevices = false;
      });
    }
  }

  Future<void> _approve(String id) async {
    if (!_currentDeviceCanManageDevices) {
      _showToast(context.tr('util_thitbhinti_0d74f0'));
      return;
    }
    final msgOk = context.tr('util_duytthitb_8d23d7');
    final msgFail = context.tr('util_chathduytt_d4a412');
    try {
      await _svc.approveDevice(id);
      if (!mounted) return;
      _showToast(msgOk);
      await _loadDevices();
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: msgFail,
      );
      debugPrint('Approve device failed: ${errorInfo.message}');
      _showToast(errorInfo.message);
    }
  }

  Future<void> _block(String id) async {
    if (!_currentDeviceCanManageDevices) {
      _showToast(context.tr('util_thitbhinti_0d74f0'));
      return;
    }
    final msgOk = context.tr('util_chnthitb_763bc8');
    final msgFail = context.tr('util_chathchnth_5a7417');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('util_chnthitb_172ff3')),
        content: Text(context.tr('util_bncchcmunc_271400')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('util_hy_1e4050'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('util_chn_483b6f'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _svc.blockDevice(id);
        if (!mounted) return;
        _showToast(msgOk);
        await _loadDevices();
      } catch (e) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: msgFail,
        );
        debugPrint('Block device failed: ${errorInfo.message}');
        _showToast(errorInfo.message);
      }
    }
  }

  Future<void> _delete(String id) async {
    if (!_currentDeviceCanManageDevices) {
      _showToast(context.tr('util_thitbhinti_0d74f0'));
      return;
    }
    final msgOk = context.tr('util_xathitb_78ba12');
    final msgFail = context.tr('util_chathxathi_89c942');
    try {
      await _svc.deleteDevice(id);
      if (!mounted) return;
      _showToast(msgOk);
      await _loadDevices();
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: msgFail,
      );
      debugPrint('Delete device failed: ${errorInfo.message}');
      _showToast(errorInfo.message);
    }
  }

  void _showToast(String msg) {
    SLNotice.showInfo(context, msg);
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return context.tr('util_khngr_b18ff7');
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch((ts as num).toInt());
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return context.tr('util_khngr_b18ff7');
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
        return context.tr('util_duyt_e451b6');
      case 'blocked':
        return context.tr('util_chn_7c554a');
      case 'pending':
        final firstSeen = (device?['first_seen'] as num?)?.toInt() ?? 0;
        if (firstSeen <= 0) return context.tr('util_chduyt_acb8dc');
        final autoApproveAtMs = firstSeen +
            DeviceManagerService.pendingAutoTrustDelay.inMilliseconds;
        final remainingMs =
            autoApproveAtMs - DateTime.now().millisecondsSinceEpoch;
        if (remainingMs <= 0) {
          return context.tr('util_spcduyt_44589a');
        }
        final remainingHours =
            (remainingMs / Duration.millisecondsPerHour).ceil();
        return L10nService().format(
            'util_device_approve_hours_left', {'hours': remainingHours});
      case 'local_only':
        return context.tr('util_chtrnmyny_838a8e');
      default:
        return context.tr('util_khngr_b18ff7');
    }
  }

  String _statusLabelForTile(
    String? status,
    Map<String, dynamic> device,
    bool isMe,
  ) {
    if (_isSyncingDevices && isMe && status == 'local_only') {
      return 'Đang xác minh với máy chủ...';
    }
    return _statusLabel(status, device);
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
          context.tr('util_qunlthitb_983ee3'),
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
    final message = _loadMessage.trim().isNotEmpty
        ? _loadMessage.trim()
        : context.tr('util_danhschnyh_d80689');
    final isSyncing = _isSyncingDevices;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFFD81B60).withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.08),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSyncing
                      ? 'Đang tải danh sách thiết bị từ máy chủ. Thiết bị bên dưới chỉ là máy hiện tại tạm thời.'
                      : message,
                  style: SLTheme.quicksand(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                if (isSyncing) ...[
                  SLSpacing.h8,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      color: Color(0xFFD81B60),
                      backgroundColor: Color(0xFFFFD6E5),
                    ),
                  ),
                ],
              ],
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
            context.tr('util_chacthitbn_85fc6a'),
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
      itemCount: _devices.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNoticeCard(),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  L10nService().format(
                      'util_device_showing_count', {'count': _devices.length}),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          );
        }
        final device = _devices[i - 1];
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
                color: isMe
                    ? Colors.blue
                    : _statusColor(status).withValues(alpha: 0.4),
                width: 2),
            boxShadow: [
              BoxShadow(
                  color: _statusColor(status).withValues(alpha: 0.08),
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
                  _statusColor(status).withValues(alpha: 0.2),
                  _statusColor(status).withValues(alpha: 0.05)
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
                    device['model'] ?? context.tr('util_thitbkhngr_671ddb'),
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
                      context.tr('util_bn_1fd75b'),
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
                Text(
                    L10nService().format('util_device_last_seen',
                        {'time': _formatTs(device['last_seen'])}),
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
                  Text(
                      L10nService().format('util_device_location',
                          {'location': device['location']}),
                      style: SLTheme.quicksand(
                          fontSize: 11, color: Colors.black45)),
                ],
                if (device['ipSource'] != null &&
                    device['ipSource'] != 'unknown') ...[
                  SLSpacing.gapH(2),
                  Text(
                      L10nService().format('util_device_ip_source',
                          {'source': device['ipSource']}),
                      style:
                          SLTheme.quicksand(fontSize: 10, color: Colors.grey)),
                ],
                SLSpacing.h8,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: SLRadius.mdAll,
                  ),
                  child: Text(
                    _statusLabelForTile(status, device, isMe),
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
                    color: Colors.grey.withValues(alpha: 0.05),
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
                            label: Text(context.tr('util_duyt_a4db4d')),
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
                            label: Text(context.tr('util_chn_483b6f')),
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
                          label: Text(context.tr('util_xa_4ed187')),
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
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    isMe
                        ? context.tr('util_ylthitbbna_af3295')
                        : context.tr('util_thitbhinti_7d3436'),
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
