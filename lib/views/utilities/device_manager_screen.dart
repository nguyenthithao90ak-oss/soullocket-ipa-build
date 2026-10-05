import 'dart:async';

import 'package:soullocket_app/widgets/sl_dialog.dart';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/device_manager_service.dart';
import '../../utils/services/device_manager_client.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/sl_notice.dart';

/// ============================================================
///  DeviceManagerScreen — GRA (UI + Logic)
///  Màn hình Quản lý Thiết bị Đăng nhập
///  Dựa theo openDeviceManager() trong bundle.js (~30415)
/// ============================================================
class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({super.key, this.client});

  final DeviceManagerClient? client;

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  late final DeviceManagerClient _svc;
  StreamSubscription<String?>? _sessionSub;
  String? _sessionUid;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;
  bool _isSyncingDevices = false;
  bool _listVerified = false;
  bool _loadFailed = false;
  bool _actionPending = false;
  String _houseId = '';
  String _currentDeviceId = '';
  String _loadMessage = '';
  int _loadRequest = 0;
  int _actionRequest = 0;
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _svc = widget.client ?? DeviceManagerService();
    _sessionUid = _svc.sessionUid;
    _sessionSub = _svc.sessionChanges.listen((uid) {
      if (!mounted || uid == _sessionUid) return;
      ++_loadRequest;
      ++_actionRequest;
      _loadFuture = null;
      setState(() {
        _sessionUid = uid;
        _devices = [];
        _houseId = '';
        _currentDeviceId = '';
        _listVerified = false;
        _loadFailed = false;
        _loadMessage = '';
        _actionPending = false;
        _isSyncingDevices = false;
      });
      unawaited(_loadDevices());
    });
    unawaited(_loadDevices());
  }

  @override
  void dispose() {
    ++_loadRequest;
    ++_actionRequest;
    _sessionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDevices() {
    final existing = _loadFuture;
    if (existing != null) return existing;
    late final Future<void> future;
    future = _loadDevicesInternal().whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
    });
    _loadFuture = future;
    return future;
  }

  Future<void> _loadDevicesInternal() async {
    if (!mounted) return;
    final request = ++_loadRequest;
    final uid = _sessionUid;
    bool isCurrent() =>
        mounted && request == _loadRequest && uid == _svc.sessionUid;
    setState(() {
      _isSyncingDevices = true;
      _listVerified = false;
      _loadFailed = false;
      _loadMessage = '';
      _isLoading = _devices.isEmpty;
    });
    try {
      if (uid == null || uid.isEmpty) {
        throw StateError(AppErrorMapper.authSyncMessage);
      }
      final currentSnapshot = await _svc.getCurrentDeviceSnapshot();
      if (!isCurrent()) return;
      final currentDeviceId = currentSnapshot['deviceId'] ?? '';
      if (currentDeviceId.isEmpty) {
        throw const FormatException('Missing device ID');
      }
      setState(() {
        _currentDeviceId = currentDeviceId;
        if (_devices.isEmpty) {
          _devices = [
            {...currentSnapshot, 'status': 'unverified', 'can_manage': false},
          ];
        }
      });
      final signalsAllowed = await _svc.isSecurityDeviceSignalsAllowed();
      if (!isCurrent()) return;
      var registrationMessage = '';
      if (signalsAllowed) {
        try {
          await _svc
              .registerCurrentDevice(throwOnError: true)
              .timeout(const Duration(seconds: 12));
        } catch (error) {
          registrationMessage = L10nService().translate(
            'device_manager_registration_failed',
          );
        }
      }
      if (!isCurrent()) return;
      final listing = await _svc.loadDeviceListing().timeout(
        const Duration(seconds: 12),
      );
      if (!isCurrent()) return;
      final devices = listing.devices
          .map((device) => Map<String, dynamic>.from(device))
          .toList();
      if (!devices.any((device) => device['deviceId'] == currentDeviceId)) {
        devices.add({
          ...currentSnapshot,
          'status': 'local_only',
          'can_manage': false,
        });
      }
      devices.sort((left, right) {
        final leftIsCurrent = left['deviceId'] == currentDeviceId;
        final rightIsCurrent = right['deviceId'] == currentDeviceId;
        if (leftIsCurrent != rightIsCurrent) return leftIsCurrent ? -1 : 1;
        final leftSeen = (left['last_seen'] as num?)?.toInt() ?? 0;
        final rightSeen = (right['last_seen'] as num?)?.toInt() ?? 0;
        return rightSeen.compareTo(leftSeen);
      });
      setState(() {
        _currentDeviceId = currentDeviceId;
        _devices = devices;
        _houseId = listing.houseId;
        _listVerified = true;
        _loadMessage = registrationMessage;
      });
    } catch (error) {
      if (!isCurrent()) return;
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate('util_chathtidan_e58038'),
      );
      setState(() {
        _loadMessage = errorInfo.message;
        _listVerified = false;
        _loadFailed = true;
      });
    } finally {
      if (isCurrent()) {
        setState(() {
          _isLoading = false;
          _isSyncingDevices = false;
        });
      }
    }
  }

  bool _canManageDevice(String id) =>
      _listVerified &&
      _houseId.isNotEmpty &&
      id.isNotEmpty &&
      id != _currentDeviceId &&
      _devices.any(
        (device) => device['deviceId'] == id && device['can_manage'] == true,
      );

  Future<void> _runDeviceAction({
    required String id,
    required Future<void> Function(String houseId) action,
    required String successMessage,
    required String failureMessage,
    String? confirmationTitle,
    String? confirmationBody,
    String? confirmationAction,
    bool destructive = false,
  }) async {
    if (!mounted ||
        _actionPending ||
        _isSyncingDevices ||
        !_canManageDevice(id)) {
      return;
    }
    final request = ++_actionRequest;
    final uid = _sessionUid;
    final houseId = _houseId;
    bool isCurrent() =>
        mounted &&
        request == _actionRequest &&
        uid == _svc.sessionUid &&
        houseId == _houseId;
    setState(() => _actionPending = true);
    try {
      if (confirmationTitle != null) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => SLAlertDialog(
            title: Text(confirmationTitle),
            content: Text(confirmationBody ?? ''),
            actions: [
              SLDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.tr('util_hy_1e4050')),
              ),
              SLDialogAction(
                primary: true,
                destructive: destructive,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmationAction ?? ''),
              ),
            ],
          ),
        );
        if (confirm != true || !isCurrent() || !_canManageDevice(id)) return;
      }
      if (!isCurrent()) return;
      await action(houseId);
      if (!isCurrent()) return;
      _showToast(successMessage);
      await _loadDevices();
    } catch (error) {
      if (!isCurrent()) return;
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: failureMessage,
      );
      _showToast(errorInfo.message);
    } finally {
      if (mounted && request == _actionRequest) {
        setState(() => _actionPending = false);
      }
    }
  }

  Future<void> _approve(String id) => _runDeviceAction(
    id: id,
    action: (houseId) => _svc.approveDevice(id, expectedHouseId: houseId),
    successMessage: context.tr('util_duytthitb_8d23d7'),
    failureMessage: context.tr('util_chathduytt_d4a412'),
    confirmationTitle: context.tr('util_duyt_a4db4d'),
    confirmationBody: context.tr('device_manager_approve_confirm'),
    confirmationAction: context.tr('util_duyt_a4db4d'),
  );

  Future<void> _block(String id) => _runDeviceAction(
    id: id,
    action: (houseId) => _svc.blockDevice(id, expectedHouseId: houseId),
    successMessage: context.tr('util_chnthitb_763bc8'),
    failureMessage: context.tr('util_chathchnth_5a7417'),
    confirmationTitle: context.tr('util_chnthitb_172ff3'),
    confirmationBody: context.tr('device_manager_block_confirm'),
    confirmationAction: context.tr('util_chn_483b6f'),
    destructive: true,
  );

  Future<void> _delete(String id) => _runDeviceAction(
    id: id,
    action: (houseId) => _svc.deleteDevice(id, expectedHouseId: houseId),
    successMessage: context.tr('util_xathitb_78ba12'),
    failureMessage: context.tr('util_chathxathi_89c942'),
    confirmationTitle: context.tr('confirm_delete'),
    confirmationBody: context.tr('device_manager_delete_confirm'),
    confirmationAction: context.tr('util_xa_4ed187'),
    destructive: true,
  );

  void _showToast(String message) {
    if (mounted) SLNotice.showInfo(context, message);
  }

  String _formatLastSeen(dynamic ts) {
    if (ts == null) return context.tr('util_khngr_b18ff7');
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch((ts as num).toInt());
      final localizations = MaterialLocalizations.of(context);
      final date = localizations.formatMediumDate(dt);
      final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dt));
      return L10nService().format('device_manager_last_seen', {
        'time': '$date $time',
      });
    } catch (_) {
      return context.tr('util_khngr_b18ff7');
    }
  }

  Color _statusTextColor(String? status) {
    switch (status) {
      case 'approved':
      case 'auto_approved':
        return const Color(0xFF1B5E20);
      case 'blocked':
      case 'deleted':
        return const Color(0xFFC62828);
      case 'pending':
        return const Color(0xFFE65100);
      case 'local_only':
      case 'unverified':
        return SLColors.textPrimary;
      default:
        return Colors.grey;
    }
  }

  Color _statusBgColor(String? status) {
    switch (status) {
      case 'approved':
      case 'auto_approved':
        return SLColors.successLight;
      case 'blocked':
      case 'deleted':
        return SLColors.dangerLight;
      case 'pending':
        return SLColors.warningLight;
      case 'local_only':
      case 'unverified':
        return SLColors.primaryLight;
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'approved':
      case 'auto_approved':
        return context.tr('util_duyt_e451b6');
      case 'blocked':
        return context.tr('util_chn_7c554a');
      case 'deleted':
        return context.tr('util_xathitb_78ba12');
      case 'pending':
        return context.tr('util_chduyt_acb8dc');
      case 'local_only':
        return context.tr('util_chtrnmyny_838a8e');
      case 'unverified':
        return context.tr('device_manager_device_unverified');
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
      return L10nService().translate(
        'ui_utilities_verifying_with_server_09cfa0',
      );
    }
    return _statusLabel(status);
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
            tooltip: context.tr('util_tili_13be6c'),
            onPressed: _isSyncingDevices || _actionPending
                ? null
                : _loadDevices,
          ),
        ],
      ),
      body: SLTheme.background(
        themeKey: 'off',
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: SLColors.primary),
              )
            : _devices.isEmpty
            ? _buildEmpty()
            : _buildList(),
      ),
    );
  }

  Widget _buildNoticeCard() {
    final message = _loadMessage.trim().isNotEmpty
        ? _loadMessage.trim()
        : context.tr('device_manager_status_notice');
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
          Icon(
            _loadFailed ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
            color: SLColors.primary,
          ),
          SLSpacing.w10,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSyncing
                      ? context.tr(
                          'ui_utilities_loading_device_list_from_server_the_device_57c1c7',
                        )
                      : _loadFailed
                      ? context.tr('device_manager_load_failed_title')
                      : message,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textPrimary,
                  ),
                ),
                if (_loadFailed) ...[
                  SLSpacing.h10,
                  Text(
                    message,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      height: 1.45,
                      color: SLColors.textPrimary,
                    ),
                  ),
                ],
                if (_loadFailed || _loadMessage.trim().isNotEmpty) ...[
                  SLSpacing.h10,
                  Text(
                    context.tr(
                      _loadFailed
                          ? 'device_manager_load_failed_body'
                          : 'device_manager_status_notice',
                    ),
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      height: 1.45,
                      color: SLColors.textSecond,
                    ),
                  ),
                ],
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildNoticeCard(),
        const Icon(Icons.devices_other, size: 72, color: Color(0xFFD81B60)),
        SLSpacing.h16,
        Text(
          context.tr(
            _loadFailed
                ? 'device_manager_load_failed_title'
                : 'device_manager_empty',
          ),
          style: SLTheme.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceActions(String id, String? status) {
    final busy = _actionPending || _isSyncingDevices;
    final actions =
        <
          ({
            String label,
            IconData icon,
            Color color,
            VoidCallback onTap,
            String key,
          })
        >[
          if (status == 'pending' || status == 'blocked' || status == 'deleted')
            (
              label: context.tr('util_duyt_a4db4d'),
              icon: Icons.check_circle_outline,
              color: const Color(0xFF2E7D32),
              onTap: () => _approve(id),
              key: 'device-approve-$id',
            ),
          if (status != 'blocked' && status != 'deleted')
            (
              label: context.tr('util_chn_483b6f'),
              icon: Icons.block_outlined,
              color: const Color(0xFFEF6C00),
              onTap: () => _block(id),
              key: 'device-block-$id',
            ),
          if (status != 'deleted')
            (
              label: context.tr('util_xa_4ed187'),
              icon: Icons.delete_outline_rounded,
              color: const Color(0xFFC62828),
              onTap: () => _delete(id),
              key: 'device-delete-$id',
            ),
        ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(13) > 18;
        final width = stack
            ? constraints.maxWidth
            : (constraints.maxWidth - (actions.length - 1) * 8) /
                  actions.length;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: ElevatedButton.icon(
                  key: ValueKey(action.key),
                  onPressed: busy ? null : action.onTap,
                  icon: Icon(action.icon, size: 16),
                  label: Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: action.color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
                  L10nService().format('util_device_showing_count', {
                    'count': _devices.length,
                  }),
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
        final canTakeAction = _canManageDevice(id);

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
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('device-tile-$id'),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device['model'] ?? context.tr('util_thitbkhngr_671ddb'),
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isMe)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF007AFF,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            context.tr('ui_utilities_this_device_870b01'),
                            style: SLTheme.quicksand(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SLSpacing.h4,
                      Text(
                        device['os'] ?? '',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      SLSpacing.gapH(2),
                      Text(
                        _formatLastSeen(device['last_seen']),
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                      if (device['ip'] != null &&
                          device['ip'] != 'unknown') ...[
                        SLSpacing.gapH(2),
                        Text(
                          L10nScope.of(context).format(
                            'ui_utilities_ip_value1_cf7f6d',
                            {'value1': device['ip']},
                          ),
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                      if (device['location'] != null &&
                          device['location'] != 'unknown') ...[
                        SLSpacing.gapH(2),
                        Text(
                          L10nService().format('util_device_location', {
                            'location': device['location'],
                          }),
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                      SLSpacing.h8,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: SLRadius.mdAll,
                        ),
                        child: Text(
                          _statusLabelForTile(status, device, isMe),
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: statusText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    if (canTakeAction)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.02),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: _buildDeviceActions(id, status),
                      ),
                    if (!canTakeAction)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
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
                              : status == 'deleted'
                              ? _statusLabel(status)
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
              ),
            ),
          ),
        );
      },
    );
  }
}
