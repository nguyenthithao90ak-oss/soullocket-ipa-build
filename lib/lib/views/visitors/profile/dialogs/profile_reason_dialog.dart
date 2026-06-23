import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';

Future<String?> showVisitorProfileReasonDialog({
  required BuildContext context,
  required String hint,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: SLRadius.xlAll),
      title: Text(
        'Báo cáo',
        style: SLTheme.quicksand(fontWeight: FontWeight.w900),
      ),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: SLTheme.quicksand(color: SLColors.textTertiary),
          border: OutlineInputBorder(borderRadius: SLRadius.lgAll),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            'Hủy',
            style: SLTheme.quicksand(color: SLColors.textSecond),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: SLColors.primary,
            shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
          ),
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(
            'Gửi',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
