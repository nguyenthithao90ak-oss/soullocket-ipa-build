import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/services/l10n_service.dart';
import 'diary_composer_art.dart';

/// Giữ nút kết thúc nhập ở ngoài phần cuộn, ngay trên bàn phím.
class DiaryKeyboardDismissArea extends StatefulWidget {
  const DiaryKeyboardDismissArea({super.key, required this.child});

  final Widget child;

  @override
  State<DiaryKeyboardDismissArea> createState() =>
      _DiaryKeyboardDismissAreaState();
}

class _DiaryKeyboardDismissAreaState extends State<DiaryKeyboardDismissArea> {
  final _focusScope = FocusScopeNode();

  @override
  void dispose() {
    _focusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = DiaryComposerPalette.of(context);
    return AnimatedBuilder(
      animation: FocusManager.instance,
      child: FocusScope(node: _focusScope, child: widget.child),
      builder: (context, child) {
        // Scaffold ngoài đã tiêu thụ viewInsets; dùng focus để cả bàn phím
        // bên thứ ba, bàn phím nổi và bố cục Scaffold lồng nhau đều có nút.
        final isEditing = _focusScope.hasFocus && !_focusScope.hasPrimaryFocus;
        return Column(
          children: [
            Expanded(child: child!),
            if (isEditing)
              TextFieldTapRegion(
                child: Material(
                  color: palette.paper,
                  elevation: 3,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          key: const ValueKey('diary-keyboard-done'),
                          onPressed: _focusScope.unfocus,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.ink,
                            minimumSize: const Size(48, 48),
                            textStyle: SLTheme.quicksand(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          icon: const Icon(Icons.keyboard_hide_rounded),
                          label: Text(context.tr('core_done')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
