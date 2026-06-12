import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../services/l10n_service.dart';

class ForgotGmailDialog extends StatefulWidget {
  final Function(String) onNext;

  const ForgotGmailDialog({super.key, required this.onNext});

  @override
  State<ForgotGmailDialog> createState() => _ForgotGmailDialogState();
}

class _ForgotGmailDialogState extends State<ForgotGmailDialog> {
  final TextEditingController _hIdCtrl = TextEditingController();

  @override
  void dispose() {
    _hIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Text('QUÊN GMAIL',
          style: SLTheme.quicksand(
              color: SLColors.primaryActive,
              fontWeight: FontWeight.bold,
              fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(L10nService().translate('Vui lòng nhập mã nhà của bạn:'),
              style: SLTheme.quicksand(fontSize: 14)),
          const SizedBox(height: 16),
          TextField(
            controller: _hIdCtrl,
            autofocus: true,
            style: SLTheme.quicksand(),
            decoration: InputDecoration(
              hintText: 'VD: NH_...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10nService().translate('Hủy'),
                style: SLTheme.quicksand())),
        ElevatedButton(
            onPressed: () => widget.onNext(_hIdCtrl.text.trim()),
            child: Text(L10nService().translate('Tiếp theo'),
                style: SLTheme.quicksand())),
      ],
    );
  }
}
