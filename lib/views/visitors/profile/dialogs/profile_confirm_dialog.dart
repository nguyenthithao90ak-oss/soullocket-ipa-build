import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/l10n_service.dart';

Future<bool> showVisitorProfileConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
          title: Text(
            title,
            style: SLTheme.quicksand(fontWeight: FontWeight.w900),
          ),
          content: Text(
            message,
            style: SLTheme.quicksand(
              fontSize: 14,
              height: 1.5,
              color: SLColors.textSecond,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                context.tr('p5_cancel'),
                style: SLTheme.quicksand(color: SLColors.textSecond),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SLColors.danger,
                shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.tr('p5_confirm'),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;
}
