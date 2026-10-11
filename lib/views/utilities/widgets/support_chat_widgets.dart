import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/sl_detail_widgets.dart';

enum SupportSender { user, assistant, team }

/// Nút hành động đi kèm một tin nhắn (ví dụ: hỏi lại AI, gửi cho đội ngũ).
class SupportChatAction {
  const SupportChatAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
}

class SupportChatItem {
  const SupportChatItem({
    required this.id,
    required this.text,
    required this.sender,
    required this.time,
    this.failed = false,
    this.actions = const [],
  });

  final String id;
  final String text;
  final SupportSender sender;
  final String time;

  /// Tin báo lỗi (AI không trả lời được) hiển thị khác màu để người dùng nhận ra ngay.
  final bool failed;
  final List<SupportChatAction> actions;
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

bool supportStatusIsTeam(String status) => const [
  'waiting_for_admin',
  'pending',
  'replied',
  'in_progress',
].contains(status);

bool supportStatusIsClosed(String status) =>
    status == 'resolved' || status == 'closed';

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
    required this.hasTicket,
    required this.sending,
    required this.onSend,
    required this.onBack,
    required this.onContactTeam,
    this.focusNode,
    this.guide,
    this.aiMode = true,
    this.thinking = false,
    this.notice,
    this.entryNotice,
    this.onEntryAction,
    this.onRetry,
    this.onReopen,
    this.loadingHistory = false,
  });

  final List<SupportChatItem> messages;
  final TextEditingController controller;
  final ScrollController scrollController;
  final String status;
  final bool hasTicket;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onBack;
  final VoidCallback onContactTeam;
  final FocusNode? focusNode;

  /// Khung hướng dẫn theo danh mục, đặt trước lịch sử trò chuyện.
  final Widget? guide;

  /// true: ô nhập hỏi trợ lý AI; false: nhắn trực tiếp cho đội ngũ hỗ trợ.
  final bool aiMode;
  final bool thinking;
  final String? notice;
  final String? entryNotice;

  /// Nút gửi lại tin chưa được xác nhận cho đội ngũ, hiện dưới [entryNotice].
  final VoidCallback? onEntryAction;
  final VoidCallback? onRetry;
  final VoidCallback? onReopen;
  final bool loadingHistory;

  @override
  Widget build(BuildContext context) {
    final closed = supportStatusIsClosed(status);
    final showStatus = closed || supportStatusIsTeam(status);
    return Scaffold(
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
                              context.tr('support_ui_guide_subtitle'),
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
                        onPressed: hasTicket ? onContactTeam : null,
                        tooltip: context.tr('support_ui_contact_team'),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(Icons.support_agent_rounded, size: 22),
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
                        return showStatus
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: SupportStatusCard(status: status),
                              )
                            : const SizedBox.shrink();
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
                            if (entryNotice != null && onEntryAction != null)
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton.icon(
                                  key: const Key('support-pending-resend'),
                                  onPressed: onEntryAction,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  icon: const Icon(Icons.support_agent_rounded),
                                  label: Text(context.tr('support_ui_contact_team')),
                                ),
                              ),
                          ],
                        );
                      }
                      if (index == 2) {
                        return guide == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: guide,
                              );
                      }
                      final message = messages[index - 3];
                      return SupportMessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                      );
                    },
                  ),
                ),
                if (loadingHistory) const LinearProgressIndicator(minHeight: 2),
                if (thinking)
                  SupportTypingIndicator(
                    text: context.tr('support_ui_ai_thinking'),
                  )
                else if (sending)
                  SupportTypingIndicator(
                    text: context.tr('support_ui_preparing'),
                    team: true,
                  ),
                if (closed && onReopen != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: FilledButton.icon(
                      onPressed: hasTicket && !sending ? onReopen : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(context.tr('support_ui_reopen')),
                    ),
                  ),
                if (!closed)
                  SupportComposer(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !sending && !thinking && (aiMode || hasTicket),
                    sending: sending || thinking,
                    hintText: context.tr(
                      aiMode ? 'support_ui_ai_input' : 'support_ui_team_input',
                    ),
                    onSend: onSend,
                    onContactTeam: hasTicket ? onContactTeam : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Trạng thái yêu cầu đã chuyển cho đội ngũ (chờ, đã phản hồi, đã đóng).
class SupportStatusCard extends StatelessWidget {
  const SupportStatusCard({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final replied = status == 'replied' || status == 'in_progress';
    final closed = supportStatusIsClosed(status);
    final team = supportStatusIsTeam(status);
    final titleKey = closed
        ? 'support_ui_closed'
        : replied
        ? 'support_ui_replied'
        : team
        ? 'support_ui_waiting'
        : 'support_ui_assistant';
    final detailKey = closed
        ? 'support_ui_closed_desc'
        : replied
        ? 'support_ui_replied_desc'
        : team
        ? 'support_ui_team_waiting_desc'
        : 'support_ui_assistant_desc';
    return SLDetailCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SupportAvatar(team: team || closed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(titleKey),
                  style: _supportText(context, size: 14, weight: FontWeight.w700),
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

class SupportMessageBubble extends StatelessWidget {
  const SupportMessageBubble({super.key, required this.message});
  final SupportChatItem message;

  @override
  Widget build(BuildContext context) {
    final mine = message.sender == SupportSender.user;
    final team = message.sender == SupportSender.team;
    final warning = SLDetailStyle.accent(context, SLDetailStyle.warning);
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
                        : message.failed
                        ? warning.withValues(alpha: 0.10)
                        : SLDetailStyle.card(context),
                    border: mine
                        ? null
                        : Border.all(
                            color: message.failed
                                ? warning.withValues(alpha: 0.45)
                                : SLDetailStyle.outline(context),
                          ),
                    borderRadius: BorderRadiusDirectional.only(
                      topStart: const Radius.circular(20),
                      topEnd: const Radius.circular(20),
                      bottomStart: Radius.circular(mine ? 20 : 6),
                      bottomEnd: Radius.circular(mine ? 6 : 20),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.failed) ...[
                        Icon(Icons.error_outline_rounded, size: 18, color: warning),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: SelectableText(
                          message.text,
                          style: _supportText(
                            context,
                            size: 14,
                            color: mine ? Colors.white : SLDetailStyle.text(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in message.actions)
                        action.primary
                            ? FilledButton.tonalIcon(
                                onPressed: action.onTap,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 44),
                                ),
                                icon: Icon(action.icon, size: 18),
                                label: Text(action.label),
                              )
                            : OutlinedButton.icon(
                                onPressed: action.onTap,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 44),
                                  foregroundColor: SLDetailStyle.text(context),
                                  side: BorderSide(
                                    color: SLDetailStyle.outline(context),
                                  ),
                                ),
                                icon: Icon(action.icon, size: 18),
                                label: Text(action.label),
                              ),
                    ],
                  ),
                ],
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
  const SupportTypingIndicator({
    super.key,
    required this.text,
    this.team = false,
  });

  final String text;
  final bool team;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: [
          SupportAvatar(size: 24, team: team),
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
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
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
    required this.hintText,
    required this.onSend,
    this.onContactTeam,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool sending;
  final String hintText;
  final VoidCallback onSend;
  final VoidCallback? onContactTeam;

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
          onPressed: onContactTeam,
          tooltip: context.tr('support_ui_contact_team'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.support_agent_rounded, size: 21),
          color: SLDetailStyle.muted(context),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
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
              hintText: hintText,
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
  Widget build(BuildContext context) => Padding(
    // Đẩy sheet lên trên bàn phím khi nhập nội dung gửi đội ngũ.
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
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
    ),
  );
}
