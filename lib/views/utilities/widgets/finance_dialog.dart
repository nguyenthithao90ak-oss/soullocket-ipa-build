import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import 'finance_design.dart';

/// Hộp thoại riêng của Tài chính dùng cùng theme với dashboard.
class FinanceDialog extends AlertDialog {
  const FinanceDialog({
    super.key,
    super.title,
    super.content,
    super.actions,
    super.insetPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 24,
    ),
    super.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = FinancePalette.ink(context);
    final muted = FinancePalette.muted(context);
    final surface = FinancePalette.surface(context);
    final field = FinancePalette.mutedSurface(context);
    final border = FinancePalette.border(context);
    final rose = FinancePalette.accent(context, FinancePalette.rose);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: rose,
          onPrimary: FinancePalette.dark(context)
              ? SLColors.darkBgMain
              : Colors.white,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerHighest: field,
          outline: border,
        ),
        iconTheme: IconThemeData(color: rose),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: rose,
          selectionColor: rose.withValues(alpha: 0.2),
          selectionHandleColor: rose,
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: field,
          labelStyle: TextStyle(color: muted),
          hintStyle: TextStyle(color: muted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: rose, width: 1.5),
          ),
        ),
        dialogTheme: theme.dialogTheme.copyWith(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          constraints: const BoxConstraints(maxWidth: 440),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: border),
          ),
          titleTextStyle: FinancePalette.text(
            context,
            size: 21,
            weight: FontWeight.w800,
          ),
          contentTextStyle: FinancePalette.text(
            context,
            size: 14,
            color: muted,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        ),
      ),
      child: Builder(builder: (context) => super.build(context)),
    );
  }
}

class FinanceDialogAction extends StatelessWidget {
  const FinanceDialogAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.primary = false,
    this.destructive = false,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = FinancePalette.accent(
      context,
      destructive ? const Color(0xFFAC4E54) : FinancePalette.rose,
    );
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(96, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        foregroundColor: primary
            ? (FinancePalette.dark(context)
                  ? SLColors.darkBgMain
                  : Colors.white)
            : color,
        backgroundColor: primary ? color : FinancePalette.mutedSurface(context),
        textStyle: FinancePalette.text(context, weight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: child,
    );
  }
}

class FinanceSplitBillForm extends StatelessWidget {
  const FinanceSplitBillForm({
    super.key,
    required this.amountController,
    required this.peopleController,
    required this.onChanged,
    this.resultText,
  });
  final TextEditingController amountController;
  final TextEditingController peopleController;
  final VoidCallback onChanged;
  final String? resultText;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _FinanceDialogField(
        label: context.tr('util_tngstinvnd_59805c'),
        controller: amountController,
        inputKey: const ValueKey('finance-split-amount'),
        icon: Icons.receipt_long_rounded,
        maxLength: 12,
        autofocus: true,
        onChanged: onChanged,
        action: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      _FinanceDialogField(
        label: context.tr('util_sngichia_91ed4e'),
        controller: peopleController,
        inputKey: const ValueKey('finance-split-people'),
        icon: Icons.group_outlined,
        maxLength: 4,
        onChanged: onChanged,
        action: TextInputAction.done,
      ),
      if (resultText != null) ...[
        const SizedBox(height: 20),
        Container(
          key: const ValueKey('finance-split-result'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FinancePalette.mutedSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FinancePalette.border(context)),
          ),
          child: Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  color: FinancePalette.accent(context, FinancePalette.rose),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  resultText!,
                  textAlign: TextAlign.center,
                  style: FinancePalette.text(
                    context,
                    size: 18,
                    weight: FontWeight.w800,
                    color: FinancePalette.accent(context, FinancePalette.rose),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

class _FinanceDialogField extends StatelessWidget {
  const _FinanceDialogField({
    required this.label,
    required this.controller,
    required this.inputKey,
    required this.icon,
    required this.maxLength,
    required this.onChanged,
    required this.action,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController controller;
  final Key inputKey;
  final IconData icon;
  final int maxLength;
  final VoidCallback onChanged;
  final TextInputAction action;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: FinancePalette.text(context, size: 13, weight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Semantics(
        label: label,
        child: TextField(
          key: inputKey,
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: action,
          autofocus: autofocus,
          maxLength: maxLength,
          style: FinancePalette.text(context),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: FinancePalette.accent(context, FinancePalette.rose),
            ),
            counterText: '',
          ),
          scrollPadding: const EdgeInsets.only(bottom: 24),
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => action == TextInputAction.next
              ? FocusScope.of(context).nextFocus()
              : FocusScope.of(context).unfocus(),
        ),
      ),
    ],
  );
}
