import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/routing/single_open_gate.dart';
import 'package:soullocket_app/core/sl_route.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/models/single_match_models.dart';
import 'package:soullocket_app/views/chat/chat_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/single_match_finding_screen.dart';
import '../widgets/single_match_hub_design.dart';

class SingleMatchChatsTab extends StatefulWidget {
  final String houseId;

  const SingleMatchChatsTab({super.key, required this.houseId});

  @override
  State<SingleMatchChatsTab> createState() => _SingleMatchChatsTabState();
}

class _SingleMatchChatsTabState extends State<SingleMatchChatsTab> {
  final SingleMatchService _service = SingleMatchService.instance;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSub;
  List<Map<String, dynamic>> _mappings = [];
  bool _isCreating = false;
  String? _error;
  final SingleOpenGate _openGate = SingleOpenGate();

  @override
  void initState() {
    super.initState();
    _chatSub = _service
        .streamChatMappings(widget.houseId)
        .listen(
          (list) {
            if (mounted) setState(() => _mappings = list);
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
    _chatSub?.cancel();
    super.dispose();
  }

  Future<void> _startRandomChat() {
    return _openGate.run(_startRandomChatFlow);
  }

  Future<void> _startRandomChatFlow() async {
    if (_isCreating) return;

    try {
      final alreadyChatted = _mappings
          .map((m) => m['peerHouseId'].toString())
          .toSet();

      final result = await slPush<dynamic>(
        context,
        SingleMatchFindingScreen(
          currentHouseId: widget.houseId,
          excludeHouseIds: alreadyChatted,
          isChat: true,
        ),
      );

      if (result == 'cancelled') return;

      if (result == null || result is! SingleMatchCandidate) {
        if (!mounted) return;
        _showSnack(context.tr('p9_match_chat_no_candidates'));
        return;
      }

      setState(() => _isCreating = true);

      final pick = result;
      await _service.getOrCreateMatchChatRoom(
        myHouseId: widget.houseId,
        peerHouseId: pick.houseId,
        peerName: pick.displayName,
        peerAvatarUrl: pick.avatarUrl,
      );

      if (!mounted) return;
      await slPush<void>(
        context,
        ChatDetailScreen(
          myHouseId: widget.houseId,
          targetHouseId: pick.houseId,
          targetName: pick.displayName,
          targetAvatar: pick.avatarUrl,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      _showSnack(
        AppErrorMapper.resolve(
          err,
          fallbackMessage: L10nService().translate('match_khngthtidl_11f27c'),
        ).message,
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: SLColors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w700,
                  color: SLColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final palette = SingleMatchHubPalette.of(context);
    final hasMappings = _mappings.isNotEmpty;
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
            _buildChatHero(context, palette),
            const SizedBox(height: 22),
            if (hasMappings) ...[
              _buildSectionHeader(context, palette),
              const SizedBox(height: 12),
              ..._mappings.map(_buildChatItem),
            ] else
              _buildEmptyState(context, palette),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHero(BuildContext context, SingleMatchHubPalette palette) {
    return Semantics(
      container: true,
      label: context.tr('p9_match_chat_random_title'),
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
                    color: palette.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.forum_rounded,
                    color: palette.accent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('p9_match_chat_random_title'),
                        style: SLTheme.quicksand(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.tr('p9_match_chat_random_subtitle'),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStepChip(
                  context,
                  palette,
                  Icons.explore_rounded,
                  context.tr('match_ghpngunhin_1ee82f'),
                ),
                _buildStepChip(
                  context,
                  palette,
                  Icons.chat_bubble_rounded,
                  context.tr('chat_tab'),
                ),
                _buildStepChip(
                  context,
                  palette,
                  Icons.call_rounded,
                  context.tr('match_gi_7c0807'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isCreating ? null : _startRandomChat,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: palette.action,
                  foregroundColor: palette.onAction,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isCreating
                    ? Semantics(
                        label: context.tr('p9_match_chat_creating'),
                        liveRegion: true,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.onAction,
                          ),
                        ),
                      )
                    : const Icon(Icons.person_search_rounded),
                label: Text(
                  context.tr(
                    _isCreating
                        ? 'p9_match_chat_creating'
                        : 'p9_match_chat_start',
                  ),
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepChip(
    BuildContext context,
    SingleMatchHubPalette palette,
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    SingleMatchHubPalette palette,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr('p9_match_chat_history'),
            style: SLTheme.quicksand(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: palette.ink,
            ),
          ),
        ),
        Text(
          L10nService().format('p9_match_chat_people_count', {
            'count': _mappings.length,
          }),
          style: SLTheme.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.muted,
          ),
        ),
      ],
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
              Icons.chat_bubble_outline_rounded,
              size: 30,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('p9_match_chat_empty_title'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('p9_match_chat_empty_subtitle'),
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

  Widget _buildChatItem(Map<String, dynamic> mapping) {
    final peerHouseId = mapping['peerHouseId']?.toString() ?? '';
    final peerName =
        mapping['peerName']?.toString() ??
        L10nService().translate('match_hsc_81b822');
    final peerAvatar = mapping['peerAvatarUrl']?.toString() ?? '';
    final createdAt = mapping['createdAt'] is num
        ? _formatTime(mapping['createdAt'] as num)
        : '';
    final palette = SingleMatchHubPalette.of(context);

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
          children: [
            Row(
              children: [
                Semantics(
                  image: true,
                  label: L10nService().format('p9_match_chat_avatar_label', {
                    'name': peerName,
                  }),
                  child: ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: palette.soft,
                      backgroundImage: peerAvatar.isNotEmpty
                          ? CachedNetworkImageProvider(peerAvatar)
                          : null,
                      child: peerAvatar.isEmpty
                          ? Text(
                              peerName.isNotEmpty
                                  ? peerName[0].toUpperCase()
                                  : '?',
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                color: palette.accent,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAt.isEmpty
                            ? context.tr('p9_match_chat_empty_subtitle')
                            : createdAt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.muted),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => slPush<void>(
                  context,
                  ChatDetailScreen(
                    myHouseId: widget.houseId,
                    targetHouseId: peerHouseId,
                    targetName: peerName,
                    targetAvatar: peerAvatar,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: palette.ink,
                  side: BorderSide(color: palette.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(Icons.chat_bubble_rounded, color: palette.accent),
                label: Text(
                  context.tr('p9_match_chat_message'),
                  style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(num ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) {
      return L10nService().translate('p9_match_time_just_now');
    }
    if (diff.inMinutes < 60) {
      return L10nService().format('p9_match_time_minutes_ago', {
        'count': diff.inMinutes,
      });
    }
    if (diff.inHours < 24) {
      return L10nService().format('p9_match_time_hours_ago', {
        'count': diff.inHours,
      });
    }
    if (diff.inDays < 7) {
      return L10nService().format('p9_match_time_days_ago', {
        'count': diff.inDays,
      });
    }
    return L10nService().format('p9_match_time_date', {
      'day': dt.day,
      'month': dt.month,
      'year': dt.year,
    });
  }
}
