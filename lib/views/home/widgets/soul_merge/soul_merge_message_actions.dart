import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';
import 'soul_merge_design.dart';
import 'soul_merge_reactions.dart';

enum SoulMessageAction { reply, copy, photo, removeReaction, hide, delete }

String soulMessagePreview(BuildContext context, Map<String, dynamic>? message) {
  if (message == null) return context.tr('p4_soul_reply_unavailable');
  final text = message['text']?.toString() ?? '';
  if (text.isNotEmpty) return text;
  final image = message['imageUrl']?.toString() ?? '';
  return SoulLocketStickerCatalog.find(image) != null ||
          image.startsWith('assets/')
      ? context.tr('sticker')
      : context.tr('p4_soul_message_photo');
}

class SoulMergeMessageActions extends StatelessWidget {
  const SoulMergeMessageActions({
    super.key,
    required this.message,
    required this.onAction,
    required this.onReaction,
    this.selectedReaction,
    this.canReply = true,
    this.canHide = true,
    this.canDelete = false,
    this.hasPhoto = false,
  });
  final Map<String, dynamic> message;
  final ValueChanged<SoulMessageAction> onAction;
  final ValueChanged<String>? onReaction;
  final String? selectedReaction;
  final bool canReply, canHide, canDelete, hasPhoto;

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> message, {
    required String? uid,
    required Future<void> Function(Map<String, dynamic>, String)? onReact,
    required Future<void> Function(Map<String, dynamic>)? onRemoveReaction,
    required Future<void> Function(Map<String, dynamic>)? onDelete,
    required Future<void> Function(Map<String, dynamic>)? onHide,
    required ValueChanged<Map<String, dynamic>>? onReply,
    required bool canDelete,
    required VoidCallback? onOpenPhoto,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    final raw = message['reactions'];
    final selected = raw is Map ? raw[uid]?.toString() : null;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SoulMergeMessageActions(
        message: message,
        selectedReaction: selected,
        canDelete: canDelete && onDelete != null,
        canHide: onHide != null,
        canReply: onReply != null,
        hasPhoto: onOpenPhoto != null,
        onReaction: onReact == null
            ? null
            : (value) => Navigator.pop(sheetContext, value),
        onAction: (value) => Navigator.pop(sheetContext, value),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice is String) {
      if (choice == selected && onRemoveReaction != null) {
        await onRemoveReaction(message);
      } else {
        await onReact?.call(message, choice);
      }
      return;
    }
    switch (choice as SoulMessageAction) {
      case SoulMessageAction.reply:
        onReply?.call(message);
      case SoulMessageAction.copy:
        await Clipboard.setData(
          ClipboardData(text: message['text']?.toString() ?? ''),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('p4_soul_action_copied'))),
          );
        }
      case SoulMessageAction.photo:
        onOpenPhoto?.call();
      case SoulMessageAction.removeReaction:
        await onRemoveReaction?.call(message);
      case SoulMessageAction.hide:
      case SoulMessageAction.delete:
        final hide = choice == SoulMessageAction.hide;
        final key = hide ? 'p4_soul_action_hide' : 'p4_soul_action_delete';
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.tr(key)),
            content: Text(
              context.tr(
                hide
                    ? 'p4_soul_action_hide_confirm'
                    : 'p4_soul_action_delete_confirm',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('core_cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.tr(key)),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          if (hide) {
            await onHide?.call(message);
          } else {
            await onDelete?.call(message);
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.line,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('p4_soul_action_react'),
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.blush,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        soulMessagePreview(context, message),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (onReaction != null) ...[
                      const SizedBox(height: 16),
                      SoulMergeReactionPicker(
                        onSelected: onReaction!,
                        selected: selectedReaction,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(color: colors.line),
                    if (canReply)
                      _tile(
                        context,
                        SoulMessageAction.reply,
                        Icons.reply_rounded,
                        'p4_soul_action_reply',
                      ),
                    if ((message['text']?.toString() ?? '').isNotEmpty)
                      _tile(
                        context,
                        SoulMessageAction.copy,
                        Icons.copy_rounded,
                        'p4_soul_action_copy',
                      ),
                    if (hasPhoto)
                      _tile(
                        context,
                        SoulMessageAction.photo,
                        Icons.open_in_full_rounded,
                        'p4_soul_action_view_photo',
                      ),
                    if (selectedReaction != null && onReaction != null)
                      _tile(
                        context,
                        SoulMessageAction.removeReaction,
                        Icons.heart_broken_outlined,
                        'p4_soul_action_remove_reaction',
                      ),
                    if (canHide)
                      _tile(
                        context,
                        SoulMessageAction.hide,
                        Icons.hide_source_rounded,
                        'p4_soul_action_hide',
                      ),
                    if (canDelete)
                      _tile(
                        context,
                        SoulMessageAction.delete,
                        Icons.delete_outline_rounded,
                        'p4_soul_action_delete',
                        destructive: true,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    SoulMessageAction action,
    IconData icon,
    String key, {
    bool destructive = false,
  }) {
    final colors = SoulMergeColors(context);
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : colors.ink;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 52,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.blush,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        context.tr(key),
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => onAction(action),
    );
  }
}
