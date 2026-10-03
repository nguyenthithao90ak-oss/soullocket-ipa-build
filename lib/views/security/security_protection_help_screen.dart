import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/security_protection_analytics_service.dart';
import '../../utils/services/security_protection_service.dart';
import '../utilities/user_support_chat_screen.dart';
import 'security_protection_copy.dart';

class SecurityProtectionHelpScreen extends StatefulWidget {
  final SecurityProtectionVerdict verdict;

  const SecurityProtectionHelpScreen({
    super.key,
    required this.verdict,
  });

  @override
  State<SecurityProtectionHelpScreen> createState() =>
      _SecurityProtectionHelpScreenState();
}

class _SecurityProtectionHelpScreenState
    extends State<SecurityProtectionHelpScreen> {
  final SecurityProtectionAnalyticsService _analyticsService =
      SecurityProtectionAnalyticsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyticsService.logDecision(
        verdict: widget.verdict,
        eventType: 'help_opened',
        source: 'security_help_screen',
      );
    });
  }

  Future<void> _openSupport() async {
    await _analyticsService.logDecision(
      verdict: widget.verdict,
      eventType: 'support_opened',
      source: 'security_help_screen',
    );
    if (!mounted) return;
    final copy = resolveSecurityProtectionCopy(context, widget.verdict);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserSupportChatScreen(
          initialTopic: 'Bảo vệ thao tác nhạy cảm',
          initialDraft:
              '[${widget.verdict.reason.key}] ${copy.supportDraft}\nHành động: ${widget.verdict.actionId}\nMàn hình: ${widget.verdict.screenId}\nMã lý do: ${widget.verdict.reasonCode}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = resolveSecurityProtectionCopy(context, widget.verdict);
    final isBlocked = widget.verdict.shouldBlock;
    final accent =
        isBlocked ? const Color(0xFFD32F2F) : const Color(0xFFF57C00);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1F2A44),
        elevation: 0,
        title: Text(
          context.tr('ui_security_protect_sensitive_operations_009056'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1F2A44),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.14),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    fontSize: 22,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  copy.subtitle,
                  style: SLTheme.quicksand(
                    color: SLColors.textMedium,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildMetaChip(
                      label: L10nScope.of(context).format('ui_security_risk_level_value1_32a21e', {'value1': widget.verdict.effectiveRisk.key}),
                      accent: accent,
                    ),
                    _buildMetaChip(
                      label: L10nScope.of(context).format('ui_security_reason_value1_4442c8', {'value1': widget.verdict.reason.key}),
                      accent: accent,
                    ),
                    _buildMetaChip(
                      label: L10nScope.of(context).format('ui_security_phase_value1_68a79a', {'value1': widget.verdict.rolloutStage.key}),
                      accent: accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildSectionCard(
            title: context.tr('ui_security_what_to_do_now_4ced36'),
            icon: Icons.task_alt_rounded,
            children: [
              for (var index = 0; index < copy.steps.length; index++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == copy.steps.length - 1 ? 0 : 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          copy.steps[index],
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            height: 1.55,
                            color: const Color(0xFF344054),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: context.tr('ui_security_quick_faq_for_customer_service_and_users_b8feaa'),
            icon: Icons.help_outline_rounded,
            children: [
              for (final faq in copy.faqs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faq.question,
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1F2A44),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        faq.answer,
                        style: SLTheme.quicksand(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textMedium,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: context.tr('ui_security_if_needed_ask_for_support_7365ba'),
            icon: Icons.support_agent_rounded,
            children: [
              Text(
                context.tr('ui_security_include_actions_screens_reason_codes_and_apps_a25951'),
                style: SLTheme.quicksand(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: SLColors.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openSupport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD81B60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.support_agent_rounded),
                  label: Text(
                    context.tr('Liên hệ hỗ trợ'),
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            side: BorderSide(color: accent.withValues(alpha: 0.28)),
          ),
          child: Text(
            isBlocked ? context.tr('ui_security_i_ll_handle_it_and_try_again_d7f39e') : context.tr('ui_security_understood_continue_61278b'),
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required String label,
    required Color accent,
  }) {
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
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFD81B60)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: const Color(0xFF1F2A44),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
