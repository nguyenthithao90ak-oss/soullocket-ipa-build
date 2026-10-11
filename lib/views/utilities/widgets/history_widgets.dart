import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/locale_date_format.dart';
import '../../../utils/services/activity_history_service.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/sl_detail_widgets.dart';

class ActivityHistoryContent extends StatelessWidget {
  const ActivityHistoryContent({
    super.key,
    required this.entries,
    required this.onRestore,
    this.loading = false,
    this.refreshing = false,
    this.restoringEntryId,
  });

  final List<ActivityHistoryEntry> entries;
  final ValueChanged<ActivityHistoryEntry> onRestore;
  final bool loading;
  final bool refreshing;
  final String? restoringEntryId;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            sliver: SliverToBoxAdapter(
              child: SLDetailCard(
                child: Row(
                  children: [
                    const SLDetailIcon(icon: Icons.history_rounded, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('detail_history_recent'),
                            style: SLTheme.quicksand(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: SLDetailStyle.text(context),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            L10nService().format('util_history_limit', {
                              'count': ActivityHistoryService.maxItems,
                            }),
                            style: SLTheme.quicksand(
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: SLDetailStyle.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (refreshing) ...[
                      const SizedBox(width: 8),
                      const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SLDetailStyle.secondary,
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Text(
                      '${entries.length}',
                      style: SLTheme.quicksand(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: SLDetailStyle.text(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                itemCount: 3,
                itemBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _ActivityHistorySkeleton(),
                ),
              ),
            )
          else if (entries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SLDetailCard(
                  child: Row(
                    children: [
                      const SLDetailIcon(
                        icon: Icons.history_toggle_off_rounded,
                        size: 48,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('util_chaclchsho_b9320d'),
                              style: SLTheme.quicksand(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: SLDetailStyle.text(context),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              context.tr('detail_history_empty_desc'),
                              style: SLTheme.quicksand(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: SLDetailStyle.muted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ActivityHistoryCard(
                    entry: entries[index],
                    restoring: restoringEntryId == entries[index].id,
                    onRestore: () => onRestore(entries[index]),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ActivityHistoryCard extends StatelessWidget {
  const ActivityHistoryCard({
    super.key,
    required this.entry,
    required this.onRestore,
    this.restoring = false,
  });

  final ActivityHistoryEntry entry;
  final VoidCallback onRestore;
  final bool restoring;

  IconData get _icon {
    if (entry.isVoicePreview) return Icons.mic_none_rounded;
    if (entry.isImagePreview) return Icons.photo_library_outlined;
    if (entry.module.contains('diary')) return Icons.edit_note_rounded;
    if (entry.module.contains('setting')) return Icons.tune_rounded;
    return Icons.history_rounded;
  }

  String _sourceLabel(BuildContext context) {
    if (entry.sourceLabel.trim().isNotEmpty) return entry.sourceLabel.trim();
    return switch (entry.module.trim().toLowerCase()) {
      'diary' || 'diary_memory' => context.tr('settings_group_diary_title'),
      'settings' => context.tr('settings'),
      'chat' => context.tr('history_source_chat'),
      _ => entry.effectiveSourceLabel,
    };
  }

  Widget _tag(BuildContext context, String label, Color color) {
    final accent = SLDetailStyle.accent(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: accent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SLDetailCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SLDetailIcon(
          icon: _icon,
          size: 36,
          color: entry.isImagePreview ? SLDetailStyle.rose : SLDetailStyle.blue,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.displayLine,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: SLDetailStyle.text(context),
                ),
              ),
              if (entry.subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  entry.subtitle.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    height: 1.5,
                    color: SLDetailStyle.muted(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (entry.hasPreview && entry.isImagePreview) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CachedNetworkImage(
                      imageUrl: entry.previewUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 150,
                      filterQuality: FilterQuality.medium,
                      placeholder: (_, _) => ColoredBox(
                        color: SLDetailStyle.background(context),
                        child: const Icon(
                          Icons.photo_outlined,
                          color: SLDetailStyle.secondary,
                        ),
                      ),
                      errorWidget: (_, _, _) => ColoredBox(
                        color: SLDetailStyle.background(context),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: SLDetailStyle.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    LocaleDateFormat.dateTime(
                      DateTime.fromMillisecondsSinceEpoch(entry.ts),
                    ),
                    style: SLTheme.quicksand(
                      fontSize: 11.5,
                      height: 1.4,
                      color: SLDetailStyle.muted(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (entry.effectiveSourceLabel.isNotEmpty)
                    _tag(
                      context,
                      _sourceLabel(context),
                      SLDetailStyle.secondary,
                    ),
                  if (entry.isRestoreExpired)
                    _tag(
                      context,
                      context.tr('util_qu3ngy_45ff69'),
                      SLDetailStyle.warning,
                    ),
                ],
              ),
              if (entry.canRestore) ...[
                const SizedBox(height: 4),
                SLDetailButton(
                  icon: restoring
                      ? Icons.hourglass_top_rounded
                      : Icons.restore_rounded,
                  label: context.tr(
                    restoring ? 'util_angkhiphc_4d5bed' : 'util_khiphc_682697',
                  ),
                  onPressed: restoring ? null : onRestore,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActivityHistorySkeleton extends StatelessWidget {
  const _ActivityHistorySkeleton();

  @override
  Widget build(BuildContext context) {
    final muted = SLDetailStyle.muted(context).withValues(alpha: 0.17);
    return SLDetailCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: muted,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: muted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 9),
                FractionallySizedBox(
                  widthFactor: 0.62,
                  child: Container(
                    height: 9,
                    decoration: BoxDecoration(
                      color: muted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
