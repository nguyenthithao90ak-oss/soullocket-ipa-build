import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/routing/single_open_gate.dart';
import 'package:soullocket_app/core/sl_route.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/models/single_match_models.dart';
import 'package:soullocket_app/views/visitors/visitor_profile_screen.dart';
import '../screens/single_match_finding_screen.dart';
import '../screens/single_match_call_screen.dart';
import '../widgets/single_match_hub_design.dart';

class SingleMatchCallsTab extends StatefulWidget {
  final String houseId;

  const SingleMatchCallsTab({super.key, required this.houseId});

  @override
  State<SingleMatchCallsTab> createState() => _SingleMatchCallsTabState();
}

class _SingleMatchCallsTabState extends State<SingleMatchCallsTab> {
  final SingleMatchService _service = SingleMatchService.instance;
  StreamSubscription<List<SingleMatchHistoryEntry>>? _historySub;
  List<SingleMatchHistoryEntry> _history = [];
  String? _callingHouseId;
  String? _error;
  final SingleOpenGate _openGate = SingleOpenGate();

  @override
  void initState() {
    super.initState();

    _historySub = _service
        .streamHistory(widget.houseId)
        .listen(
          (list) {
            if (mounted) setState(() => _history = list);
          },
          onError: (err) {
            if (mounted) {
              setState(() {
                _error = AppErrorMapper.resolve(
                  err,
                  fallbackMessage: L10nService().translate(
                    'match_khngthtidl_11f27c',
                  ),
                ).message;
              });
            }
          },
        );
  }

  @override
  void dispose() {
    _historySub?.cancel();
    super.dispose();
  }

  Future<void> _startRandomCall({
    required bool isVideo,
    required bool isBlind,
  }) {
    return _openGate.run(
      () => _startRandomCallFlow(isVideo: isVideo, isBlind: isBlind),
    );
  }

  Future<void> _startRandomCallFlow({
    required bool isVideo,
    required bool isBlind,
  }) async {
    final excludeHouseIds = _history
        .where((e) => e.isCall)
        .map((e) => e.peerHouseId)
        .toSet();

    final result = await slPush<dynamic>(
      context,
      SingleMatchFindingScreen(
        currentHouseId: widget.houseId,
        excludeHouseIds: excludeHouseIds,
        isVideo: isVideo,
      ),
    );

    if (result == 'cancelled') return;

    if (result == null || result is! SingleMatchCandidate) {
      if (!mounted) return;
      _showSnack(context.tr('p4_match_no_candidate'));
      return;
    }

    await _launchCall(pick: result, isVideo: isVideo, isBlind: isBlind);
  }

