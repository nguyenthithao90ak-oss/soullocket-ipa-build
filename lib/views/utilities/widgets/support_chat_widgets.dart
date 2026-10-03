import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/sl_detail_widgets.dart';
import '../support_ticket_shared.dart';

enum SupportSender { user, assistant, team }

class SupportChatItem {
  const SupportChatItem({
    required this.id,
    required this.text,
    required this.sender,
    required this.time,
    this.welcome = false,
  });

  final String id;
  final String text;
  final SupportSender sender;
  final String time;
  final bool welcome;
}

TextStyle _supportText(
  BuildContext context, {
  double size = 13,
  FontWeight weight = FontWeight.w500,
  Color? color,
}) => SLTheme.quicksand(
  fontSize: size,
  fontWeight: weight,
  color: color ?? SLDetailStyle.text(context),
  height: 1.45,
);

IconData supportTopicIcon(String id) => switch (id) {
  '1' => Icons.key_outlined,
  '2' => Icons.link_rounded,
  '3' => Icons.photo_library_outlined,
  '4' => Icons.verified_user_outlined,
  '5' => Icons.phonelink_ring_outlined,
  '6' => Icons.bug_report_outlined,
  '7' => Icons.favorite_border_rounded,
  '8' => Icons.manage_accounts_outlined,
  _ => Icons.support_agent_rounded,
};

String supportTopicLabel(BuildContext context, String id) => context
    .tr(switch (id) {
      '1' => 'util_tikhon_bbc710',
      '2' => 'util_ghpi_c374d8',
      '3' => 'util_hnhnh_c868d5',
      '4' => 'util_quynli_898c4c',
      '5' => 'util_ngb_0a52bc',
      '6' => 'util_boli_5df258',
      '7' => 'util_tnhcm_516e30',
      '8' => 'util_xatikhon_232744',
      _ => 'support_ui_team',
    })
    .replaceAll(RegExp(r'[🔑🔗📸💳📱🐞💖🗑️]', unicode: true), '')
    .trim();

class SupportAvatar extends StatelessWidget {
  const SupportAvatar({super.key, this.team = false, this.size = 36});

  final bool team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = SLDetailStyle.accent(
      context,
      team ? SLDetailStyle.sage : SLDetailStyle.blue,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Icon(
        team ? Icons.support_agent_rounded : Icons.auto_awesome_outlined,
        color: accent,
        size: size * 0.55,
      ),
    );
  }
}

class SupportChatView extends StatelessWidget {
  const SupportChatView({
    super.key,
    required this.messages,
    required this.controller,
    required this.scrollController,
    required this.status,
    required this.messageCount,
    required this.hasTicket,
    required this.sending,
    required this.onSend,
    required this.onBack,
    required this.onGuide,
    required this.onFaq,
    required this.onTopics,
    required this.onTopic,
    this.selectedTopicId,
    this.notice,
    this.entryNotice,
    this.onRetry,
    this.onReopen,
    this.loadingHistory = false,
  });

