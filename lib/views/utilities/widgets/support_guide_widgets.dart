import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/sl_detail_widgets.dart';
import '../support_guide_catalog.dart';

enum SupportGuideFeedback { none, resolved, unresolved }

TextStyle _guideText(
  BuildContext context, {
  double size = 13,
  FontWeight weight = FontWeight.w500,
  Color? color,
  double height = 1.45,
}) => SLTheme.quicksand(
  fontSize: size,
  fontWeight: weight,
  color: color ?? SLDetailStyle.text(context),
  height: height,
);

/// Khung tự trợ giúp: chọn mục → chọn vấn đề → xem cách xử lý từng bước.
/// Widget chỉ trình bày; trạng thái và hành động do màn hỗ trợ quản lý.
class SupportGuidePanel extends StatelessWidget {
  const SupportGuidePanel({
    super.key,
    required this.categoryId,
    required this.issueId,
    required this.feedback,
    required this.onCategory,
    required this.onIssue,
    required this.onBackToCategories,
    required this.onBackToIssues,
    required this.onFeedback,
    required this.onAskAi,
    required this.onContactTeam,
    this.onEmail,
    this.teamAvailable = true,
  });

  final String? categoryId;
  final String? issueId;
  final SupportGuideFeedback feedback;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onIssue;
  final VoidCallback onBackToCategories;
  final VoidCallback onBackToIssues;
  final ValueChanged<bool> onFeedback;
  final VoidCallback onAskAi;
  final VoidCallback onContactTeam;
  final VoidCallback? onEmail;
  final bool teamAvailable;

