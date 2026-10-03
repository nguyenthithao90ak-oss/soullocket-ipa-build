import 'package:flutter/material.dart';

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
