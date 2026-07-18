import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import '../../../../core/sl_theme.dart';
import 'creative_diary_controller.dart'; 

class CreativeDiaryHeader extends StatelessWidget {
  final bool hasPages;
  final int safeIndex;
  final int totalPages;
  final DiaryPageData? activePage;
  final bool compact;
  final bool compactHeight;

  const CreativeDiaryHeader({
    super.key,
    required this.hasPages,
    required this.safeIndex,
    required this.totalPages,
    required this.activePage,
    required this.compact,
    required this.compactHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compactHeight ? 8 : 12,
        compact ? 12 : 14,
        0,
      ),
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.72),
            width: 1.6,
          ),
          boxShadow: SLTheme.cardShadow,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 340;
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPages
                      ? 'Trang ${safeIndex + 1}/$totalPages'
                      : L10nService().translate('util_stayringca_d5d3c4'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                    color: SLColors.primaryActive,
                    letterSpacing: 0.2,
                  ),
                ),
                SLSpacing.h8,
                Text(
                  activePage?.content ??
                      L10nService().translate('util_staycahaib_a09d75'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: compact ? 17 : 18,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                SLSpacing.h8,
                Text(
                  activePage == null
                      ? L10nService().translate('util_lulinhngdn_f942d3')
                      : L10nService().format(
                          'util_diary_saved_date', {
                          'date': DateFormat('dd/MM/yyyy')
                              .format(DateTime.fromMillisecondsSinceEpoch(activePage!.createdAtMs))
                        }),
                  style: SLTheme.quicksand(
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w600,
                    color: SLColors.textSecondary,
                  ),
                ),
              ],
            );

            // chip
            final chip = Container(
              constraints: BoxConstraints(
                maxWidth: narrow ? constraints.maxWidth : constraints.maxWidth * 0.28,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SLColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_rounded, color: SLColors.primaryActive, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      activePage?.authorName ?? 'You',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SLColors.primaryActive,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  SLSpacing.h12,
                  chip,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: info),
                const SizedBox(width: 12),
                chip,
              ],
            );
          },
        ),
      ),
    );
  }
}