  @override
  Widget build(BuildContext context) {
    final category = supportGuideCategoryById(categoryId);
    final issue = supportGuideIssue(categoryId, issueId);
    return SLDetailCard(
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        child: category == null
            ? _CategoryPicker(
                onCategory: onCategory,
                nextSteps: _NextSteps(
                  onAskAi: onAskAi,
                  onContactTeam: teamAvailable ? onContactTeam : null,
                  onEmail: onEmail,
                ),
              )
            : issue == null
            ? _IssueList(
                category: category,
                onBack: onBackToCategories,
                onIssue: onIssue,
                nextSteps: _NextSteps(
                  onAskAi: onAskAi,
                  onContactTeam: teamAvailable ? onContactTeam : null,
                  onEmail: onEmail,
                ),
              )
            : _AnswerView(
                category: category,
                issue: issue,
                feedback: feedback,
                onBack: onBackToIssues,
                onBackToCategories: onBackToCategories,
                onFeedback: onFeedback,
                nextSteps: _NextSteps(
                  onAskAi: onAskAi,
                  onContactTeam: teamAvailable ? onContactTeam : null,
                  onEmail: onEmail,
                ),
              ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.onCategory, required this.nextSteps});

  final ValueChanged<String> onCategory;
  final Widget nextSteps;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('support_ui_pick_title'),
        style: _guideText(context, size: 19, weight: FontWeight.w700, height: 1.3),
      ),
      const SizedBox(height: 4),
      Text(
        context.tr('support_ui_pick_desc'),
        style: _guideText(context, size: 12.5, color: SLDetailStyle.muted(context)),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns =
              constraints.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          final tiles = [
            for (final category in supportGuideCategories)
              _CategoryTile(
                category: category,
                onTap: () => onCategory(category.id),
              ),
          ];
          if (!twoColumns) {
            return Column(
              children: [
                for (final tile in tiles)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: tile),
              ],
            );
          }
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: tiles[i]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: i + 1 < tiles.length
                              ? tiles[i + 1]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 6),
      Text(
        context.tr('support_ui_not_found'),
        style: _guideText(context, size: 13, weight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      nextSteps,
    ],
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final SupportGuideCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = SLDetailStyle.accent(context, category.color);
    return Material(
      key: Key('support-guide-category-${category.id}'),
      color: accent.withValues(alpha: SLDetailStyle.isDark(context) ? 0.14 : 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SLDetailIcon(icon: category.icon, color: category.color, size: 34),
                const SizedBox(height: 8),
                Text(
                  context.tr(category.titleKey),
                  style: _guideText(context, size: 13.5, weight: FontWeight.w700, height: 1.25),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(category.descKey),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _guideText(
                    context,
                    size: 11.5,
                    color: SLDetailStyle.muted(context),
                    height: 1.35,
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

class _BackRow extends StatelessWidget {
  const _BackRow({required this.label, required this.onBack});

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      onPressed: onBack,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        padding: const EdgeInsetsDirectional.only(start: 4, end: 10),
        foregroundColor: SLDetailStyle.muted(context),
      ),
      icon: const BackButtonIcon(),
      label: Text(label, style: _guideText(context, size: 12.5, weight: FontWeight.w600)),
    ),
  );
}

class _IssueList extends StatelessWidget {
  const _IssueList({
    required this.category,
    required this.onBack,
    required this.onIssue,
    required this.nextSteps,
  });

  final SupportGuideCategory category;
  final VoidCallback onBack;
  final ValueChanged<String> onIssue;
  final Widget nextSteps;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _BackRow(label: context.tr('support_ui_all_topics'), onBack: onBack),
      const SizedBox(height: 4),
      Row(
        children: [
          SLDetailIcon(icon: category.icon, color: category.color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr(category.titleKey),
              style: _guideText(context, size: 17, weight: FontWeight.w700, height: 1.3),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        context.tr('support_ui_pick_issue'),
        style: _guideText(context, size: 12.5, color: SLDetailStyle.muted(context)),
      ),
      const SizedBox(height: 10),
      for (final issue in category.issues)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            key: Key('support-guide-issue-${issue.key}'),
            color: SLDetailStyle.background(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: SLDetailStyle.outline(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onIssue(issue.id),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          supportGuideText(issue.titleKey, context.tr),
                          style: _guideText(context, size: 14, weight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: SLDetailStyle.muted(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        context.tr('support_ui_not_found'),
        style: _guideText(context, size: 13, weight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      nextSteps,
    ],
  );
}

class _AnswerView extends StatelessWidget {
  const _AnswerView({
    required this.category,
    required this.issue,
    required this.feedback,
    required this.onBack,
    required this.onBackToCategories,
    required this.onFeedback,
    required this.nextSteps,
  });

  final SupportGuideCategory category;
  final SupportGuideIssue issue;
  final SupportGuideFeedback feedback;
  final VoidCallback onBack;
  final VoidCallback onBackToCategories;
  final ValueChanged<bool> onFeedback;
  final Widget nextSteps;

  @override
  Widget build(BuildContext context) {
    final steps = supportGuideSteps(issue, context.tr);
    final accent = SLDetailStyle.accent(context, category.color);
    final sage = SLDetailStyle.accent(context, SLDetailStyle.sage);
    return Column(
      key: Key('support-guide-answer-${issue.key}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackRow(label: context.tr(category.titleKey), onBack: onBack),
        const SizedBox(height: 4),
        Text(
          supportGuideText(issue.titleKey, context.tr),
          style: _guideText(context, size: 18, weight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${context.tr('support_ui_why')} ',
                        style: _guideText(context, size: 13, weight: FontWeight.w700),
                      ),
                      TextSpan(text: supportGuideText(issue.whyKey, context.tr)),
                    ],
                  ),
                  style: _guideText(context, size: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('support_ui_steps'),
          style: _guideText(context, size: 14, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: _guideText(
                      context,
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: accent,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(steps[i], style: _guideText(context, size: 14)),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 24),
        switch (feedback) {
          SupportGuideFeedback.none => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('support_ui_helpful_q'),
                style: _guideText(context, size: 13.5, weight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('support-guide-resolved'),
                    onPressed: () => onFeedback(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: sage,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(context.tr('support_ui_resolved')),
                  ),
                  OutlinedButton.icon(
                    key: const Key('support-guide-unresolved'),
                    onPressed: () => onFeedback(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: SLDetailStyle.text(context),
                      side: BorderSide(color: SLDetailStyle.outline(context)),
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: Text(context.tr('support_ui_not_resolved')),
                  ),
                ],
              ),
            ],
          ),
          SupportGuideFeedback.resolved => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: sage, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('support_ui_resolved_msg'),
                      style: _guideText(context, size: 13.5, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onBackToCategories,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.grid_view_rounded, size: 18),
                  label: Text(context.tr('support_ui_other_issue')),
                ),
              ),
            ],
          ),
          SupportGuideFeedback.unresolved => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('support_ui_next_step'),
                style: _guideText(context, size: 13.5, weight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              nextSteps,
            ],
          ),
        },
      ],
    );
  }
}

/// Hai lối tiếp theo luôn rõ ràng: hỏi AI ngay hoặc gửi cho người thật.
class _NextSteps extends StatelessWidget {
  const _NextSteps({
    required this.onAskAi,
    required this.onContactTeam,
    this.onEmail,
  });

  final VoidCallback onAskAi;
  final VoidCallback? onContactTeam;
  final VoidCallback? onEmail;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _NextStepTile(
        key: const Key('support-guide-ask-ai'),
        icon: Icons.auto_awesome_outlined,
        color: SLDetailStyle.blue,
        title: context.tr('support_ui_ask_ai'),
        description: context.tr('support_ui_ask_ai_desc'),
        onTap: onAskAi,
      ),
      const SizedBox(height: 8),
      _NextStepTile(
        key: const Key('support-guide-contact-team'),
        icon: Icons.support_agent_rounded,
        color: SLDetailStyle.sage,
        title: context.tr('support_ui_contact_team'),
        description: context.tr('support_ui_contact_team_desc'),
        onTap: onContactTeam,
      ),
      if (onEmail != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onEmail,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: SLDetailStyle.muted(context),
            ),
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            label: Text(context.tr('support_ui_email')),
          ),
        ),
    ],
  );
}

