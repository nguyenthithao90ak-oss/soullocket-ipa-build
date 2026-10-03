import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reward_pro_plan.dart';
import '../../utils/services/l10n_service.dart';

/// Danh sách lựa chọn phẳng; nghiệp vụ đổi điểm nằm ở màn hình/service.
class RewardProExchange extends StatefulWidget {
  const RewardProExchange({
    super.key,
    required this.points,
    required this.onRedeem,
    this.busy = false,
  });

  final int points;
  final bool busy;
  final ValueChanged<RewardProPlan> onRedeem;

  @override
  State<RewardProExchange> createState() => _RewardProExchangeState();
}

class _RewardProExchangeState extends State<RewardProExchange> {
  RewardProPlan _selected = RewardProPlan.all.first;

  String _number(int value) => NumberFormat.decimalPattern(
    L10nService().locale.toString(),
  ).format(value);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF5EFED) : const Color(0xFF302A30);
    final muted = dark ? const Color(0xFFBBAFB6) : const Color(0xFF796D76);
    final accent = dark ? const Color(0xFFE4A6B8) : const Color(0xFF874C61);
    final line = dark ? const Color(0xFF423940) : const Color(0xFFECE3E5);
    final affordable = widget.points >= _selected.points;
    final summary = L10nService().format(
      affordable ? 'reward_store_balance_after' : 'reward_store_need_points',
      {'points': _number((widget.points - _selected.points).abs())},
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF282329) : const Color(0xFFFFFDFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 30, color: accent),
          const SizedBox(height: 12),
          Text(
            context.tr('util_giiimpro_28acbc'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('reward_store_exchange_note'),
            style: TextStyle(fontSize: 13, color: muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('reward_store_choose_plan'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          for (final plan in RewardProPlan.all) ...[
            _planRow(context, plan, ink, muted, accent, dark),
            if (plan != RewardProPlan.all.last) Divider(height: 1, color: line),
          ],
          const SizedBox(height: 16),
          Text(
            summary,
            key: const ValueKey('pro-exchange-summary'),
            style: TextStyle(
              fontSize: 13,
              color: affordable ? muted : accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('pro-exchange-submit'),
              onPressed: affordable && !widget.busy
                  ? () => widget.onRedeem(_selected)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: dark ? const Color(0xFF282329) : Colors.white,
                minimumSize: const Size(48, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: widget.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '${context.tr('redeem')} · ${context.tr(_selected.titleKey)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planRow(
    BuildContext context,
    RewardProPlan plan,
    Color ink,
    Color muted,
    Color accent,
    bool dark,
  ) {
    final selected = plan.id == _selected.id;
    final price = L10nService().format('reward_store_points', {
      'points': _number(plan.points),
    });
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? accent.withValues(alpha: dark ? 0.13 : 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('pro-plan-${plan.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: widget.busy ? null : () => setState(() => _selected = plan),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 16, 10, 16),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 22,
                  color: selected ? accent : muted.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked =
                          constraints.maxWidth < 220 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20;
                      final title = Text(
                        context.tr(plan.titleKey),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      );
                      final cost = Text(
                        price,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected ? accent : ink,
                        ),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (stacked) ...[
                            title,
                            const SizedBox(height: 4),
                            cost,
                          ] else
                            Row(
                              children: [
                                Expanded(child: title),
                                const SizedBox(width: 8),
                                cost,
                              ],
                            ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(plan.subtitleKey),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: muted,
                            ),
                          ),
                        ],
                      );
                    },
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
