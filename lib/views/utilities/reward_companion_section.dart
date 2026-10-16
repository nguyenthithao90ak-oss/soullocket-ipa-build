import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/service_locator.dart';
import '../../utils/services/companion_rewards_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../widgets/sl_feedback.dart';
import '../home/widgets/companion/home_companion_outfit.dart';
import 'reward_companion_panel.dart';

class RewardCompanionSection extends StatefulWidget {
  const RewardCompanionSection({super.key, this.balance});

  final int? balance;

  @override
  State<RewardCompanionSection> createState() => _RewardCompanionSectionState();
}

class _RewardCompanionSectionState extends State<RewardCompanionSection>
    with WidgetsBindingObserver {
  CompanionRewardsService? _service;
  HomeCompanionCharacter? _redeeming;
  int? _redeemGeneration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (locator.isRegistered<CompanionRewardsService>()) {
      _service = locator<CompanionRewardsService>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _service!.start();
        if (_service!.state != null) unawaited(_service!.refresh());
      });
    }
  }

  @override
  void didUpdateWidget(RewardCompanionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.balance != oldWidget.balance && _redeeming == null &&
        _service?.state?.enabled == true && _service?.loading == false) {
      unawaited(_service!.refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = _service;
    if (state == AppLifecycleState.resumed && _redeeming == null &&
        service != null) {
      unawaited(service.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _redeem(HomeCompanionCharacter character) async {
    final service = _service;
    final price = service?.state?.prices[character];
    if (service == null || service.loading || service.state?.enabled != true ||
        _redeeming != null || price == null ||
        service.state!.unlocked.contains(character)) {
      return;
    }
    final generation = service.accountGeneration;
    setState(() {
      _redeeming = character;
      _redeemGeneration = generation;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('reward_companion_confirm_title')),
          content: Text(context.tr('reward_companion_confirm_body')
              .replaceAll('{name}', context.tr('reward_companion_${character.name}'))
              .replaceAll('{points}', '$price')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              key: const ValueKey('reward-companion-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('confirm')),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true || generation != service.accountGeneration) return;
      try {
        await service.redeemCharacter(character, price);
      } catch (_) {
        if (!mounted || generation != service.accountGeneration) return;
        await service.refresh();
      }
      if (!mounted || generation != service.accountGeneration) return;
      final received = service.state?.enabled == true &&
          service.state!.unlocked.contains(character);
      ScaffoldMessenger.of(context).showSnackBar(SLSnackBar(
        content: Text(received
            ? context.tr('reward_companion_received').replaceAll(
                '{name}', context.tr('reward_companion_${character.name}'))
            : context.tr('reward_companion_uncertain')),
      ));
    } finally {
      if (mounted) setState(() => _redeeming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (service == null) return const RewardCompanionPanel(available: false);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => RewardCompanionPanel(
        state: service.state,
        balance: widget.balance,
        loading: service.loading,
        hasError: service.error != null,
        redeeming: _redeemGeneration == service.accountGeneration ? _redeeming : null,
        onRedeem: _redeem,
        onRefresh: _redeeming == null ? service.refresh : null,
      ),
    );
  }
}

