import 'package:flutter/material.dart';

import '../../../../utils/services/l10n_service.dart';
import '../../../../widgets/sl_dialog.dart';

/// Chỉ nhắc nghỉ; không đếm ngược, tự đóng màn hoặc đưa app về nền.
class HomeInactivityReminderDialog extends StatelessWidget {
  const HomeInactivityReminderDialog({super.key});

  @override
  Widget build(BuildContext context) => SLAlertDialog(
    title: Text(context.tr('home_khonghd_inactivity')),
    content: Text(context.tr('home_inactivity_reminder_body')),
    actions: [
      SLDialogAction(
        primary: true,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr('continue_action')),
      ),
    ],
  );
}
