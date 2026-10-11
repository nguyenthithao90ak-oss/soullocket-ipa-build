import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/finance_category.dart';
import '../../../utils/services/l10n_service.dart';

/// Các widget chỉ trình bày dữ liệu và gửi thao tác về FinanceScreen.
abstract final class FinancePalette {
  static const rose = Color(0xFFC0526B);
  static const sage = Color(0xFF347563);
  static const gold = Color(0xFF9B7232);
  static const lavender = Color(0xFF8066B8);

  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color canvas(BuildContext context) =>
      dark(context) ? SLColors.darkBgMain : const Color(0xFFFAF5F0);
  static Color surface(BuildContext context) =>
      dark(context) ? SLColors.darkBgCard : SLColors.paper;
  static Color mutedSurface(BuildContext context) =>
      dark(context) ? SLColors.darkBgElevated : const Color(0xFFF7F1EB);
  static Color ink(BuildContext context) =>
      dark(context) ? SLColors.darkTextPrimary : SLColors.ink;
  static Color muted(BuildContext context) =>
      dark(context) ? SLColors.darkTextSecond : SLColors.textSecond;
  static Color border(BuildContext context) =>
      dark(context) ? SLColors.darkBorder : const Color(0xFFEDE1D8);
  static Color accent(BuildContext context, Color color) =>
      dark(context) ? Color.lerp(color, Colors.white, 0.40)! : color;

  static TextStyle text(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) => SLTheme.quicksand(
    color: color ?? ink(context),
    fontSize: size,
    fontWeight: weight,
    height: 1.35,
  );

  static Duration motion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 240);

  static InputDecoration input(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) => InputDecoration(
    labelText: label,
    labelStyle: text(context, size: 13, color: muted(context)),
    prefixIcon: Icon(icon, size: 20, color: accent(context, rose)),
    filled: true,
    fillColor: mutedSurface(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    counterText: '',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: border(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: border(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accent(context, rose), width: 1.5),
    ),
  );
}

