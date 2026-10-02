import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/l10n_service.dart';

Future<String?> showVisitorProfileReasonDialog({
  required BuildContext context,
  required String hint,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => SLAlertDialog(
      title: Text(context.tr('p5_profile_report')),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: SLTheme.quicksand(color: SLColors.textTertiary),
          border: OutlineInputBorder(borderRadius: SLRadius.lgAll),
        ),
      ),
      actions: [
        SLDialogAction(
          onPressed: () => Navigator.pop(context, null),
          child: Text(context.tr('p5_cancel')),
        ),
        SLDialogAction(
          primary: true,

          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(context.tr('p5_send')),
        ),
      ],
    ),
  );
}
