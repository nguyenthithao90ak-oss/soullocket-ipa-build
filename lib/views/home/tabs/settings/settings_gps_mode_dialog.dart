import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../utils/services/gps_tracking_state.dart';
import '../../../../utils/services/l10n_service.dart';
import '../../../../widgets/sl_detail_widgets.dart';
import '../../../../widgets/sl_dialog.dart';

class SettingsGpsModeDialog extends StatefulWidget {
  const SettingsGpsModeDialog({
    super.key,
    required this.initialMode,
    required this.foregroundMode,
    required this.alwaysMode,
  });

  final String initialMode;
  final String foregroundMode;
  final String alwaysMode;

  @override
  State<SettingsGpsModeDialog> createState() => _SettingsGpsModeDialogState();
}

class _SettingsGpsModeDialogState extends State<SettingsGpsModeDialog> {
  late String _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) => SLAlertDialog(
    scrollable: true,
    title: SLDialogHeading(
      icon: Icons.location_on_outlined,
      title: context.tr('settings_gps_mode_title'),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('settings_gps_mode_dialog_desc')),
        const SizedBox(height: 16),
        SLDetailChoice(
          selected: _mode == widget.foregroundMode,
          title: context.tr('settings_gps_mode_foreground'),
          badge: context.tr('settings_gps_mode_recommended'),
          description: context.tr('settings_gps_mode_foreground_desc'),
          icon: Icons.battery_saver_outlined,
          onTap: () => setState(() => _mode = widget.foregroundMode),
        ),
        const SizedBox(height: 12),
        SLDetailChoice(
          selected: _mode == widget.alwaysMode,
          title: context.tr('settings_gps_mode_always'),
          description: context.tr('settings_gps_mode_always_desc'),
          warning: context.tr('settings_gps_mode_always_warning'),
          icon: Icons.location_searching_rounded,
          onTap: () => setState(() => _mode = widget.alwaysMode),
        ),
      ],
    ),
    actions: [
      SLDialogAction(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('cancel')),
      ),
      SLDialogAction(
        primary: true,
        onPressed: () => Navigator.pop(context, _mode),
        child: Text(context.tr('detail_save_changes')),
      ),
    ],
  );
}

/// Nhãn lấy từ luồng GPS/ack thật, không lấy dấu chọn trong SharedPreferences.
class SettingsGpsStatus extends StatefulWidget {
  const SettingsGpsStatus({
    super.key,
    required this.trackingState,
    required this.onTap,
    this.now,
  });

  final ValueListenable<GpsTrackingState> trackingState;
  final VoidCallback onTap;
  final DateTime Function()? now;

  @override
  State<SettingsGpsStatus> createState() => _SettingsGpsStatusState();
}

class _SettingsGpsStatusState extends State<SettingsGpsStatus>
    with WidgetsBindingObserver {
  Timer? _freshnessTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer();
  }

  void _syncTimer() {
    _freshnessTimer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      // Chỉ cập nhật tuổi dữ liệu trên UI; không tạo heartbeat hay lượt tải mạng.
      _freshnessTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncTimer();
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<GpsTrackingState>(
        valueListenable: widget.trackingState,
        builder: (context, state, _) {
          final now = (widget.now ?? DateTime.now)();
          return SLDetailStatusRow(
            icon: Icons.location_on_rounded,
            title: context.tr('settings_gps_mode_title'),
            status: context.tr(state.statusKeyAt(now)),
            ready: state.isReadyAt(now),
            onTap: widget.onTap,
          );
        },
      );
}
