import 'package:flutter/material.dart';
import '../../../widgets/sl_dialog.dart';

/// Khung mở khóa toàn màn hình, cuộn được khi bàn phím hoặc chữ lớn xuất hiện.
class VaultAccessSurface extends StatelessWidget {
  const VaultAccessSurface({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.insetPadding,
    this.scrollable = true,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final EdgeInsets? insetPadding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0B1220),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 56,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF172642),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF62D9FF),
                              size: 46,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          color: Color(0xFFF3F7FF),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        child: title,
                      ),
                      const SizedBox(height: 28),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FD),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: content,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Action chính xuất hiện trước, các lựa chọn phụ ở dưới.
                      for (final action in actions.reversed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.fromSeed(
                                  seedColor: const Color(0xFF2479A8),
                                ),
                              ),
                              child: action is SLDialogAction
                                  ? TextButton(
                                      onPressed: action.onPressed,
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size.fromHeight(54),
                                        backgroundColor: action.primary
                                            ? const Color(0xFF62D9FF)
                                            : const Color(0xFF172642),
                                        foregroundColor: action.primary
                                            ? const Color(0xFF0B1220)
                                            : const Color(0xFFF3F7FF),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: action.child,
                                    )
                                  : action,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
