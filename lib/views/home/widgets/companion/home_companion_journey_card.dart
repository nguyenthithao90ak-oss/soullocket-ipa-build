import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/core/service_locator.dart';
import 'package:soullocket_app/utils/services/companion_journey_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/views/utilities/reward_store_screen.dart';
import 'home_companion_motion.dart';
import 'home_companion_painter.dart';

class HomeCompanionJourneyCard extends StatefulWidget {
  const HomeCompanionJourneyCard({super.key});

  @override
  State<HomeCompanionJourneyCard> createState() =>
      _HomeCompanionJourneyCardState();
}

class _HomeCompanionJourneyCardState extends State<HomeCompanionJourneyCard> {
  @override
  void initState() {
    super.initState();
    // Bảng hành trình vẫn tải khi người dùng tắt hoạt ảnh pet trên Home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && locator.isRegistered<CompanionJourneyService>()) {
        locator<CompanionJourneyService>().start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!locator.isRegistered<CompanionJourneyService>()) {
      return const SizedBox.shrink();
    }
    final service = locator<CompanionJourneyService>();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final state = service.state;
        if (state?.enabled == false) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.auto_awesome_rounded),
            title: Text(context.tr('companion_journey_title')),
            subtitle: state == null
                ? service.loading
                      ? const LinearProgressIndicator()
                      : Text(context.tr('companion_wardrobe_error'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context
                            .tr('companion_journey_level')
                            .replaceAll('{level}', '${state.level}'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context
                            .tr('companion_journey_xp_total')
                            .replaceAll('{xp}', '${state.xp}'),
                      ),
                      LinearProgressIndicator(
                        value: state.progress,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: service.loading && state == null
                ? null
                : () async {
                    if (state == null) {
                      await service.refresh();
                      return;
                    }
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _JourneySheet(service: service),
                    );
                  },
          ),
        );
      },
    );
  }
}

class _JourneySheet extends StatefulWidget {
  const _JourneySheet({required this.service});
  final CompanionJourneyService service;
  @override
  State<_JourneySheet> createState() => _JourneySheetState();
}

class _JourneySheetState extends State<_JourneySheet> {
  final _pose = _JourneyPose();
  bool _adBusy = false;
  String? _adMessage;
  int? _messageGeneration;
  bool _checkinBusy = false;
  bool _checkinFailed = false;
  int? _checkinGeneration;

  Future<void> _checkIn() async {
    if (_checkinBusy) return;
    final generation = widget.service.accountGeneration;
    setState(() {
      _checkinBusy = true;
      _checkinFailed = false;
      _checkinGeneration = generation;
    });
    try {
      await widget.service.checkIn();
    } catch (_) {
      if (mounted && generation == widget.service.accountGeneration) {
        setState(() => _checkinFailed = true);
      }
    } finally {
      if (mounted) setState(() => _checkinBusy = false);
    }
  }

  Future<void> _rewardAd({bool showIfNone = false}) async {
    if (_adBusy) return;
    final generation = widget.service.accountGeneration;
    setState(() {
      _adBusy = true;
      _adMessage = null;
      _messageGeneration = generation;
    });
    try {
      final result = await widget.service.claimAdReward(showIfNone: showIfNone);
      if (!mounted || generation != widget.service.accountGeneration) return;
      setState(
        () => _adMessage =
            result.error == 'missing_proof' ||
                result.error == 'ad_not_completed'
            ? null
            : result.ok
            ? context
                  .tr('ad_reward_points_received')
                  .replaceAll('{points}', '${result.granted}')
            : context.tr(
                result.error == 'reward_pending'
                    ? 'ad_reward_verification_pending'
                    : 'err_default_network',
              ),
      );
      await widget.service.refresh();
    } catch (_) {
      if (mounted && generation == widget.service.accountGeneration) {
        setState(() => _adMessage = context.tr('err_default_network'));
      }
    } finally {
      if (mounted) setState(() => _adBusy = false);
    }
  }

