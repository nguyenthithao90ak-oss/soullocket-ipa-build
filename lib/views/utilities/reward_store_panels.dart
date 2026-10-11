import 'package:flutter/material.dart';
import '../../utils/locale_date_format.dart';

import '../../models/reward_missions.dart';
import '../../utils/services/l10n_service.dart';
import 'reward_store_design.dart';

RewardStorePalette _palette(BuildContext context) =>
    RewardStorePalette.of(context);

class RewardCheckinCard extends StatelessWidget {
  const RewardCheckinCard({
    super.key,
    required this.days,
    required this.streak,
    required this.onCheckin,
    this.loaded = true,
    this.busy = false,
    this.hasError = false,
    this.refreshing = false,
    this.onRetry,
    this.now,
  });

  final Map<String, bool> days;
  final int streak;
  final VoidCallback onCheckin;
  final bool loaded, busy, hasError, refreshing;
  final VoidCallback? onRetry;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final instant = (now ?? DateTime.now()).toUtc();
    final today = rewardDayKey(instant);
    final checked = days[today] == true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _palette(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _palette(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: _palette(context).rose,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _copy('util_imdanhhngn_d32a8b'),
                  style: TextStyle(
                    fontSize: 18,
                    color: _palette(context).ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasError
                ? _copy('reward_store_error')
                : !loaded
                ? _copy('reward_store_loading')
                : checked
                ? _copy('reward_store_done_today', {'count': '$streak'})
                : _copy('util_imdanhngay_da87d4'),
            style: TextStyle(
              color: _palette(context).muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _copy('reward_store_reset_local', {
              'time': LocaleDateFormat.dateTime(
                nextRewardResetUtc(instant).toLocal(),
              ),
            }),
            style: TextStyle(
              color: _palette(context).muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          if (loaded)
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth < 330 ||
                        MediaQuery.textScalerOf(context).scale(14) > 19
                    ? 4
                    : 7;
                final dayWidth =
                    (constraints.maxWidth - 6 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: [
                    for (var offset = 6; offset >= 0; offset--)
                      SizedBox(
                        width: dayWidth,
                        child: _CheckinDay(
                          date: instant.subtract(Duration(days: offset)),
                          checked:
                              days[rewardDayKey(
                                instant.subtract(Duration(days: offset)),
                              )] ==
                              true,
                          today: offset == 0,
                        ),
                      ),
                  ],
                );
              },
            )
          else
            _RewardReadState(
              message: _copy(
                hasError ? 'reward_store_error' : 'reward_store_loading',
              ),
              onRetry: hasError ? onRetry : null,
            ),
          if (loaded && hasError)
            _RewardReadState(
              message: _copy('reward_store_error'),
              onRetry: onRetry,
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('reward-checkin-submit'),
              onPressed: !loaded || busy || hasError || refreshing || checked
                  ? null
                  : onCheckin,
              style: FilledButton.styleFrom(
                backgroundColor: _palette(context).rose,
                foregroundColor: _palette(context).onAccent,
                disabledBackgroundColor: _palette(context).disabled,
                disabledForegroundColor: _palette(context).muted,
                minimumSize: const Size(48, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: busy
                  ? _rewardBusyIcon(context)
                  : Text(
                      _copy(
                        !loaded
                            ? 'util_angtiimdan_3fdaf8'
                            : checked
                            ? 'util_imdanh_682dd9'
                            : 'util_bmimdanh_d15143',
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckinDay extends StatelessWidget {
  const _CheckinDay({
    required this.date,
    required this.checked,
    required this.today,
  });
  final DateTime date;
  final bool checked, today;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: today
        ? _copy('reward_store_today')
        : LocaleDateFormat.date(rewardCalendarNow(date)),
    child: Semantics(
      label: LocaleDateFormat.date(rewardCalendarNow(date)),
      value: checked
          ? _copy('reward_store_completed')
          : today
          ? _copy('reward_store_today')
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: checked
              ? _palette(context).successSoft
              : _palette(context).roseSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: today ? _palette(context).rose : _palette(context).line,
          ),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${rewardCalendarNow(date).day}',
                style: TextStyle(
                  fontSize: 14,
                  color: _palette(context).ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              checked ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: checked
                  ? _palette(context).success
                  : _palette(context).muted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RewardReadState extends StatelessWidget {
  const _RewardReadState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _palette(context).muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.tr('retry')),
            style: TextButton.styleFrom(
              foregroundColor: _palette(context).rose,
              minimumSize: const Size(48, 48),
            ),
          ),
      ],
    ),
  );
}

String _copy(String key, [Map<String, String> values = const {}]) {
  var text = L10nService().translate(key);
  for (final entry in values.entries) {
    text = text.replaceAll('{${entry.key}}', entry.value);
  }
  return text;
}

class RewardWalletCard extends StatelessWidget {
  const RewardWalletCard({
    super.key,
    required this.balance,
    required this.status,
    required this.streak,
    this.loading = false,
    this.hasError = false,
    this.onRetry,
  });

  final String balance;
  final String status;
  final int? streak;
  final bool loading, hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: _palette(context).wallet,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _copy('reward_store_eyebrow'),
          style: const TextStyle(
            color: Color(0xFFFFDBD6),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _copy('reward_store_tagline'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _copy('reward_store_balance'),
                    style: const TextStyle(
                      color: Color(0xFFFFE3E5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      balance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 390 &&
                MediaQuery.textScalerOf(context).scale(14) <= 20)
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFD795),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF994E29),
                    size: 38,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (streak != null)
              _WalletBadge(
                icon: Icons.local_fire_department_rounded,
                label: _copy('reward_store_days', {'count': '$streak'}),
              ),
            _WalletBadge(icon: Icons.verified_outlined, label: status),
          ],
        ),
        if ((hasError || loading) && onRetry != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.tr('retry')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
      ],
    ),
  );
}

class _WalletBadge extends StatelessWidget {
  const _WalletBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFFFDBBC), size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class RewardMissionsPanel extends StatefulWidget {
  const RewardMissionsPanel({
    super.key,
    required this.data,
    this.loading = false,
    this.hasError = false,
    this.onRetry,
    this.hasData = true,
    this.refreshing = false,
  });
  final Map<String, dynamic> data;
  final bool loading;
  final bool hasError;
  final bool hasData;
  final bool refreshing;
  final VoidCallback? onRetry;

  @override
  State<RewardMissionsPanel> createState() => _RewardMissionsPanelState();
}

class _RewardMissionsPanelState extends State<RewardMissionsPanel> {
  String _kind = 'streak';

  @override
  Widget build(BuildContext context) {
    try {
      return _buildPanel(context);
    } catch (error, stackTrace) {
      debugPrint('Reward missions panel build failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _MissionPanelState(
        message: _copy('reward_store_error'),
        onRetry: widget.onRetry,
      );
    }
  }

  Widget _buildPanel(BuildContext context) {
    final missions = RewardMission.all.where(
      (mission) => mission.kind == _kind,
    );
    final completed = RewardMission.all
        .where((mission) => mission.completed(widget.data))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _copy('reward_store_missions'),
                style: TextStyle(
                  color: _palette(context).ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.hasData)
              Text(
                '$completed/${RewardMission.all.length}',
                style: TextStyle(
                  color: _palette(context).rose,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _copy('reward_store_missions_hint'),
          style: TextStyle(
            fontSize: 14,
            color: _palette(context).muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final kind in ['activity', 'streak', 'video'])
              ChoiceChip(
                label: Text(_copy('reward_store_$kind')),
                selected: kind == _kind,
                onSelected: (_) => setState(() => _kind = kind),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                selectedColor: _palette(context).roseSoft,
                backgroundColor: _palette(context).surface,
                side: BorderSide(
                  color: kind == _kind
                      ? _palette(context).rose
                      : _palette(context).line,
                ),
                labelStyle: TextStyle(
                  color: kind == _kind
                      ? _palette(context).rose
                      : _palette(context).muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!widget.hasData || (widget.loading && !widget.refreshing))
          _MissionPanelState(
            message: _copy(
              widget.hasError ? 'reward_store_error' : 'reward_store_loading',
            ),
            onRetry: widget.hasError ? widget.onRetry : null,
          )
        else ...[
          if (widget.hasError || widget.refreshing)
            _MissionPanelState(
              message: _copy(
                widget.hasError ? 'reward_store_error' : 'reward_store_loading',
              ),
              onRetry: widget.hasError ? widget.onRetry : null,
            ),
          if (_kind != 'activity')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _copy('reward_store_${_kind}_hint'),
                style: TextStyle(
                  color: _palette(context).muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          for (final mission in missions)
            _MissionRow(mission: mission, data: widget.data),
        ],
      ],
    );
  }
}

class _MissionPanelState extends StatelessWidget {
  const _MissionPanelState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Column(
      children: [
        Icon(
          onRetry == null
              ? Icons.hourglass_empty_rounded
              : Icons.favorite_border_rounded,
          color: _palette(context).rose,
          size: 30,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _palette(context).muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.tr('retry')),
            style: TextButton.styleFrom(
              foregroundColor: _palette(context).rose,
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ],
    ),
  );
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission, required this.data});
  final RewardMission mission;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final completed = mission.completed(data);
    final progress = mission.progress(data);
    final available = mission.kind != 'activity' || data[mission.id] is Map;
    final title = mission.kind == 'activity'
        ? _copy('companion_journey_quest_${mission.id}')
        : _copy('reward_store_${mission.kind}_title', {
            'count': '${mission.target}',
          });
    const hints = {
      'partner_interaction': 'partner',
      'diary_entry': 'diary',
      'map_checkin': 'map',
      'simultaneous_online': 'online',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed
            ? _palette(context).successSoft
            : _palette(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _palette(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _palette(context).goldSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  switch (mission.id) {
                    'partner_interaction' => Icons.favorite_outline_rounded,
                    'map_checkin' => Icons.place_outlined,
                    'diary_entry' => Icons.photo_camera_outlined,
                    'simultaneous_online' => Icons.people_outline_rounded,
                    'streak_2' => Icons.spa_outlined,
                    'streak_3' => Icons.local_florist_outlined,
                    'streak_7' => Icons.emoji_events_outlined,
                    'video_20' => Icons.card_giftcard_rounded,
                    _ => Icons.play_circle_outline_rounded,
                  },
                  color: _palette(context).gold,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: _palette(context).ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+${_copy('reward_store_points', {'points': '${mission.points}'})}',
                      style: TextStyle(
                        color: _palette(context).rose,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (completed)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: _palette(context).success,
                    size: 22,
                  ),
                ),
            ],
          ),
          if (hints.containsKey(mission.id)) ...[
            const SizedBox(height: 10),
            Text(
              _copy('reward_store_${hints[mission.id]}_hint'),
              style: TextStyle(
                color: _palette(context).muted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress / mission.target,
                    minHeight: 5,
                    color: completed
                        ? _palette(context).success
                        : _palette(context).rose,
                    backgroundColor: _palette(context).line,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  !available
                      ? _copy('companion_journey_soon')
                      : completed
                      ? _copy('reward_store_completed')
                      : '$progress/${mission.target}',
                  style: TextStyle(
                    color: _palette(context).muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RewardVideoCard extends StatelessWidget {
  const RewardVideoCard({
    super.key,
    required this.count,
    required this.limit,
    required this.points,
    required this.buttonLabel,
    required this.onWatch,
    this.message,
    this.busy = false,
    this.onRetry,
  });
  final int? count;
  final int limit, points;
  final String buttonLabel;
  final String? message;
  final bool busy;
  final VoidCallback? onWatch;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _palette(context).goldSoft,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _palette(context).line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              color: _palette(context).gold,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _copy('reward_store_ad_title'),
                style: TextStyle(
                  fontSize: 18,
                  color: _palette(context).ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          message ?? _copy('reward_store_ad_hint', {'points': '$points'}),
          style: TextStyle(
            color: _palette(context).muted,
            height: 1.5,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        if (count != null) ...[
          LinearProgressIndicator(
            value: limit > 0 ? (count! / limit).clamp(0, 1) : 0,
            color: _palette(context).gold,
            backgroundColor: _palette(context).line,
            minHeight: 5,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            _copy('reward_store_ad_count', {
              'count': '${count!}',
              'limit': '$limit',
            }),
            style: TextStyle(color: _palette(context).muted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('reward-video-submit'),
            onPressed: onWatch,
            style: FilledButton.styleFrom(
              backgroundColor: _palette(context).rose,
              foregroundColor: _palette(context).onAccent,
              disabledBackgroundColor: _palette(context).disabled,
              disabledForegroundColor: _palette(context).muted,
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: busy
                ? _rewardBusyIcon(context)
                : const Icon(Icons.play_arrow_rounded),
            label: Text(buttonLabel, textAlign: TextAlign.center),
          ),
        ),
        if (onRetry != null)
          Align(
            alignment: AlignmentDirectional.center,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.tr('retry')),
              style: TextButton.styleFrom(
                foregroundColor: _palette(context).ink,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _rewardBusyIcon(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Icon(
        Icons.hourglass_top_rounded,
        color: _palette(context).onAccent,
        size: 20,
      )
    : SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _palette(context).onAccent,
        ),
      );