  final List<SupportChatItem> messages;
  final TextEditingController controller;
  final ScrollController scrollController;
  final String status;
  final int messageCount;
  final bool hasTicket;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onBack;
  final VoidCallback onGuide;
  final VoidCallback onFaq;
  final VoidCallback onTopics;
  final ValueChanged<String> onTopic;
  final String? selectedTopicId;
  final String? notice;
  final String? entryNotice;
  final VoidCallback? onRetry;
  final VoidCallback? onReopen;
  final bool loadingHistory;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SLDetailStyle.background(context),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const BackButtonIcon(),
                      color: SLDetailStyle.text(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('util_htrsoulloc_ed0178'),
                            style: _supportText(
                              context,
                              size: 17,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            context.tr('support_ui_subtitle'),
                            style: _supportText(
                              context,
                              size: 11,
                              color: SLDetailStyle.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onFaq,
                      tooltip: context.tr('util_cuhithnggp_65b83c'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.help_outline_rounded, size: 22),
                      color: SLDetailStyle.muted(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  key: const Key('support-conversation'),
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  itemCount: messages.length + 3,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SupportStatusCard(
                          status: status,
                          count: messageCount,
                          onGuide: onGuide,
                        ),
                      );
                    }
                    if (index == 1) {
                      return Column(
                        children: [
                          if (notice != null) SupportNotice(text: notice!),
                          if (notice != null && onRetry != null)
                            TextButton.icon(
                              onPressed: onRetry,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(context.tr('dialog_retry')),
                            ),
                          if (entryNotice != null)
                            SupportNotice(text: entryNotice!, warning: false),
                        ],
                      );
                    }
                    if (index == 2) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final id in ['1', '2', '3'])
                              SupportTopicButton(
                                id: id,
                                selected: selectedTopicId == id,
                                onTap: hasTicket && !sending
                                    && status != 'resolved' && status != 'closed'
                                    ? () => onTopic(id)
                                    : null,
                              ),
                            TextButton.icon(
                              onPressed: onTopics,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: SLDetailStyle.muted(context),
                              ),
                              icon: const Icon(
                                Icons.grid_view_rounded,
                                size: 17,
                              ),
                              label: Text(
                                context.tr('support_ui_topics'),
                                style: _supportText(context, size: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final message = messages[index - 3];
                    return message.welcome
                        ? const SupportWelcomeCard()
                        : SupportMessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                          );
                  },
                ),
              ),
              if (loadingHistory) const LinearProgressIndicator(minHeight: 2),
              if (sending) const SupportTypingIndicator(),
              if ((status == 'resolved' || status == 'closed') && onReopen != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton.icon(
                    onPressed: hasTicket && !sending ? onReopen : null,
                    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                    icon: const Icon(Icons.forum_outlined),
                    label: Text(context.tr('support_ui_reopen')),
                  ),
                ),
              if (status != 'resolved' && status != 'closed')
                SupportComposer(
                  controller: controller,
                  enabled: hasTicket && !sending,
                  sending: sending,
                  hasTicket: hasTicket,
                  onSend: onSend,
                  onGuide: onGuide,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SupportStatusCard extends StatelessWidget {
  const SupportStatusCard({
    super.key,
    required this.status,
    required this.count,
    required this.onGuide,
  });
  final String status;
  final int count;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    final waiting = status == 'waiting_for_admin' || status == 'pending';
    final replied = status == 'replied' || status == 'in_progress';
    final closed = status == 'resolved' || status == 'closed';
    final titleKey = closed
        ? 'support_ui_closed'
        : replied
        ? 'support_ui_replied'
        : waiting
        ? 'support_ui_waiting'
        : 'support_ui_assistant';
    final detailKey = closed
        ? 'support_ui_closed_desc'
        : replied
        ? 'support_ui_replied_desc'
        : waiting
        ? 'support_ui_waiting_desc'
        : 'support_ui_assistant_desc';
    return SLDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SupportAvatar(team: waiting || replied || closed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(titleKey),
                      style: _supportText(
                        context,
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(detailKey),
                      style: _supportText(
                        context,
                        size: 12,
                        color: SLDetailStyle.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onGuide,
                tooltip: context.tr('util_hngdngihtr_9c6550'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.info_outline_rounded, size: 20),
                color: SLDetailStyle.muted(context),
              ),
            ],
          ),
          if (!waiting && !replied && !closed) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: count.clamp(0, 5) / 5,
                minHeight: 3,
                backgroundColor: SLDetailStyle.outline(context),
                color: SLDetailStyle.accent(context, SLDetailStyle.sage),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              L10nService().format('support_ui_progress', {
                'count': count.clamp(0, 5),
              }),
              style: _supportText(
                context,
                size: 11,
                color: SLDetailStyle.muted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SupportNotice extends StatelessWidget {
  const SupportNotice({super.key, required this.text, this.warning = true});
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warning
              ? Icons.info_outline_rounded
              : Icons.subdirectory_arrow_right_rounded,
          size: 18,
          color: SLDetailStyle.muted(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: _supportText(
              context,
              size: 12,
              color: SLDetailStyle.muted(context),
            ),
          ),
        ),
      ],
    ),
  );
}

class SupportWelcomeCard extends StatelessWidget {
  const SupportWelcomeCard({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SupportAvatar(team: true, size: 56),
        const SizedBox(height: 18),
        Text(
          context.tr('support_ui_welcome'),
          style: _supportText(context, size: 24, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('support_ui_welcome_desc'),
          style: _supportText(
            context,
            size: 14,
            color: SLDetailStyle.muted(context),
          ),
        ),
      ],
    ),
  );
}

class SupportTopicButton extends StatelessWidget {
  const SupportTopicButton({
    super.key,
    required this.id,
    required this.onTap,
    this.selected = false,
  });
  final String id;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: SLDetailStyle.text(context),
        backgroundColor: selected
            ? SLDetailStyle.accent(
                context,
                SLDetailStyle.sage,
              ).withValues(alpha: 0.12)
            : SLDetailStyle.card(context),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(
          color: selected
              ? SLDetailStyle.accent(context, SLDetailStyle.sage)
              : SLDetailStyle.outline(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(supportTopicIcon(id), size: 17),
      label: Text(
        supportTopicLabel(context, id),
        style: _supportText(context, size: 12, weight: FontWeight.w600),
      ),
    ),
  );
}

class SupportMessageBubble extends StatelessWidget {
  const SupportMessageBubble({super.key, required this.message});
  final SupportChatItem message;

