import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';
import 'soul_merge_design.dart';
import 'soul_merge_reactions.dart';

enum SoulMessageAction { reply, copy, photo, removeReaction, pin, hide, delete }

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
    this.compact = false,
    this.isPinned = false,
    this.onPin,
    this.onUnpin,
  });
  final Map<String, dynamic> message;
  final ValueChanged<SoulMessageAction> onAction;
  final ValueChanged<String>? onReaction;
  final String? selectedReaction;
  final bool canReply, canHide, canDelete, hasPhoto, compact;
  final bool isPinned;
  final Future<void> Function(Map<String, dynamic>)? onPin;
  final Future<void> Function(Map<String, dynamic>)? onUnpin;

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
    required bool isPinned,
    required Future<void> Function(Map<String, dynamic>)? onPin,
    required Future<void> Function(Map<String, dynamic>)? onUnpin,
    Rect? anchor,
    bool isSelf = false,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    final raw = message['reactions'];
    final selected = raw is Map ? raw[uid]?.toString() : null;
    final choice = await showGeneralDialog<Object>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: .22),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      transitionBuilder: (context, animation, secondary, child) =>
          FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: .97, end: 1.0).animate(animation),
              child: child,
            ),
          ),
      pageBuilder: (menuContext, animation, secondary) =>
          CustomSingleChildLayout(
            delegate: SoulMessageMenuLayout(
              anchor:
                  anchor ??
                  Rect.fromCenter(
                    center: MediaQuery.sizeOf(context).center(Offset.zero),
                    width: 1,
                    height: 1,
                  ),
              isSelf: isSelf,
              padding: MediaQuery.paddingOf(menuContext),
              keyboard: MediaQuery.viewInsetsOf(menuContext).bottom,
            ),
            child: SoulMergeMessageActions(
              compact: true,
              message: message,
              selectedReaction: selected,
              canDelete: canDelete && onDelete != null,
              canHide: onHide != null,
              canReply: onReply != null,
              hasPhoto: onOpenPhoto != null,
              isPinned: isPinned,
              onPin: onPin,
              onUnpin: onUnpin,
              onReaction: onReact == null
                  ? null
                  : (value) => Navigator.pop(menuContext, value),
              onAction: (value) => Navigator.pop(menuContext, value),
            ),
          ),
    );
    if (!context.mounted || choice == null) return;
    // Menu vừa pop nhưng ScreenActivityMixin chỉ cập nhật route ở frame kế.
    // Đợi frame đó trước callback để thao tác ghim/cảm xúc không bị bỏ qua.
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return;
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
      case SoulMessageAction.pin:
        if (isPinned) {
          await onUnpin?.call(message);
        } else {
          await onPin?.call(message);
        }
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
            key: const ValueKey('soul-message-floating-menu'),
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
                    if (!compact)
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
                    SizedBox(height: compact ? 4 : 16),
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
                        maxLines: compact ? 1 : 3,
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
                        compact: compact,
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
                    if (onPin != null || onUnpin != null)
                      _tile(
                        context,
                        SoulMessageAction.pin,
                        isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        isPinned ? 'p5_notif_unpin' : 'p5_notif_pin',
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
      minTileHeight: 48,
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

/// Giữ menu gần tin đang chọn và trong vùng an toàn, kể cả khi bàn phím mở.
class SoulMessageMenuLayout extends SingleChildLayoutDelegate {
  SoulMessageMenuLayout({
    required this.anchor,
    required this.isSelf,
    required this.padding,
    required this.keyboard,
  });
  final Rect anchor;
  final bool isSelf;
  final EdgeInsets padding;
  final double keyboard;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: math.min(352, constraints.maxWidth - 24),
        maxWidth: math.min(352, constraints.maxWidth - 24),
        maxHeight: math.max(
          0,
          math.min(
            500,
            constraints.maxHeight -
                padding.top -
                math.max(padding.bottom, keyboard) -
                24,
          ),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = padding.top + 8;
    final bottom = size.height - math.max(padding.bottom, keyboard) - 8;
    final below = anchor.bottom + 8;
    final above = anchor.top - childSize.height - 8;
    final y = below + childSize.height <= bottom
        ? below
        : above >= top
        ? above
        : (anchor.center.dy - childSize.height / 2).clamp(
            top,
            math.max(top, bottom - childSize.height),
          );
    final x = (isSelf ? anchor.right - childSize.width : anchor.left).clamp(
      12.0,
      math.max(12.0, size.width - childSize.width - 12),
    );
    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  bool shouldRelayout(covariant SoulMessageMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      padding != oldDelegate.padding ||
      keyboard != oldDelegate.keyboard ||
      isSelf != oldDelegate.isSelf;
}
