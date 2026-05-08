import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/security_protection_analytics_service.dart';
import '../../utils/services/security_protection_service.dart';
import 'security_protection_copy.dart';
import 'security_protection_help_screen.dart';

enum SecurityProtectionDialogAction {
  retry,
  openHelp,
  dismiss,
}

Future<SecurityProtectionDialogAction> showSecurityProtectionDialog(
  BuildContext context, {
  required SecurityProtectionVerdict verdict,
  String source = 'security_dialog',
  bool isDismissible = true,
}) async {
  if (verdict.effectiveRisk == SecurityProtectionRiskLevel.allow) {
    return SecurityProtectionDialogAction.retry;
  }

  final analyticsService = SecurityProtectionAnalyticsService();
  final navigator = Navigator.of(context);

  unawaited(
    analyticsService.logDecision(
      verdict: verdict,
      eventType: 'dialog_opened',
      source: source,
    ),
  );

  final action = await showModalBottomSheet<SecurityProtectionDialogAction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: isDismissible,
        enableDrag: isDismissible,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _SecurityProtectionDialogSheet(
          verdict: verdict,
        ),
      ) ??
      SecurityProtectionDialogAction.dismiss;

  await analyticsService.logDecision(
    verdict: verdict,
    eventType: switch (action) {
      SecurityProtectionDialogAction.retry => 'dialog_primary_tap',
      SecurityProtectionDialogAction.openHelp => 'dialog_help_tap',
      SecurityProtectionDialogAction.dismiss => 'dialog_dismissed',
    },
    source: source,
  );

  if (action == SecurityProtectionDialogAction.openHelp && navigator.mounted) {
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => SecurityProtectionHelpScreen(verdict: verdict),
      ),
    );
  }

  return action;
}

class _SecurityProtectionDialogSheet extends StatelessWidget {
  const _SecurityProtectionDialogSheet({
    required this.verdict,
  });

  final SecurityProtectionVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final copy = resolveSecurityProtectionCopy(context, verdict);
    final isBlocked = verdict.shouldBlock;
    final accent =
        isBlocked ? const Color(0xFFD32F2F) : const Color(0xFFF57C00);

    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFE),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7DCE8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    copy.badge,
                    style: SLTheme.quicksand(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  copy.title,
                  style: SLTheme.quicksand(
                    color: const Color(0xFF14213D),
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  copy.subtitle,
                  style: SLTheme.quicksand(
                    color: const Color(0xFF475467),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.52,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetaChip(
                      label: 'Mức rủi ro ${verdict.effectiveRisk.key}',
                      accent: accent,
                    ),
                    _MetaChip(
                      label: 'Lý do ${verdict.reason.key}',
                      accent: accent,
                    ),
                    _MetaChip(
                      label: 'Giai đoạn ${verdict.rolloutStage.key}',
                      accent: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accent.withValues(alpha: 0.16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cần làm gì ngay',
                        style: SLTheme.quicksand(
                          color: const Color(0xFF1F2A44),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var index = 0; index < copy.steps.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == copy.steps.length - 1 ? 0 : 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: SLTheme.quicksand(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  copy.steps[index],
                                  style: SLTheme.quicksand(
                                    color: const Color(0xFF344054),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pop(SecurityProtectionDialogAction.openHelp);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: accent.withValues(alpha: 0.28)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          copy.secondaryActionLabel,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            color: accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pop(SecurityProtectionDialogAction.retry);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          copy.primaryActionLabel,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context)
                          .pop(SecurityProtectionDialogAction.dismiss);
                    },
                    child: Text(
                      copy.dismissLabel,
                      style: SLTheme.quicksand(
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          color: const Color(0xFF344054),
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}
