import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/services/diary_reaction_service.dart';
import '../../../../../utils/services/l10n_service.dart';

Future<String?> showDiaryReactionPicker(
  BuildContext context, {
  String? selectedId,
  Map<String, int> counts = const <String, int>{},
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: false,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF25202E) : const Color(0xFFFFF9F5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFFFD9DD),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.14),
                blurRadius: 26,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.26)
                      : const Color(0xFFE9BFC6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('diary_reaction_choose'),
                      style: SLTheme.quicksand(
                        color: isDark ? Colors.white : const Color(0xFF4B3340),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(sheetContext)
                        .closeButtonTooltip,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? Colors.white70 : const Color(0xFF80626D),
                  ),
                ],
              ),
              Text(
                context.tr('diary_reaction_hint'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: isDark ? Colors.white60 : const Color(0xFF8B6E78),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: DiaryReactionService.options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.88,
                ),
                itemBuilder: (context, index) {
                  final option = DiaryReactionService.options[index];
                  final isSelected = option.id == selectedId;
                  final count = counts[option.id] ?? 0;
                  return Semantics(
                    button: true,
                    label: context.tr(option.labelKey),
                    selected: isSelected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(sheetContext).pop(option.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                    ? const Color(0xFF70495D)
                                    : const Color(0xFFFFE2E6))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF7E9B)
                                : Colors.transparent,
                            width: 1.6,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              option.assetPath,
                              width: 60,
                              height: 60,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                            if (count > 0)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 22),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF3C3046)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    textAlign: TextAlign.center,
                                    style: SLTheme.quicksand(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF63434E),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class DiaryReactionSummary extends StatelessWidget {
  final Map<String, int> counts;
  final String? selectedId;

  const DiaryReactionSummary({
    super.key,
    required this.counts,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final entries = DiaryReactionService.options
        .where((option) => (counts[option.id] ?? 0) > 0)
        .toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        for (final option in entries)
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(5, 3, 7, 3),
            decoration: BoxDecoration(
              color: option.id == selectedId
                  ? const Color(0xFFFFE0E8)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: option.id == selectedId
                    ? const Color(0xFFFF7E9B)
                    : const Color(0xFFFFD7DE),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(option.assetPath, width: 24, height: 24),
                const SizedBox(width: 3),
                Text(
                  '${counts[option.id]}',
                  style: SLTheme.quicksand(
                    color: const Color(0xFF67434F),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
