import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';

/// Nhắc người vừa ghép đôi đặt tên của mình một lần, khi vị trí của mình trong
/// nhà vẫn là tên mặc định ("Bạn Nam"/"Bạn Nữ" hoặc bản dịch). Chỉ lưu dấu đã
/// nhắc trên máy theo UID + House; tên vẫn được ghi qua luồng đổi biệt danh
/// sẵn có ở Home nên không thêm đường ghi dữ liệu mới.
class PairingNamePrompt {
  PairingNamePrompt._();

  static const int maxNameChars = 30;

  /// Giá trị createHouseSecure ghi khi app không gửi tên (không hiển thị ra UI).
  static const Set<String> serverDefaultNames = {'Bạn Nam', 'Bạn Nữ'};

  /// Khóa dịch của nhãn mặc định hai vai (RoleUtils.defaultNameKey và nhãn
  /// Home dùng khi chưa có tên).
  static const List<String> defaultNameKeys = [
    'home_bnnam_123ef2',
    'home_bnn_babaec',
    'home_default_male',
    'home_default_female',
  ];

  static String prefsKey(String uid, String houseId) =>
      'pairing_name_prompt_shown_v1_${uid}_$houseId';

  static bool isDefaultName(String? name, Iterable<String> localizedDefaults) {
    final value = (name ?? '').trim();
    if (value.isEmpty || serverDefaultNames.contains(value)) return true;
    return localizedDefaults.any((label) => label.trim() == value);
  }

  static Future<bool> wasShown(String uid, String houseId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey(uid, houseId)) ?? false;
  }

  static Future<void> markShown(String uid, String houseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey(uid, houseId), true);
  }

  /// Trả về tên đã nhập, hoặc null khi người dùng chọn để sau.
  static Future<String?> show(
    BuildContext context, {
    required String defaultLabel,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _PairingNamePromptDialog(defaultLabel: defaultLabel),
    );
  }
}

class _PairingNamePromptDialog extends StatefulWidget {
  const _PairingNamePromptDialog({required this.defaultLabel});

  final String defaultLabel;

  @override
  State<_PairingNamePromptDialog> createState() =>
      _PairingNamePromptDialogState();
}

class _PairingNamePromptDialogState extends State<_PairingNamePromptDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String get _name => _controller.text.trim();

  void _submit() {
    if (_name.isEmpty) return;
    Navigator.of(context).pop(_name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    return SLAlertDialog(
      title: Text(
        l10n.translate('pairing_name_prompt_title'),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.format('pairing_name_prompt_body', {
                'name': widget.defaultLabel,
              }),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('pairing-name-prompt-field'),
              controller: _controller,
              autofocus: true,
              maxLength: PairingNamePrompt.maxNameChars,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
              decoration: InputDecoration(
                hintText: l10n.translate('pairing_name_prompt_hint'),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: SLTheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        SLDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.translate('pairing_name_prompt_later')),
        ),
        SLDialogAction(
          primary: true,
          onPressed: _name.isEmpty ? null : _submit,
          child: Text(l10n.translate('pairing_name_prompt_save')),
        ),
      ],
    );
  }
}
