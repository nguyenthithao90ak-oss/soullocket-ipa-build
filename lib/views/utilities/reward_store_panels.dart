import 'package:flutter/material.dart';

import '../../models/reward_missions.dart';
import '../../utils/services/l10n_service.dart';

const _ink = Color(0xFF3B2934);
const _rose = Color(0xFFBD3D65);
const _muted = Color(0xFF806C77);

class RewardCheckinCard extends StatelessWidget {
  const RewardCheckinCard({
    super.key,
    required this.days,
    required this.streak,
    required this.onCheckin,
    this.loaded = true,
    this.busy = false,
    this.now,
  });

  final Map<String, bool> days;
  final int streak;
  final VoidCallback onCheckin;
  final bool loaded, busy;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final instant = (now ?? DateTime.now()).toUtc();
    final today = rewardDayKey(instant);
    final checked = days[today] == true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E5E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: _rose, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _copy('util_imdanhhngn_d32a8b'),
                  style: const TextStyle(
                    fontSize: 18,
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            checked
                ? _copy('reward_store_done_today', {'count': '$streak'})
                : _copy('util_imdanhngay_da87d4'),
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var offset = 6; offset >= 0; offset--)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
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
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: !loaded || busy || checked ? null : onCheckin,
              style: FilledButton.styleFrom(
                backgroundColor: _rose,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
    message: today ? _copy('reward_store_today') : rewardDayKey(date),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: checked ? const Color(0xFFF0F7F1) : const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: today ? _rose : const Color(0xFFF0E5E8)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${rewardCalendarNow(date).day}',
              style: const TextStyle(
                fontSize: 12,
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            checked ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 18,
            color: checked ? const Color(0xFF3E8051) : const Color(0xFFD3B6C0),
          ),
        ],
      ),
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
  });

  final String balance;
  final String status;
  final int streak;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF87394F), Color(0xFFBA4F72)],
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
            fontSize: 10,
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
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    balance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
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
            _WalletBadge(
              icon: Icons.local_fire_department_rounded,
              label: _copy('reward_store_days', {'count': '$streak'}),
            ),
            _WalletBadge(icon: Icons.verified_outlined, label: status),
          ],
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
              fontSize: 11,
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
  });
  final Map<String, dynamic> data;
  final bool loading;
  final bool hasError;

  @override
  State<RewardMissionsPanel> createState() => _RewardMissionsPanelState();
}

class _RewardMissionsPanelState extends State<RewardMissionsPanel> {
  String _kind = 'streak';

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$completed/${RewardMission.all.length}',
              style: const TextStyle(color: _rose, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _copy('reward_store_missions_hint'),
          style: const TextStyle(fontSize: 12, color: _muted, height: 1.5),
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
                selectedColor: const Color(0xFFF7DCE5),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: kind == _kind
                      ? const Color(0xFFDC9FB4)
                      : const Color(0xFFECDDE2),
                ),
                labelStyle: TextStyle(
                  color: kind == _kind ? _rose : _muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.hasError || widget.loading)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _copy(
                widget.hasError ? 'reward_store_error' : 'reward_store_loading',
              ),
            ),
          )
        else ...[
          if (_kind != 'activity')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _copy('reward_store_${_kind}_hint'),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
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
        color: completed ? const Color(0xFFF0F7F1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: completed ? const Color(0xFFCDE5D2) : const Color(0xFFF0E5E8),
        ),
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
                  color: const Color(0xFFFFF1E6),
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
                  color: const Color(0xFFAD6234),
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+${_copy('reward_store_points', {'points': '${mission.points}'})}',
                      style: const TextStyle(
                        color: _rose,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (completed)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: 8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF3E8051),
                    size: 22,
                  ),
                ),
            ],
          ),
          if (hints.containsKey(mission.id)) ...[
            const SizedBox(height: 10),
            Text(
              _copy('reward_store_${hints[mission.id]}_hint'),
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.45),
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
                        ? const Color(0xFF63946F)
                        : const Color(0xFFDB88A1),
                    backgroundColor: const Color(0xFFF5EAF0),
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
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
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
  });
  final int count, limit, points;
  final String buttonLabel;
  final String? message;
  final bool busy;
  final VoidCallback? onWatch;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0DF),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFF0DCC6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.play_circle_outline_rounded,
              color: Color(0xFFAD6234),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _copy('reward_store_ad_title'),
                style: const TextStyle(
                  fontSize: 18,
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          message ?? _copy('reward_store_ad_hint', {'points': '$points'}),
          style: const TextStyle(
            color: Color(0xFF795D4E),
            height: 1.5,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: limit > 0 ? (count / limit).clamp(0, 1) : 0,
          color: const Color(0xFFBD864C),
          backgroundColor: const Color(0xFFF3DEC6),
          minHeight: 5,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 8),
        Text(
          _copy('reward_store_ad_count', {
            'count': '$count',
            'limit': '$limit',
          }),
          style: const TextStyle(color: Color(0xFF795D4E), fontSize: 11),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onWatch,
            style: FilledButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(buttonLabel, textAlign: TextAlign.center),
          ),
        ),
      ],
    ),
  );
}
