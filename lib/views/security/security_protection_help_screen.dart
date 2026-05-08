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
          'Bảo vệ thao tác nhạy cảm',
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
                    color: const Color(0xFF475467),
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
                      label: 'Mức rủi ro: ${widget.verdict.effectiveRisk.key}',
                      accent: accent,
                    ),
                    _buildMetaChip(
                      label: 'Lý do: ${widget.verdict.reason.key}',
                      accent: accent,
                    ),
                    _buildMetaChip(
                      label: 'Giai đoạn: ${widget.verdict.rolloutStage.key}',
                      accent: accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildSectionCard(
            title: 'Cần làm gì ngay bây giờ',
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
            title: 'FAQ nhanh cho CSKH và người dùng',
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
                          color: const Color(0xFF475467),
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
            title: 'Nếu cần hỏi hỗ trợ',
            icon: Icons.support_agent_rounded,
            children: [
              Text(
                'Gửi kèm hành động, màn hình, mã lý do và các app đang chạy nền. Như vậy đội ngũ dễ phân biệt báo nhầm với thiết bị thực sự có rủi ro.',
                style: SLTheme.quicksand(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475467),
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
                    'Liên hệ hỗ trợ',
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
            isBlocked ? 'Tôi sẽ xử lý rồi thử lại sau' : 'Đã hiểu, tiếp tục',
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