  Future<void> _launchCall({
    required SingleMatchCandidate pick,
    required bool isVideo,
    bool isBlind = false,
    double compatScore = 50,
  }) async {
    if (_callingHouseId != null) return;
    final startedAt = DateTime.now().millisecondsSinceEpoch;

    setState(() => _callingHouseId = pick.houseId);
    try {
      await slPush<void>(
        context,
        SingleMatchCallScreen(
          peerName: pick.displayName,
          peerAvatarUrl: pick.avatarUrl,
          peerHouseId: pick.houseId,
          isVideo: isVideo,
          isBlind: isBlind,
        ),
      );
    } finally {
      final endedAt = DateTime.now().millisecondsSinceEpoch;
      try {
        await _service
            .logHistory(
              houseId: widget.houseId,
              action: isVideo ? 'video_call' : 'audio_call',
              peerHouseId: pick.houseId,
              peerName: pick.displayName,
              peerAvatarUrl: pick.avatarUrl,
              goal: pick.goal,
              startedAt: startedAt,
              endedAt: endedAt,
              durationSeconds: ((endedAt - startedAt) / 1000).round(),
              compatibilityScore: compatScore,
              note: L10nService().translate('match_khitottabg_083000'),
            )
            .timeout(const Duration(seconds: 8));
      } catch (error) {
        debugPrint(
          '[SuppressedError] lib/views/single_match/tabs/single_match_calls_tab.dart: $error',
        );
      }
      if (mounted) setState(() => _callingHouseId = null);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFD81B60) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SLTheme.emptyStatePanel(
            icon: Icons.cloud_off_rounded,
            title: context.tr('p4_match_load_error_title'),
            subtitle: _error!,
            accentColor: SLColors.danger,
          ),
        ),
      );
    }

    final callEntries = _history.where((e) => e.isCall).toList();
    final totalMinutes = callEntries.fold<int>(
      0,
      (sum, e) => sum + e.durationSeconds ~/ 60,
    );
    final palette = SingleMatchHubPalette.of(context);
    final horizontalPadding = MediaQuery.sizeOf(context).width < 380
        ? 14.0
        : 20.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          physics: SLResponsive.scrollPhysicsForPlatform(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            30,
          ),
          children: [
            _buildCallHero(context, palette),

            if (callEntries.isNotEmpty) ...[
              const SizedBox(height: 18),
              _buildStats(
                context,
                palette,
                calls: callEntries.length,
                minutes: totalMinutes,
              ),
              const SizedBox(height: 18),
              _buildSectionHeader(context, palette),
              const SizedBox(height: 12),
              ...callEntries.map(_buildHistoryCard),
            ],

            if (callEntries.isEmpty && _history.isEmpty) ...[
              const SizedBox(height: 24),
              _buildEmptyState(context, palette),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCallHero(BuildContext context, SingleMatchHubPalette palette) {
    final isBusy = _callingHouseId != null;
    return Semantics(
      container: true,
      label: context.tr('p4_match_random_title'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.soft, palette.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: Color(0xFF6366F1),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('p4_match_random_title'),
                        style: SLTheme.quicksand(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.tr('p4_match_random_subtitle'),
                        style: SLTheme.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCallAction(
              context,
              palette,
              icon: Icons.call_rounded,
              title: context.tr('match_githoi_ad3e35'),
              subtitle: context.tr('match_chophpgith_5a78ca'),
              filled: true,
              enabled: !isBusy,
              onPressed: () => _startRandomCall(isVideo: false, isBlind: false),
            ),
            const SizedBox(height: 10),
            _buildCallAction(
              context,
              palette,
              icon: Icons.videocam_rounded,
              title: context.tr('match_givideonga_ba8333'),
              subtitle: context.tr('match_chophpgivi_95d26f'),
              filled: false,
              enabled: !isBusy,
              onPressed: () => _startRandomCall(isVideo: true, isBlind: false),
            ),
            if (isBusy) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('match_anggi_fc34f1'),
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCallAction(
    BuildContext context,
    SingleMatchHubPalette palette, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool filled,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final foreground = filled ? palette.onAction : palette.ink;
    final background = filled ? palette.action : palette.surface;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(
            color: filled ? palette.action : palette.border,
            width: filled ? 0 : 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, color: filled ? palette.onAction : palette.accent),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: filled
                      ? palette.onAction.withValues(alpha: 0.82)
                      : palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats(
    BuildContext context,
    SingleMatchHubPalette palette, {
    required int calls,
    required int minutes,
  }) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: L10nService().translate('match_tngcucgi_8e041e'),
            value: '$calls',
            icon: Icons.call_rounded,
            color: palette.accent,
            background: palette.surface,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: L10nService().translate('match_phttrchuyn_b7d1cd'),
            value: '$minutes',
            icon: Icons.schedule_rounded,
            color: const Color(0xFF6366F1),
            background: palette.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    SingleMatchHubPalette palette,
  ) {
    return Text(
      context.tr('p4_match_history_title'),
      style: SLTheme.quicksand(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: palette.ink,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, SingleMatchHubPalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.soft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.call_end_rounded,
              size: 30,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('p4_match_empty_title'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('p4_match_empty_subtitle'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(SingleMatchHistoryEntry entry) {
    final isVideo = entry.action == 'video_call';
    final actionLabel = switch (entry.action) {
      'audio_call' => L10nService().translate('match_cucgithoi_98f19b'),
      'video_call' => L10nService().translate('match_cucgivideo_e7e38f'),
      _ => L10nService().translate('match_hotng_2c21bc'),
    };
    final accent = switch (entry.action) {
      'audio_call' => const Color(0xFFFF5E7E),
      'video_call' => const Color(0xFF6366F1),
      _ => const Color(0xFF38BDF8),
    };
    final palette = SingleMatchHubPalette.of(context);
    final isBusy = _callingHouseId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: palette.soft,
                  backgroundImage: entry.peerAvatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(entry.peerAvatarUrl)
                      : null,
                  child: entry.peerAvatarUrl.isEmpty
                      ? Text(
                          entry.peerName.isNotEmpty
                              ? entry.peerName[0].toUpperCase()
                              : '?',
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.peerName.isEmpty
                        ? L10nService().translate('match_hsc_81b822')
                        : entry.peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: palette.ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    actionLabel,
                    style: SLTheme.quicksand(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              L10nService().format('p4_match_history_meta', {
                'time': _formatRelativeTime(entry.startedAt),
                'score': entry.compatibilityScore.toStringAsFixed(0),
              }),
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDuration(entry.durationSeconds),
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => slPush<void>(
                      context,
                      VisitorProfileScreen(targetHouseId: entry.peerHouseId),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: palette.ink,
                      side: BorderSide(color: palette.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.person_search_rounded, size: 17),
                    label: Text(context.tr('match_mhs_d226ff')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => _launchCall(
                            pick: SingleMatchCandidate(
                              houseId: entry.peerHouseId,
                              displayName: entry.peerName,
                              houseName: entry.peerName,
                              avatarUrl: entry.peerAvatarUrl,
                              bio: '',
                              intro: '',
                              goal: entry.goal,
                              voiceStyle: '',
                              tags: const [],
                              allowAudioCalls: true,
                              allowVideoCalls: true,
                              enabled: true,
                              privacy: 'public',
                              updatedAt: entry.startedAt,
                              age: null,
                            ),
                            isVideo: isVideo,
                            compatScore: entry.compatibilityScore,
                          ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(
                      isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      size: 17,
                    ),
                    label: Text(
                      context.tr(
                        isVideo
                            ? 'p4_match_call_video_again'
                            : 'p4_match_call_again',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) {
      return L10nService().translate('p4_match_just_now');
    }
    if (diff.inMinutes < 60) {
      return L10nService().format('p4_match_minutes_ago', {
        'count': diff.inMinutes,
      });
    }
    if (diff.inHours < 24) {
      return L10nService().format('p4_match_hours_ago', {
        'count': diff.inHours,
      });
    }
    if (diff.inDays < 7) {
      return L10nService().format('p4_match_days_ago', {'count': diff.inDays});
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return L10nService().format('p4_match_seconds', {'count': seconds});
    }
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return sec > 0
        ? L10nService().format('p4_match_minutes_seconds', {
            'minutes': min,
            'seconds': sec,
          })
        : L10nService().format('p4_match_minutes', {'count': min});
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