  static const _milestones = {
    HomeCompanionCharacter.bunny: 1,
    HomeCompanionCharacter.bear: 5,
    HomeCompanionCharacter.melody: 12,
    HomeCompanionCharacter.kuromi: 20,
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.service.refresh();
      if (!kIsWeb) _rewardAd();
    });
  }

  @override
  void dispose() {
    _pose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final state = widget.service.state;
          if (state == null || !state.enabled) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('companion_journey_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: context.tr('companion_wardrobe_close'),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                context
                    .tr('companion_journey_level')
                    .replaceAll('{level}', '${state.level}'),
              ),
              const SizedBox(height: 10),
              Text(
                context
                    .tr('companion_journey_xp_total')
                    .replaceAll('{xp}', '${state.xp}'),
              ),
              LinearProgressIndicator(value: state.progress),
              const SizedBox(height: 8),
              Text(
                context
                    .tr('companion_journey_daily')
                    .replaceAll('{xp}', '${state.dailyXp}'),
              ),
              Text(
                context
                    .tr('companion_shop_price')
                    .replaceAll('{points}', '${state.points}'),
              ),
              if (widget.service.loading) const LinearProgressIndicator(),
              if (widget.service.error != null)
                Text(context.tr('companion_wardrobe_error')),
              const SizedBox(height: 16),
              Text(
                context.tr('companion_journey_quests'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(context.tr('companion_journey_xp_note')),
              for (final entry in state.quests.entries)
                Card(
                  key: ValueKey('journey-quest-${entry.key}'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr('companion_journey_quest_${entry.key}'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context
                              .tr('companion_journey_quest_xp')
                              .replaceAll('{xp}', '${entry.value.xp}'),
                        ),
                        if (entry.value.completed)
                          Text(context.tr('companion_journey_done'))
                        else if (!entry.value.available)
                          Text(context.tr('companion_journey_soon'))
                        else if (entry.key == 'daily_checkin')
                          FilledButton.icon(
                            key: const ValueKey('journey-checkin'),
                            onPressed:
                                _checkinBusy ||
                                    widget.service.loading ||
                                    _adBusy
                                ? null
                                : _checkIn,
                            icon: const Icon(Icons.today_rounded),
                            label: Text(
                              context.tr(
                                'companion_journey_quest_daily_checkin',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_checkinFailed &&
                  _checkinGeneration == widget.service.accountGeneration)
                Text(context.tr('companion_wardrobe_error')),
              TextButton.icon(
                key: const ValueKey('journey-refresh'),
                onPressed: widget.service.loading || _checkinBusy || _adBusy
                    ? null
                    : widget.service.refresh,
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('core_retry')),
              ),
              if (!kIsWeb) ...[
                OutlinedButton.icon(
                  key: const ValueKey('journey-reward-ad'),
                  onPressed: _adBusy || _checkinBusy || widget.service.loading
                      ? null
                      : () => _rewardAd(showIfNone: state.adRemaining > 0),
                  icon: _adBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          state.adRemaining > 0
                              ? Icons.play_circle_outline
                              : Icons.refresh,
                        ),
                  label: Text(
                    state.adRemaining == 0
                        ? context.tr('core_retry')
                        : context
                              .tr('companion_journey_ad')
                              .replaceAll(
                                '{remaining}',
                                '${state.adRemaining}',
                              ),
                  ),
                ),
                if (_adMessage != null &&
                    _messageGeneration == widget.service.accountGeneration)
                  Text(_adMessage!),
              ],
              for (final entry in _milestones.entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          height: 110,
                          child: CustomPaint(
                            painter: HomeCompanionPainter(
                              motion: _pose,
                              character: entry.key,
                              outfit: state.outfits[entry.key],
                              showEffects: false,
                              darkMode: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context
                                .tr('companion_journey_unlock')
                                .replaceAll('{level}', '${entry.value}'),
                          ),
                        ),
                        Icon(
                          state.unlocked.contains(entry.key)
                              ? Icons.check_circle_rounded
                              : Icons.lock_outline_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              FilledButton.icon(
                icon: const Icon(Icons.favorite_outline),
                label: Text(context.tr('companion_journey_quests')),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RewardStoreScreen(),
                    ),
                  );
                  if (mounted) await widget.service.refresh();
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _JourneyPose extends HomeCompanionMotion {
  @override
  bool get hasSurfaces => true;
  @override
  Offset get position => const Offset(45, 90);
}
