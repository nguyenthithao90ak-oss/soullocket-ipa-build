import 'dart:async';

import 'package:soullocket_app/widgets/sl_dialog.dart';

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'widgets/device_manager_design.dart';
import 'widgets/keepsake_design.dart';
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
  Map<String, dynamic> _management = const {};
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
        _management = const {};
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
        _isLoading = false;
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
        _management = listing.management;
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
      _management['canManage'] != false &&
      id.isNotEmpty &&
      id != _currentDeviceId &&
      _devices.any(
        (device) =>
            device['deviceId'] == id &&
            device['can_manage'] == true &&
            device['protected'] != true,
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

  String? _formatTimestamp(dynamic ts) {
    if (ts is! num || !ts.isFinite || ts <= 0 || ts > 4102444800000) {
      return null;
    }
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
      final localizations = MaterialLocalizations.of(context);
      final date = localizations.formatFullDate(dt);
      final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dt));
      return '$date $time';
    } catch (_) {
      return null;
    }
  }

  String _formatLastSeen(dynamic ts) {
    final timestamp = _formatTimestamp(ts);
    return timestamp == null
        ? context.tr('util_khngr_b18ff7')
        : L10nScope.of(
            context,
          ).format('device_manager_last_seen', {'time': timestamp});
  }

  String _managementMessage(Map<String, dynamic> device, bool isMe) {
    if (device['protected'] == true) {
      return context.tr('device_manager_creator_protected');
    }
    switch (device['management_reason']) {
      case 'target_unverified':
        return context.tr('device_manager_legacy_protected');
      case 'actor_new':
        return context.tr('device_manager_device_too_new');
      case 'actor_revoked':
        return context.tr('device_manager_device_revoked');
      case 'actor_unverified':
        return context.tr('device_manager_device_unverified_permission');
    }
    return isMe
        ? context.tr('util_ylthitbbna_af3295')
        : device['status'] == 'deleted'
        ? _statusLabel('deleted')
        : context.tr('util_thitbhinti_7d3436');
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
    if (_isSyncingDevices &&
        isMe &&
        (status == 'local_only' || status == 'unverified')) {
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
      backgroundColor: KeepsakeStyle.canvas(context),
      appBar: KeepsakeStyle.appBar(
        context,
        title: Text(context.tr('util_qunlthitb_983ee3')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.tr('util_tili_13be6c'),
            onPressed: _isSyncingDevices || _actionPending
                ? null
                : _loadDevices,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: KeepsakeStyle.accent(context),
                ),
              )
            : _devices.isEmpty
            ? _buildEmpty()
            : _buildList(),
      ),
    );
  }

  Widget _buildNoticeCard() => DeviceRegistryNotice(
    title: _isSyncingDevices
        ? context.tr(
            'ui_utilities_loading_device_list_from_server_the_device_57c1c7',
          )
        : _loadFailed
        ? context.tr('device_manager_load_failed_title')
        : null,
    detail: _loadMessage.trim().isEmpty ? null : _loadMessage.trim(),
    message: context.tr(
      _loadFailed
          ? 'device_manager_load_failed_body'
          : 'device_manager_status_notice',
    ),
    syncing: _isSyncingDevices,
    failed: _loadFailed,
  );

  Widget _buildEmpty() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _buildNoticeCard(),
      const SizedBox(height: 28),
      Icon(
        Icons.devices_other_rounded,
        size: 48,
        color: KeepsakeStyle.muted(context),
      ),
      const SizedBox(height: 14),
      if (!_loadFailed)
        Text(
          context.tr('device_manager_empty'),
          textAlign: TextAlign.center,
          style: KeepsakeStyle.text(context, size: 15, weight: FontWeight.w600),
        ),
    ],
  );

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
              icon: Icons.check_circle_outline_rounded,
              color: DeviceManagerStyle.statusColor(context, 'approved'),
              onTap: () => _approve(id),
              key: 'device-approve-$id',
            ),
          if (status != 'blocked' && status != 'deleted')
            (
              label: context.tr('util_chn_483b6f'),
              icon: Icons.block_rounded,
              color: DeviceManagerStyle.statusColor(context, 'pending'),
              onTap: () => _block(id),
              key: 'device-block-$id',
            ),
          if (status != 'deleted')
            (
              label: context.tr('util_xa_4ed187'),
              icon: Icons.delete_outline_rounded,
              color: DeviceManagerStyle.statusColor(context, 'deleted'),
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
                child: OutlinedButton.icon(
                  key: ValueKey(action.key),
                  onPressed: busy ? null : action.onTap,
                  icon: Icon(action.icon, size: 17),
                  label: Text(action.label, textAlign: TextAlign.center),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: action.color,
                    backgroundColor: action.color.withValues(alpha: 0.05),
                    side: BorderSide(
                      color: action.color.withValues(alpha: 0.3),
                    ),
                    textStyle: KeepsakeStyle.text(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
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

  Widget _buildList() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    itemCount: _devices.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10nScope.of(
                context,
              ).format('util_device_showing_count', {'count': _devices.length}),
              style: KeepsakeStyle.text(
                context,
                size: 20,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('device_manager_list_hint'),
              style: KeepsakeStyle.text(
                context,
                size: 12,
                color: KeepsakeStyle.muted(context),
              ),
            ),
            const SizedBox(height: 16),
            _buildNoticeCard(),
            const SizedBox(height: 16),
          ],
        );
      }
      final device = _devices[index - 1];
      final status = device['status'] as String?;
      final id = device['deviceId'] as String? ?? '';
      final isMe = id == _currentDeviceId;
      final canTakeAction = _canManageDevice(id);
      final model = device['model']?.toString().trim() ?? '';
      final statusColor = DeviceManagerStyle.statusColor(context, status);
      final ip = device['ip']?.toString().trim() ?? '';
      final location = device['location']?.toString().trim() ?? '';
      final trustRole = device['trust_role'];
      final trustLabel = switch (trustRole) {
        'creator' => 'device_manager_role_creator',
        'new' => 'device_manager_role_new',
        'established' => 'device_manager_role_established',
        'unverified' => 'device_manager_role_unverified',
        _ => null,
      };
      final registeredAt = _formatTimestamp(device['trust_since']);
      final manageAfter = isMe
          ? _formatTimestamp(_management['manageAfter'])
          : null;

      return DeviceRegistryCard(
        key: ValueKey('device-card-$id'),
        deviceId: id,
        model: model.isEmpty ? context.tr('util_thitbkhngr_671ddb') : model,
        os: device['os'] ?? '',
        platformIcon: _platformIcon(device['platform']),
        current: isMe,
        badges: [
          if (isMe)
            DeviceStatusBadge(
              label: context.tr('ui_utilities_this_device_870b01'),
              icon: Icons.person_outline_rounded,
              color: KeepsakeStyle.accent(context),
            ),
          DeviceStatusBadge(
            label: _statusLabelForTile(status, device, isMe),
            icon: DeviceManagerStyle.statusIcon(status),
            color: statusColor,
          ),
          if (trustLabel != null)
            DeviceStatusBadge(
              label: context.tr(trustLabel),
              icon: trustRole == 'creator'
                  ? Icons.verified_user_outlined
                  : trustRole == 'new'
                  ? Icons.schedule_rounded
                  : Icons.shield_outlined,
              color: KeepsakeStyle.accent(context),
            ),
        ],
        details: [
          DeviceInformationRow(
            icon: Icons.history_rounded,
            text: _formatLastSeen(device['last_seen']),
          ),
          if (registeredAt != null)
            DeviceInformationRow(
              icon: Icons.event_outlined,
              text: L10nScope.of(
                context,
              ).format('device_manager_registered_at', {'time': registeredAt}),
            ),
          if (manageAfter != null)
            DeviceInformationRow(
              icon: Icons.lock_clock_outlined,
              text: L10nScope.of(
                context,
              ).format('device_manager_manage_after', {'time': manageAfter}),
            ),
          if (ip.isNotEmpty && ip != 'unknown')
            DeviceInformationRow(
              icon: Icons.language_rounded,
              text: L10nScope.of(
                context,
              ).format('ui_utilities_ip_value1_cf7f6d', {'value1': ip}),
            ),
          if (location.isNotEmpty && location != 'unknown')
            DeviceInformationRow(
              icon: Icons.location_on_outlined,
              text: L10nScope.of(
                context,
              ).format('util_device_location', {'location': location}),
            ),
          const SizedBox(height: 4),
          if (canTakeAction)
            _buildDeviceActions(id, status)
          else
            Text(
              _managementMessage(device, isMe),
              style: KeepsakeStyle.text(
                context,
                size: 12,
                color: KeepsakeStyle.muted(context),
              ),
            ),
          if (isMe) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('device_manager_policy_hint'),
              style: KeepsakeStyle.text(
                context,
                size: 12,
                color: KeepsakeStyle.muted(context),
              ),
            ),
          ],
        ],
      );
    },
  );
}