class FinanceCard extends StatelessWidget {
  const FinanceCard({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final Color? tint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: tint == null
          ? FinancePalette.surface(context)
          : Color.alphaBlend(
              tint!.withValues(
                alpha: FinancePalette.dark(context) ? 0.09 : 0.045,
              ),
              FinancePalette.surface(context),
            ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: FinancePalette.border(context)),
      boxShadow: [
        BoxShadow(
          color: const Color(
            0xFF4B3029,
          ).withValues(alpha: FinancePalette.dark(context) ? 0.10 : 0.035),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class FinanceSectionTitle extends StatelessWidget {
  const FinanceSectionTitle({super.key, required this.label, this.count});
  final String label;
  final String? count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: FinancePalette.text(
              context,
              size: 17,
              weight: FontWeight.w800,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FinancePalette.mutedSurface(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(count!, style: FinancePalette.text(context, size: 12)),
          ),
        ],
      ],
    ),
  );
}

class FinanceBalanceCard extends StatelessWidget {
  const FinanceBalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
    required this.currency,
    this.negative = false,
  });
  final String balance;
  final String income;
  final String expense;
  final String currency;
  final bool negative;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: FinancePalette.dark(context)
            ? const [Color(0xFF3B2C35), Color(0xFF30262F)]
            : const [Color(0xFFFBE3DD), Color(0xFFFFF0E3)],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: FinancePalette.dark(context)
            ? const Color(0xFF61424D)
            : const Color(0xFFF2D5CA),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('total_balance'),
                    style: FinancePalette.text(
                      context,
                      size: 16,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('finance_balance_caption'),
                    style: FinancePalette.text(
                      context,
                      size: 12,
                      color: FinancePalette.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const ExcludeSemantics(child: FinanceWalletArt(size: 66)),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          label: balance,
          child: ExcludeSemantics(
            child: SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  balance,
                  key: const ValueKey('finance-balance-amount'),
                  style:
                      FinancePalette.text(
                        context,
                        size: 33,
                        weight: FontWeight.w800,
                        color: negative
                            ? FinancePalette.accent(
                                context,
                                FinancePalette.rose,
                              )
                            : FinancePalette.ink(context),
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(14) > 21;
            final incoming = _FinanceFlowSummary(
              label: context.tr('finance_income_label'),
              value: income,
              icon: Icons.south_west_rounded,
              color: FinancePalette.sage,
            );
            final outgoing = _FinanceFlowSummary(
              label: context.tr('finance_expense_label'),
              value: expense,
              icon: Icons.north_east_rounded,
              color: FinancePalette.rose,
            );
            if (stacked) {
              return Column(
                children: [incoming, const SizedBox(height: 8), outgoing],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: incoming),
                const SizedBox(width: 10),
                Expanded(child: outgoing),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _FinanceFlowSummary extends StatelessWidget {
  const _FinanceFlowSummary({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: FinancePalette.surface(context).withValues(alpha: 0.80),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: FinancePalette.accent(context, color)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: FinancePalette.text(
                  context,
                  size: 12,
                  color: FinancePalette.muted(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: FinancePalette.text(
            context,
            size: 13,
            weight: FontWeight.w800,
            color: FinancePalette.accent(context, color),
          ),
        ),
      ],
    ),
  );
}

class FinanceActionCard extends StatelessWidget {
  const FinanceActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: FinancePalette.surface(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: FinancePalette.border(context)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _FinanceIcon(icon: icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FinancePalette.text(
                        context,
                        size: 14,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: FinancePalette.text(
                        context,
                        size: 12,
                        color: FinancePalette.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.add_rounded,
                size: 22,
                color: FinancePalette.accent(context, color),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FinanceGoalCard extends StatelessWidget {
  const FinanceGoalCard({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.currentText,
    required this.targetText,
    required this.progress,
    required this.status,
    required this.onEdit,
    required this.onDelete,
    required this.editLabel,
    required this.deleteLabel,
    this.hint,
    this.color = FinancePalette.gold,
    this.icon = Icons.savings_outlined,
  });
  final String title;
  final String eyebrow;
  final String currentText;
  final String targetText;
  final String status;
  final String? hint;
  final double progress;
  final Color color;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final accent = FinancePalette.accent(context, color);
    return FinanceCard(
      tint: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceIcon(icon: icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: FinancePalette.text(
                        context,
                        size: 11,
                        color: FinancePalette.muted(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: FinancePalette.text(
                        context,
                        size: 15,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<bool>(
                tooltip: editLabel,
                onSelected: (edit) => edit ? onEdit() : onDelete(),
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: FinancePalette.muted(context),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(value: true, child: Text(editLabel)),
                  PopupMenuItem(value: false, child: Text(deleteLabel)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentText,
            style: FinancePalette.text(
              context,
              size: 14,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            targetText,
            style: FinancePalette.text(
              context,
              size: 12,
              color: FinancePalette.muted(context),
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.clamp(0, 1)),
            duration: FinancePalette.motion(context),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: accent.withValues(alpha: 0.12),
              color: accent,
              semanticsLabel: status,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon == Icons.savings_outlined
                    ? Icons.auto_awesome_rounded
                    : Icons.schedule_rounded,
                size: 15,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  status,
                  style: FinancePalette.text(
                    context,
                    size: 12,
                    weight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: FinancePalette.text(
                context,
                size: 11,
                color: FinancePalette.muted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FinanceComposer extends StatelessWidget {
  const FinanceComposer({
    super.key,
    required this.type,
    required this.category,
    required this.currency,
    required this.amountController,
    required this.noteController,
    required this.onType,
    required this.onCategory,
    required this.onSave,
    this.saving = false,
  });
  final String type;
  final String category;
  final String currency;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final ValueChanged<String> onType;
  final ValueChanged<String> onCategory;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final isIncome = type == 'in';
    final accent = FinancePalette.accent(
      context,
      isIncome ? FinancePalette.sage : FinancePalette.rose,
    );
    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: FinancePalette.mutedSurface(context),
              borderRadius: BorderRadius.circular(17),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final incoming = _typeButton(
                  context,
                  'in',
                  Icons.add_rounded,
                  FinancePalette.sage,
                );
                final outgoing = _typeButton(
                  context,
                  'out',
                  Icons.remove_rounded,
                  FinancePalette.rose,
                );
                if (MediaQuery.textScalerOf(context).scale(14) > 22) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [incoming, const SizedBox(height: 4), outgoing],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: incoming),
                    const SizedBox(width: 4),
                    Expanded(child: outgoing),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('finance-amount-input'),
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            maxLength: 12,
            style: FinancePalette.text(
              context,
              size: 20,
              weight: FontWeight.w800,
            ),
            decoration: FinancePalette.input(
              context,
              label: L10nService().format('finance_amount_label', {
                'currency': currency,
              }),
              icon: Icons.payments_outlined,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('finance_category_label'),
            style: FinancePalette.text(
              context,
              size: 12,
              weight: FontWeight.w700,
              color: FinancePalette.muted(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: FinanceCategory.labelKeys.keys.map((code) {
              final selected = code == category;
              return Semantics(
                selected: selected,
                button: true,
                child: Material(
                  color: selected
                      ? accent.withValues(alpha: 0.12)
                      : FinancePalette.mutedSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: ValueKey('finance-category-$code'),
                    onTap: saving ? null : () => onCategory(code),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? accent.withValues(alpha: 0.45)
                              : FinancePalette.border(context),
                        ),
                      ),
                      child: Text(
                        FinanceCategory.label(code, context.tr),
                        style: FinancePalette.text(
                          context,
                          size: 12,
                          weight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? accent
                              : FinancePalette.ink(context),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('finance-note-input'),
            controller: noteController,
            textInputAction: TextInputAction.done,
            maxLength: 100,
            minLines: 1,
            maxLines: 3,
            style: FinancePalette.text(context),
            decoration: FinancePalette.input(
              context,
              label: context.tr('util_tychn_9aa32e'),
              icon: Icons.edit_note_rounded,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('finance-save-transaction'),
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: FinancePalette.dark(context)
                  ? SLColors.darkBgMain
                  : Colors.white,
              minimumSize: const Size(48, 50),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 19),
            label: Text(
              context.tr('finance_save_transaction'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(
    BuildContext context,
    String value,
    IconData icon,
    Color color,
  ) {
    final selected = value == type;
    final accent = FinancePalette.accent(context, color);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? FinancePalette.surface(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          key: ValueKey('finance-type-$value'),
          onTap: saving ? null : () => onType(value),
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: FinancePalette.motion(context),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.28)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? accent : FinancePalette.muted(context),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    context.tr(
                      value == 'in'
                          ? 'finance_income_label'
                          : 'finance_expense_label',
                    ),
                    textAlign: TextAlign.center,
                    style: FinancePalette.text(
                      context,
                      size: 13,
                      weight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? accent : FinancePalette.muted(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceTransactionTile extends StatelessWidget {
  const FinanceTransactionTile({
    super.key,
    required this.category,
    required this.amount,
    required this.author,
    required this.time,
    required this.onDelete,
    this.note = '',
    this.income = false,
  });
  final String category;
  final String amount;
  final String author;
  final String time;
  final String note;
  final bool income;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = FinancePalette.accent(
      context,
      income ? FinancePalette.sage : FinancePalette.rose,
    );
    return FinanceCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExcludeSemantics(
              child: Text(
                FinanceCategory.emoji(category),
                textScaler: TextScaler.noScaling,
                style: const TextStyle(fontSize: 21),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FinanceCategory.label(category, context.tr),
                  style: FinancePalette.text(
                    context,
                    size: 14,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  amount,
                  style: FinancePalette.text(
                    context,
                    size: 16,
                    weight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    note,
                    style: FinancePalette.text(
                      context,
                      size: 12,
                      color: FinancePalette.muted(context),
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (author.isNotEmpty)
                      Text(
                        author,
                        style: FinancePalette.text(
                          context,
                          size: 11,
                          weight: FontWeight.w700,
                          color: FinancePalette.muted(context),
                        ),
                      ),
                    Text(
                      time,
                      style: FinancePalette.text(
                        context,
                        size: 11,
                        color: FinancePalette.muted(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('p8_finance_delete_transaction_title'),
            onPressed: onDelete,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 19,
              color: FinancePalette.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceEmptyState extends StatelessWidget {
  const FinanceEmptyState({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
    child: Column(
      children: [
        const ExcludeSemantics(child: FinanceWalletArt(size: 76)),
        const SizedBox(height: 12),
        Text(
          context.tr('util_finance_empty_transactions'),
          textAlign: TextAlign.center,
          style: FinancePalette.text(
            context,
            size: 13,
            color: FinancePalette.muted(context),
          ),
        ),
      ],
    ),
  );
}

class _FinanceIcon extends StatelessWidget {
  const _FinanceIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withValues(
        alpha: FinancePalette.dark(context) ? 0.22 : 0.10,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, size: 22, color: FinancePalette.accent(context, color)),
  );
}

/// Minh họa vector nhỏ: ví, đồng xu, má hồng và trái tim.
class FinanceWalletArt extends StatelessWidget {
  const FinanceWalletArt({super.key, this.size = 70});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _FinanceWalletPainter(FinancePalette.dark(context)),
    ),
  );
}

class _FinanceWalletPainter extends CustomPainter {
  const _FinanceWalletPainter(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final ink = Paint()..color = const Color(0xFF754654);
    final line = Paint()
      ..color = const Color(0xFFBA7487)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      const Rect.fromLTWH(15, 84, 72, 9),
      Paint()..color = const Color(0xFFA46870).withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      const Offset(58, 23),
      17,
      Paint()..color = const Color(0xFFF5CE77),
    );
    canvas.drawCircle(
      const Offset(58, 23),
      12,
      Paint()..color = const Color(0xFFFFE7A4),
    );
    canvas.drawLine(
      const Offset(58, 17),
      const Offset(58, 28),
      Paint()
        ..color = const Color(0xFFC29A4B)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 34, 71, 48),
        const Radius.circular(15),
      ),
      Paint()..color = const Color(0xFFEAAFBB),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 30, 69, 47),
        const Radius.circular(14),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD9DC), Color(0xFFF4BBC7)],
        ).createShader(const Rect.fromLTWH(16, 30, 69, 47)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 30, 69, 47),
        const Radius.circular(14),
      ),
      line,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(70, 43, 20, 18),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFFE899AD),
    );
    canvas.drawCircle(
      const Offset(80, 52),
      3,
      Paint()..color = const Color(0xFFFFF4DF),
    );
    canvas.drawCircle(const Offset(37, 52), 2.5, ink);
    canvas.drawCircle(const Offset(53, 52), 2.5, ink);
    canvas.drawOval(
      const Rect.fromLTWH(27, 56, 11, 6),
      Paint()..color = const Color(0xFFEF96AA),
    );
    canvas.drawOval(
      const Rect.fromLTWH(53, 56, 11, 6),
      Paint()..color = const Color(0xFFEF96AA),
    );
    canvas.drawPath(
      Path()
        ..moveTo(40, 58)
        ..quadraticBezierTo(45, 64, 50, 58),
      Paint()
        ..color = const Color(0xFF754654)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final heart = Path()
      ..moveTo(20, 20)
      ..cubicTo(7, 12, 9, 29, 20, 34)
      ..cubicTo(33, 28, 33, 13, 20, 20);
    canvas.drawPath(heart, Paint()..color = const Color(0xFFD97C93));
    final star = Path()
      ..moveTo(84, 14)
      ..lineTo(86, 20)
      ..lineTo(92, 22)
      ..lineTo(86, 24)
      ..lineTo(84, 30)
      ..lineTo(82, 24)
      ..lineTo(76, 22)
      ..lineTo(82, 20)
      ..close();
    canvas.drawPath(
      star,
      Paint()..color = dark ? const Color(0xFFFFD994) : const Color(0xFFCDA565),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FinanceWalletPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
