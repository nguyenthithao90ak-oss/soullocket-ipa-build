import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/sl_detail_widgets.dart';

class FriendlyChatLoading extends StatelessWidget {
  const FriendlyChatLoading({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SLDetailIcon(icon: Icons.chat_bubble_outline_rounded, size: 60),
          const SizedBox(height: 16),
          Text(
            context.tr('detail_chat_loading'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              height: 1.5,
              color: SLDetailStyle.muted(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: SLDetailStyle.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

class FriendlyChatTextBubble extends StatelessWidget {
  const FriendlyChatTextBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.onLongPress,
  });

  final String text;
  final bool isUser;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: onLongPress,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isUser ? SLDetailStyle.primary : SLDetailStyle.card(context),
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(20),
          topEnd: const Radius.circular(20),
          bottomStart: Radius.circular(isUser ? 20 : 6),
          bottomEnd: Radius.circular(isUser ? 6 : 20),
        ),
        border: isUser
            ? null
            : Border.all(color: SLDetailStyle.outline(context)),
      ),
      child: Text(
        text,
        style: SLTheme.quicksand(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.55,
          color: isUser ? Colors.white : SLDetailStyle.text(context),
        ),
      ),
    ),
  );
}

class FriendlyChatComposer extends StatelessWidget {
  const FriendlyChatComposer({
    super.key,
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Material(
    color: SLDetailStyle.card(context),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              style: SLTheme.quicksand(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: SLDetailStyle.text(context),
              ),
              decoration: InputDecoration(
                hintText: context.tr('util_nhpiubnmun_30266b'),
                hintStyle: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: SLDetailStyle.muted(context),
                ),
                filled: true,
                fillColor: SLDetailStyle.background(context),
                counterStyle: TextStyle(
                  color: SLDetailStyle.muted(context),
                  fontSize: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: SLDetailStyle.outline(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: SLDetailStyle.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: canSend ? onSend : null,
            tooltip: context.tr('detail_chat_send'),
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
            icon: const Icon(Icons.arrow_upward_rounded, size: 24),
          ),
        ],
      ),
    ),
  );
}
