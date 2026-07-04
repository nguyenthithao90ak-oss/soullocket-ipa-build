import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/device_manager_service.dart';
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
    final msgFallback = L10nService().translate('util_chathtithn_526c2d');
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
        _loadMessage = L10nService().translate('util_angngbdanh_0b2773');
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
    final msgRegisterFail = L10nService().translate('util_chathngbth_d39079');
    final msgLoadFail = L10nService().translate('util_chathtidan_e58038');
    final msgOnlyCurrentDevice =
        L10nService().translate('util_nubntngngn_2e56cd');
    final msgNoDevices = L10nService().translate('util_chacdliumy_af1225');

    try {
      _securityDeviceSignalsAllowed =
          await _svc.isSecurityDeviceSignalsAllowed();
      if (!_securityDeviceSignalsAllowed) {
        await _svc.setSecurityDeviceSignalsAllowed(true);
        _securityDeviceSignalsAllowed = true;
      }
      await _svc.registerCurrentDevice();

      List<Map<String, dynamic>> devices = const [];
      try {
        devices = await _svc.loadDevices().timeout(const Duration(seconds: 12));
      } catch (e) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: msgLoadFail,
        );
        debugPrint('Load devices failed: ${errorInfo.message}');
        _loadMessage = errorInfo.message;
      }

      final hasCurrentDevice = devices.any((device) =>
          device['deviceId']?.toString().trim() == _currentDeviceId);
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
        _loadMessage = _loadMessage.isNotEmpty ? _loadMessage : msgNoDevices;
      }

      devices.sort((a, b) {
        final aIsCurrent = a['deviceId'] == _currentDeviceId;
        final bIsCurrent = b['deviceId'] == _currentDeviceId;
        if (aIsCurrent && !bIsCurrent) return -1;
        if (!aIsCurrent && bIsCurrent) return 1;

        final aTs = (a['last_seen'] as num?)?.toInt() ?? 0;
        final bTs = (b['last_seen'] as num?)?.toInt() ?? 0;
        return bTs.compareTo(aTs);
      });

      if (devices.length > 10) {
        devices = devices.take(10).toList();
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
        });
      }
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: msgRegisterFail,
      );
      debugPrint('Error loading devices context: ${errorInfo.message}');
      _loadMessage = errorInfo.message;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSyncingDevices = false;
        });
      }
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

  String _formatRelativeTime(dynamic ts, bool isMe) {
    if (ts == null) return context.tr('util_khngr_b18ff7');
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch((ts as num).toInt());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (isMe || diff.inMinutes < 5) {
        return 'Vẫn đang hoạt động';
      }

      if (diff.inDays > 0) {
        return 'Off ${diff.inDays} ngày trước';
      } else if (diff.inHours > 0) {
        return 'Off ${diff.inHours} giờ trước';
      } else if (diff.inMinutes > 0) {
        return 'Off ${diff.inMinutes} phút trước';
      } else {
        return 'Vừa xong';
      }
    } catch (_) {
      return context.tr('util_khngr_b18ff7');
    }
  }

  Color _statusTextColor(String? status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF1B5E20);
      case 'blocked':
        return const Color(0xFFC62828);
      case 'pending':
        return const Color(0xFFE65100);
      case 'local_only':
        return SLColors.textPrimary;
      default:
        return Colors.grey;
    }
  }

  Color _statusBgColor(String? status) {
    switch (status) {
      case 'approved':
        return SLColors.successLight;
      case 'blocked':
        return SLColors.dangerLight;
      case 'pending':
        return SLColors.warningLight;
      case 'local_only':
        return SLColors.primaryLight;
      default:
        return const Color(0xFFF5F5F5);
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
      appBar: SLTheme.appBar(
        context,
        context.tr('util_qunlthitb_983ee3'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: SLColors.primary),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: SLTheme.background(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: SLColors.primary))
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SLColors.primary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: SLColors.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: SLColors.primary),
          SLSpacing.w10,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSyncing
                      ? 'Đang tải danh sách thiết bị từ máy chủ. Thiết bị bên dưới chỉ là máy hiện tại tạm thời.'
                      : message,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textPrimary,
                  ),
                ),
                if (isSyncing) ...[
                  SLSpacing.h10,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      color: SLColors.primary,
                      backgroundColor: SLColors.primaryLight,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _devices.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNoticeCard(),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  L10nService().format(
                      'util_device_showing_count', {'count': _devices.length}),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textSecond,
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

        final statusBg = _statusBgColor(status);
        final statusText = _statusTextColor(status);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isMe
                  ? const Color(0xFF007AFF).withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.04),
              width: isMe ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isMe
                    ? const Color(0xFF007AFF).withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                  type: MaterialType.transparency,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF007AFF).withValues(alpha: 0.08)
                              : statusBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _platformIcon(device['platform']),
                          color: isMe ? const Color(0xFF007AFF) : statusText,
                          size: 24,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              device['model'] ??
                                  context.tr('util_thitbkhngr_671ddb'),
                              style: SLTheme.quicksand(
                                  fontWeight: FontWeight.w900, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Thiết bị này',
                                style: SLTheme.quicksand(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF007AFF),
                                ),
                              ),
                            ),
                          if (isAdmin && !isMe)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Quản trị viên',
                                style: SLTheme.quicksand(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE65100),
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
                              style: SLTheme.quicksand(
                                  fontSize: 12, color: Colors.black54)),
                          SLSpacing.gapH(2),
                          Text(_formatRelativeTime(device['last_seen'], isMe),
                              style: SLTheme.quicksand(
                                  fontSize: 11, color: Colors.black45)),
                          if (device['ip'] != null &&
                              device['ip'] != 'unknown') ...[
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
                          SLSpacing.h8,
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: SLRadius.mdAll,
                            ),
                            child: Text(
                              _statusLabelForTile(status, device, isMe),
                              style: SLTheme.quicksand(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: statusText),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        if (canTakeAction)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.02),
                              borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(24),
                                  bottomRight: Radius.circular(24)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (status != 'approved')
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _approve(id),
                                      icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 16),
                                      label: Text(
                                        context.tr('util_duyt_a4db4d'),
                                        style: SLTheme.quicksand(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF2E7D32),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                if (status != 'approved') SLSpacing.w8,
                                if (status != 'blocked')
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _block(id),
                                      icon: const Icon(Icons.block_outlined,
                                          size: 16),
                                      label: Text(
                                        context.tr('util_chn_483b6f'),
                                        style: SLTheme.quicksand(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFEF6C00),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                if (status != 'blocked') SLSpacing.w8,
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _delete(id),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16),
                                    label: Text(
                                      context.tr('util_xa_4ed187'),
                                      style: SLTheme.quicksand(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFC62828),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!canTakeAction)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.015),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                              ),
                            ),
                            child: Text(
                              isMe
                                  ? context.tr('util_ylthitbbna_af3295')
                                  : context.tr('util_thitbhinti_7d3436'),
                              style: SLTheme.quicksand(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ))),
        );
      },
    );
  }
}