class _NextStepTile extends StatelessWidget {
  const _NextStepTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: SLDetailStyle.background(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: SLDetailStyle.outline(context)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: Row(
              children: [
                SLDetailIcon(icon: icon, color: color, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: _guideText(context, size: 14, weight: FontWeight.w700),
                      ),
                      Text(
                        description,
                        style: _guideText(
                          context,
                          size: 11.5,
                          color: SLDetailStyle.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: SLDetailStyle.muted(context)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Nội dung sheet "Gửi cho đội ngũ hỗ trợ": người dùng sửa mô tả rồi gửi.
class SupportTeamSheetContent extends StatefulWidget {
  const SupportTeamSheetContent({
    super.key,
    required this.initialText,
    required this.onSubmit,
    this.attached = const [],
    this.onEmail,
  });

  final String initialText;
  final Future<bool> Function(String text) onSubmit;
  final List<String> attached;
  final VoidCallback? onEmail;

  @override
  State<SupportTeamSheetContent> createState() => _SupportTeamSheetContentState();
}

class _SupportTeamSheetContentState extends State<SupportTeamSheetContent> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.onSubmit(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('support_ui_team_sheet_desc'),
        style: _guideText(context, size: 13, color: SLDetailStyle.muted(context)),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('support-team-field'),
        controller: _controller,
        enabled: !_sending,
        minLines: 4,
        maxLines: 8,
        maxLength: 1000,
        style: _guideText(context, size: 14),
        decoration: InputDecoration(
          labelText: context.tr('support_ui_team_field'),
          alignLabelWithHint: true,
          filled: true,
          fillColor: SLDetailStyle.background(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.attach_file_rounded, size: 16, color: SLDetailStyle.muted(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [
                context.tr('support_ui_team_attached'),
                if (widget.attached.isNotEmpty) widget.attached.join(' · '),
              ].join('\n'),
              style: _guideText(context, size: 11.5, color: SLDetailStyle.muted(context)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: SLDetailStyle.muted(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.tr('support_ui_safety'),
              style: _guideText(context, size: 11.5, color: SLDetailStyle.muted(context)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => FilledButton.icon(
          key: const Key('support-team-send'),
          onPressed: !_sending && value.text.trim().isNotEmpty ? _submit : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 50),
            backgroundColor: SLDetailStyle.primary,
            foregroundColor: Colors.white,
          ),
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(context.tr('support_ui_team_send')),
        ),
      ),
      if (widget.onEmail != null) ...[
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _sending ? null : widget.onEmail,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.mail_outline_rounded, size: 18),
          label: Text(context.tr('support_ui_email')),
        ),
      ],
    ],
  );
}