  @override
  Widget build(BuildContext context) {
    final mine = message.sender == SupportSender.user;
    final team = message.sender == SupportSender.team;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: mine
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * (mine ? 0.87 : 1),
            ),
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!mine) ...[
                  Row(
                    children: [
                      SupportAvatar(team: team, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr(
                            team ? 'support_ui_team' : 'support_ui_assistant',
                          ),
                          style: _supportText(
                            context,
                            size: 11,
                            weight: FontWeight.w600,
                            color: SLDetailStyle.muted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: mine
                        ? SLDetailStyle.primary
                        : SLDetailStyle.card(context),
                    border: mine
                        ? null
                        : Border.all(color: SLDetailStyle.outline(context)),
                    borderRadius: BorderRadiusDirectional.only(
                      topStart: const Radius.circular(20),
                      topEnd: const Radius.circular(20),
                      bottomStart: Radius.circular(mine ? 20 : 6),
                      bottomEnd: Radius.circular(mine ? 6 : 20),
                    ),
                  ),
                  child: SelectableText(
                    message.text,
                    style: _supportText(
                      context,
                      size: 14,
                      color: mine ? Colors.white : SLDetailStyle.text(context),
                    ),
                  ),
                ),
                if (message.time.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    message.time,
                    style: _supportText(
                      context,
                      size: 10.5,
                      color: SLDetailStyle.muted(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SupportTypingIndicator extends StatelessWidget {
  const SupportTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SupportAvatar(size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('support_ui_preparing'),
              style: _supportText(
                context,
                size: 12,
                color: SLDetailStyle.muted(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class SupportComposer extends StatelessWidget {
  const SupportComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.hasTicket,
    required this.onSend,
    required this.onGuide,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final bool hasTicket;
  final VoidCallback onSend;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: SLDetailStyle.card(context),
      border: Border(top: BorderSide(color: SLDetailStyle.outline(context))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          onPressed: onGuide,
          tooltip: context.tr('util_hngdngihtr_9c6550'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.assignment_outlined, size: 21),
          color: SLDetailStyle.muted(context),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            textInputAction: TextInputAction.send,
            onSubmitted: enabled
                ? (text) {
                    if (text.trim().isNotEmpty) onSend();
                  }
                : null,
            style: _supportText(context, size: 14),
            decoration: InputDecoration(
              hintText: context.tr(
                hasTicket ? 'support_ui_input' : 'util_ngnhpnhn_b4a68d',
              ),
              hintStyle: _supportText(
                context,
                size: 13,
                color: SLDetailStyle.muted(context),
              ),
              filled: true,
              fillColor: SLDetailStyle.background(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: SLDetailStyle.outline(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: SLDetailStyle.outline(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: SLDetailStyle.sage,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) => IconButton.filled(
            onPressed: enabled && value.text.trim().isNotEmpty ? onSend : null,
            tooltip: context.tr('support_ui_send'),
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: SLDetailStyle.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: SLDetailStyle.outline(context),
              disabledForegroundColor: SLDetailStyle.muted(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SLDetailStyle.primary,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded, size: 22),
          ),
        ),
      ],
    ),
  );
}

class SupportSheet extends StatelessWidget {
  const SupportSheet({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: 720,
      ),
      decoration: BoxDecoration(
        color: SLDetailStyle.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: SLDetailStyle.outline(context),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: _supportText(
                      context,
                      size: 18,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

class SupportTopicsContent extends StatelessWidget {
  const SupportTopicsContent({
    super.key,
    required this.onTopic,
    this.selectedId,
    this.enabled = true,
  });
  final ValueChanged<String> onTopic;
  final String? selectedId;
  final bool enabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 340 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final topic in supportTopicCatalog)
            SizedBox(
              width: width,
              child: SupportTopicButton(
                id: topic.id,
                selected: topic.id == selectedId,
                onTap: enabled ? () => onTopic(topic.id) : null,
              ),
            ),
        ],
      );
    },
  );
}

class SupportIntakeContent extends StatelessWidget {
  const SupportIntakeContent({
    super.key,
    required this.checklist,
    required this.badges,
    this.topic,
  });
  final List<String> checklist;
  final List<String> badges;
  final SupportTopicDefinition? topic;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        topic == null
            ? context.tr('support_ui_intake_desc')
            : supportTopicLabel(context, topic!.id),
        style: _supportText(context, size: 14, weight: FontWeight.w600),
      ),
      const SizedBox(height: 14),
      for (var index = 0; index < checklist.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SLDetailIcon(
                icon: Icons.check_rounded,
                color: SLDetailStyle.sage,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(checklist[index], style: _supportText(context)),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      SupportNotice(text: context.tr('support_ui_safety')),
      if (badges.isNotEmpty) ...[
        const Divider(height: 24),
        Text(
          context.tr('util_thngtintnh_78ed0b'),
          style: _supportText(context, size: 12, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final badge in badges)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              badge,
              style: _supportText(
                context,
                size: 12,
                color: SLDetailStyle.muted(context),
              ),
            ),
          ),
      ],
    ],
  );
}

class SupportFaqContent extends StatelessWidget {
  const SupportFaqContent({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in [
        ('util_qunmtkhu_a9a074', 'util_citbomtimt_83d047'),
        ('util_appbli_92e3fa', 'util_thtthonton_f1e6df'),
        ('util_kimtraquyn_4de2fd', 'util_mcittikhon_4429d3'),
        ('util_xatikhon_348215', 'util_citxatikho_9cdf64'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SLDetailDisclosure(
            icon: Icons.help_outline_rounded,
            title: context.tr(item.$1),
            child: Text(context.tr(item.$2), style: _supportText(context)),
          ),
        ),
    ],
  );
}
