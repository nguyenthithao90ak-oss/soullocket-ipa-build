import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/single_match_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/models/single_match_models.dart';
import 'package:soullocket_app/views/chat/chat_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/single_match_finding_screen.dart';

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

  Future<void> _startRandomChat() async {
    if (_isCreating) return;

    try {
      final alreadyChatted = _mappings
          .map((m) => m['peerHouseId'].toString())
          .toSet();

      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (context) => SingleMatchFindingScreen(
            currentHouseId: widget.houseId,
            excludeHouseIds: alreadyChatted,
            isChat: true,
          ),
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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            myHouseId: widget.houseId,
            targetHouseId: pick.houseId,
            targetName: pick.displayName,
            targetAvatar: pick.avatarUrl,
          ),
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
      SnackBar(
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

    final hasMappings = _mappings.isNotEmpty;
    final isEmptyState = _mappings.isEmpty && !_isCreating;

    int itemCount = 1;
    if (hasMappings) itemCount += 3 + _mappings.length;
    if (isEmptyState) itemCount += 2;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? colorScheme.surface : SLColors.paper;
    final borderColor = isDark
        ? colorScheme.outlineVariant
        : const Color(0xFFF0E5DF);
    final primaryText = isDark
        ? colorScheme.onSurface
        : const Color(0xFF2E2427);
    final secondaryText = isDark
        ? colorScheme.onSurfaceVariant
        : const Color(0xFF7A6B72);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.builder(
          physics: SLResponsive.scrollPhysicsForPlatform(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Semantics(
                container: true,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5E7E).withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.casino_rounded,
                        size: 40,
                        color: Color(0xFFFF5E7E),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('p9_match_chat_random_title'),
                        style: SLTheme.quicksand(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('p9_match_chat_random_subtitle'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isCreating ? null : _startRandomChat,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5E7E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isCreating
                              ? Semantics(
                                  label: context.tr('p9_match_chat_creating'),
                                  liveRegion: true,
                                  child: const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.chat_rounded),
                          label: Text(
                            context.tr(
                              _isCreating
                                  ? 'p9_match_chat_creating'
                                  : 'p9_match_chat_start',
                            ),
                            style: SLTheme.quicksand(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            int offset = 1;
            if (hasMappings) {
              if (index == offset) return const SizedBox(height: 18);
              if (index == offset + 1) {
                return Row(
                  children: [
                    Text(
                      context.tr('p9_match_chat_history'),
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: primaryText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      L10nService().format('p9_match_chat_people_count', {
                        'count': _mappings.length,
                      }),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? colorScheme.onSurfaceVariant
                            : SLColors.textTertiary,
                      ),
                    ),
                  ],
                );
              }
              if (index == offset + 2) return const SizedBox(height: 12);

              final mappingIndex = index - (offset + 3);
              if (mappingIndex < _mappings.length) {
                return _buildChatItem(_mappings[mappingIndex]);
              }
              offset += 3 + _mappings.length;
            }

            if (isEmptyState) {
              if (index == offset) return const SizedBox(height: 24);
              if (index == offset + 1) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 52,
                        color: isDark
                            ? colorScheme.onSurfaceVariant
                            : SLColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('p9_match_chat_empty_title'),
                        style: SLTheme.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? colorScheme.onSurface
                              : SLColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('p9_match_chat_empty_subtitle'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? colorScheme.onSurfaceVariant
                              : SLColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }
            }

            return const SizedBox.shrink();
          },
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? colorScheme.surface : SLColors.paper;
    final borderColor = isDark
        ? colorScheme.outlineVariant
        : const Color(0xFFF0E5DF);
    final primaryText = isDark
        ? colorScheme.onSurface
        : const Color(0xFF32203B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Semantics(
              image: true,
              label: L10nService().format('p9_match_chat_avatar_label', {
                'name': peerName,
              }),
              child: ExcludeSemantics(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFFDCE7),
                  backgroundImage: peerAvatar.isNotEmpty
                      ? CachedNetworkImageProvider(peerAvatar)
                      : null,
                  child: peerAvatar.isEmpty
                      ? Text(
                          peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
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
                      color: primaryText,
                    ),
                  ),
                  if (createdAt.isNotEmpty)
                    Text(
                      createdAt,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? colorScheme.onSurfaceVariant
                            : SLColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      myHouseId: widget.houseId,
                      targetHouseId: peerHouseId,
                      targetName: peerName,
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C61FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.chat_rounded, size: 16),
              label: Text(
                context.tr('p9_match_chat_message'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
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
