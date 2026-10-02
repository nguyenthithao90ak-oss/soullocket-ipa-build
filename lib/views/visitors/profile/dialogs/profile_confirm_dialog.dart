import 'package:flutter/material.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';

import '../../../../utils/services/l10n_service.dart';

Future<bool> showVisitorProfileConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => SLAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            SLDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('p5_cancel')),
            ),
            SLDialogAction(
              primary: true,
              destructive: true,

              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('p5_confirm')),
            ),
          ],
        ),
      ) ??
      false;
}
