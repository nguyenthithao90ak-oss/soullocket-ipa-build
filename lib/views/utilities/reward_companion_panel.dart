import 'package:flutter/material.dart';
import '../../models/companion_journey.dart';
import '../../utils/services/l10n_service.dart';
import '../home/widgets/companion/home_companion_motion.dart';
import '../home/widgets/companion/home_companion_painter.dart';
import 'widgets/keepsake_design.dart';

class RewardCompanionPanel extends StatefulWidget {
  const RewardCompanionPanel({
    super.key,
    this.state,
    this.balance,
    this.loading = false,
    this.hasError = false,
    this.available = true,
    this.redeeming,
    this.onRedeem,
    this.onRefresh,
  });

  final CompanionJourney? state;
  final int? balance;
  final bool loading, hasError, available;
  final HomeCompanionCharacter? redeeming;
  final ValueChanged<HomeCompanionCharacter>? onRedeem;
  final VoidCallback? onRefresh;

  @override
  State<RewardCompanionPanel> createState() => _RewardCompanionPanelState();
}

class _RewardCompanionPanelState extends State<RewardCompanionPanel> {
  final _pose = _RewardCompanionPose();

  @override
  void dispose() {
    _pose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final enabled = widget.available && state?.enabled == true;
    return Container(
      key: const ValueKey('reward-companion-panel'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KeepsakeStyle.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KeepsakeStyle.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(context.tr('reward_companion_title'),
                style: KeepsakeStyle.text(context, size: 18, weight: FontWeight.w800))),
            IconButton(
              key: const ValueKey('reward-companion-refresh'),
              tooltip: context.tr('core_retry'),
              onPressed: widget.loading || widget.redeeming != null ? null : widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ]),
          Text(context.tr('reward_companion_hint'),
              style: KeepsakeStyle.text(context, size: 12, color: KeepsakeStyle.muted(context))),
          const SizedBox(height: 14),
          if (enabled) ...[
            Wrap(spacing: 12, runSpacing: 6, children: [
              Text(context.tr('companion_journey_level').replaceAll('{level}', '${state!.level}'),
                  style: KeepsakeStyle.text(context, size: 16, weight: FontWeight.w800)),
              Text(context.tr('companion_journey_xp_total').replaceAll('{xp}', '${state.xp}'),
                  style: KeepsakeStyle.text(context, size: 13)),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              color: KeepsakeStyle.accent(context),
              backgroundColor: KeepsakeStyle.line(context),
            ),
            const SizedBox(height: 8),
            Text(context.tr('companion_journey_daily').replaceAll('{xp}', '${state.dailyXp}'),
                style: KeepsakeStyle.text(context, size: 12, color: KeepsakeStyle.muted(context))),
          ] else
            Text(context.tr(widget.loading
                ? 'reward_store_loading'
                : widget.hasError
                ? 'reward_store_error'
                : 'reward_companion_unavailable'),
                style: KeepsakeStyle.text(context, size: 13)),
          if (widget.loading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (enabled && widget.hasError) ...[
            const SizedBox(height: 8),
            Text(context.tr('reward_store_error'), style: KeepsakeStyle.text(context, size: 12)),
          ],
          for (final character in const [HomeCompanionCharacter.melody, HomeCompanionCharacter.kuromi]) ...[
            const SizedBox(height: 14),
            _characterCard(context, character, enabled ? state : null),
          ],
          const SizedBox(height: 12),
          Text(context.tr('reward_companion_home_hint'),
              style: KeepsakeStyle.text(context, size: 12, color: KeepsakeStyle.muted(context))),
        ],
      ),
    );
  }

  Widget _characterCard(BuildContext context, HomeCompanionCharacter character, CompanionJourney? state) {
    final offer = state?.characterCatalog[character];
    final owned = state?.unlocked.contains(character) == true;
    final balance = widget.balance ?? state?.points ?? 0;
    final price = offer?.price;
    final affordable = price != null && balance >= price;
    final tint = character == HomeCompanionCharacter.melody
        ? const Color(0xFFE887AE) : const Color(0xFF9D7BCD);
    final validMilestone = offer != null && offer.level > 0 && offer.xp > 0;
    final label = owned
        ? context.tr('reward_companion_owned')
        : price == null
        ? context.tr('reward_companion_unavailable')
        : context.tr('reward_companion_redeem').replaceAll('{points}', '$price');
    return Container(
      key: ValueKey('reward-companion-${character.name}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: tint.withValues(alpha: 0.09),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(
            width: 82,
            height: 110,
            child: CustomPaint(painter: HomeCompanionPainter(
              motion: _pose,
              character: character,
              outfit: state?.outfits[character],
              showEffects: false,
              darkMode: Theme.of(context).brightness == Brightness.dark,
            )),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('reward_companion_${character.name}'),
                style: KeepsakeStyle.text(context, size: 16, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(context.tr(owned ? 'reward_companion_owned' : 'reward_companion_locked'),
                style: KeepsakeStyle.text(context, size: 12, weight: FontWeight.w600)),
            if (!owned && validMilestone) ...[
              const SizedBox(height: 6),
              Text(context.tr('reward_companion_free_level').replaceAll('{level}', '${offer.level}'),
                  style: KeepsakeStyle.text(context, size: 12)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (state!.xp / offer.xp).clamp(0.0, 1.0),
                borderRadius: BorderRadius.circular(8),
                color: tint,
                backgroundColor: tint.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 4),
              Text(context.tr('reward_companion_progress')
                  .replaceAll('{xp}', '${state.xp}')
                  .replaceAll('{target}', '${offer.xp}'),
                  style: KeepsakeStyle.text(context, size: 11, color: KeepsakeStyle.muted(context))),
            ],
          ])),
        ]),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: ValueKey('reward-companion-redeem-${character.name}'),
          onPressed: owned || !affordable || widget.loading || widget.hasError ||
                  widget.redeeming != null || widget.onRedeem == null
              ? null : () => widget.onRedeem!(character),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: character == HomeCompanionCharacter.melody
                ? const Color(0xFFAE426A) : const Color(0xFF7553A2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          icon: Icon(owned ? Icons.check_circle_outline_rounded : Icons.redeem_rounded, size: 20),
          label: Text(label, textAlign: TextAlign.center),
        ),
        if (!owned && price != null && !affordable) ...[
          const SizedBox(height: 6),
          Text(context.tr('reward_companion_missing').replaceAll('{points}', '${price - balance}'),
              textAlign: TextAlign.center,
              style: KeepsakeStyle.text(context, size: 12, color: KeepsakeStyle.muted(context))),
        ],
      ]),
    );
  }
}

class _RewardCompanionPose extends HomeCompanionMotion {
  @override
  bool get hasSurfaces => true;
  @override
  Offset get position => const Offset(41, 99);
}
