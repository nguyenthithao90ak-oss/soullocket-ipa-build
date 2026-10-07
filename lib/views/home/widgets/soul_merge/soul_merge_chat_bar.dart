import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';

import 'soul_merge_design.dart';
import 'soul_merge_photo_tile.dart';
import 'soul_merge_photo_viewer.dart';
import 'soul_merge_reactions.dart';
import 'soul_merge_message_actions.dart';
import 'soul_merge_live_message.dart';

class SoulMergeChatBar extends StatelessWidget {
  const SoulMergeChatBar({
    super.key,
    required this.chatHistory,
    required this.myRole,
    required this.partnerName,
    required this.spamWarning,
    required this.textController,
    required this.scrollController,
    required this.isUploadingPhoto,
    required this.lastAnyMsgTimestamp,
    required this.isMerged,
    required this.onSendCustomMessage,
    required this.onPickImage,
    required this.onShowSticker,
    required this.onSendPreset,
    required this.formatTime,
    this.isLoadingHistory = false,
    this.historyLoadFailed = false,
    this.onRetryHistory,
    this.onLoadOlder,
    this.imageProviderBuilder,
    this.composerFocusNode,
    this.replyTarget,
    this.onCancelReply,
    this.isSending = false,
    this.onReactMessage,
    this.onDeleteMessage,
    this.onReplyMessage,
    this.canDeleteMessage,
    this.onHideMessage,
    this.onRemoveReaction,
    this.currentUid,
    this.watchMessage,
    this.shouldWatchMessage,
    this.onMessageChanged,
  });

  final List<Map<String, dynamic>> chatHistory;
  final String myRole;
  final String partnerName;
  final String? spamWarning;
  final TextEditingController textController;
  final ScrollController scrollController;
  final bool isUploadingPhoto;
  final int lastAnyMsgTimestamp;
  final bool isMerged;
  final VoidCallback onSendCustomMessage;
  final VoidCallback onPickImage;
  final VoidCallback onShowSticker;
  final ValueChanged<String> onSendPreset;
  final String Function(int? timestamp) formatTime;
  final bool isLoadingHistory;
  final bool historyLoadFailed;
  final VoidCallback? onRetryHistory;
  final VoidCallback? onLoadOlder;
  final ImageProvider Function(String)? imageProviderBuilder;
  final FocusNode? composerFocusNode;
  final Map<String, dynamic>? replyTarget;
  final VoidCallback? onCancelReply;
  final bool isSending;
  final Future<void> Function(Map<String, dynamic>, String)? onReactMessage;
  final Future<void> Function(Map<String, dynamic>)? onDeleteMessage;
  final ValueChanged<Map<String, dynamic>>? onReplyMessage;
  final bool Function(Map<String, dynamic>)? canDeleteMessage;
  final Future<void> Function(Map<String, dynamic>)? onHideMessage;
  final Future<void> Function(Map<String, dynamic>)? onRemoveReaction;
  final String? currentUid;
  final Stream<Map<String, dynamic>?> Function(String)? watchMessage;
  final bool Function(String)? shouldWatchMessage;
  final void Function(String, Map<String, dynamic>?)? onMessageChanged;

  @override
  Widget build(BuildContext context) {
    final checkInPresets = <String>[
      L10nService().format('p4_soul_preset_check_in', {'name': partnerName}),
      L10nService().format('p4_soul_preset_hello', {'name': partnerName}),
      L10nService().format('p4_soul_preset_miss', {'name': partnerName}),
    ];
    final closePresets = <String>[
      context.tr('p4_soul_preset_love'),
      context.tr('p4_soul_preset_miss_short'),
      context.tr('p4_soul_preset_surprise'),
    ];
    final elapsedHours = lastAnyMsgTimestamp == 0
        ? 999.0
        : (DateTime.now().millisecondsSinceEpoch - lastAnyMsgTimestamp) /
              Duration.millisecondsPerHour;
    final presets = isMerged
        ? closePresets
        : (elapsedHours >= 24 ? checkInPresets : const <String>[]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: NotificationListener<OverscrollNotification>(
        onNotification: (notification) {
          if (!isLoadingHistory &&
              !historyLoadFailed &&
              notification.metrics.axisDirection == AxisDirection.up &&
              notification.metrics.extentAfter < 1 &&
              notification.overscroll > 0) {
            onLoadOlder?.call();
          }
          return false;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (spamWarning != null) ...[
              _MergeWarning(message: spamWarning!),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _MergeChatHistory(
                history: chatHistory,
                myRole: myRole,
                controller: scrollController,
                formatTime: formatTime,
                isLoading: isLoadingHistory,
                loadFailed: historyLoadFailed,
                onRetry: onRetryHistory,
                imageProviderBuilder: imageProviderBuilder,
                onReactMessage: onReactMessage,
                onDeleteMessage: onDeleteMessage,
                onReplyMessage: onReplyMessage,
                canDeleteMessage: canDeleteMessage,
                onHideMessage: onHideMessage,
                onRemoveReaction: onRemoveReaction,
                currentUid: currentUid,
                watchMessage: watchMessage,
                shouldWatchMessage: shouldWatchMessage,
                onMessageChanged: onMessageChanged,
              ),
            ),
            if (presets.isNotEmpty) ...[
              const SizedBox(height: 9),
              _MergePresetRow(presets: presets, onSelected: onSendPreset),
            ],
            const SizedBox(height: 10),
            if (replyTarget != null)
              _MergeReplyBanner(
                preview: soulMessagePreview(context, replyTarget),
                onCancel: onCancelReply,
              ),
            _MergeComposer(
              controller: textController,
              isUploadingPhoto: isUploadingPhoto,
              onPickImage: onPickImage,
              onShowSticker: onShowSticker,
              onSend: onSendCustomMessage,
              focusNode: composerFocusNode,
              isSending: isSending,
            ),
          ],
        ),
      ),
    );
  }
}

class _MergeWarning extends StatelessWidget {
  const _MergeWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5B8C2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFD64F69),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: SLTheme.quicksand(
                  color: const Color(0xFF94394D),
                  fontSize: 11.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MergeChatHistory extends StatelessWidget {
  const _MergeChatHistory({
    required this.history,
    required this.myRole,
    required this.controller,
    required this.formatTime,
    required this.isLoading,
    required this.loadFailed,
    required this.onRetry,
    this.imageProviderBuilder,
    this.onReactMessage,
    this.onDeleteMessage,
    this.onReplyMessage,
    this.canDeleteMessage,
    this.onHideMessage,
    this.onRemoveReaction,
    this.currentUid,
    this.watchMessage,
    this.shouldWatchMessage,
    this.onMessageChanged,
  });

  final List<Map<String, dynamic>> history;
  final String myRole;
  final ScrollController controller;
  final String Function(int? timestamp) formatTime;
  final bool isLoading;
  final bool loadFailed;
  final VoidCallback? onRetry;
  final ImageProvider Function(String)? imageProviderBuilder;
  final Future<void> Function(Map<String, dynamic>, String)? onReactMessage;
  final Future<void> Function(Map<String, dynamic>)? onDeleteMessage;
  final ValueChanged<Map<String, dynamic>>? onReplyMessage;
  final bool Function(Map<String, dynamic>)? canDeleteMessage;
  final Future<void> Function(Map<String, dynamic>)? onHideMessage;
  final Future<void> Function(Map<String, dynamic>)? onRemoveReaction;
  final String? currentUid;
  final Stream<Map<String, dynamic>?> Function(String)? watchMessage;
  final bool Function(String)? shouldWatchMessage;
  final void Function(String, Map<String, dynamic>?)? onMessageChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: history.isEmpty && !isLoading && !loadFailed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE6ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 18,
                        color: Color(0xFFE9577D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('p4_soul_chat_empty'),
                      style: SLTheme.quicksand(
                        color: const Color(0xFF8D7A82),
                        fontSize: 11.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            : RepaintBoundary(
                child: ListView.builder(
                  controller: controller,
                  reverse: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 12),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: history.length + (isLoading || loadFailed ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == history.length) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: isLoading
                              ? Semantics(
                                  label: context.tr(
                                    'p9_group_chat_loading_older_messages',
                                  ),
                                  child: const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: context.tr('calendar_retry_load'),
                                  onPressed: onRetry,
                                  icon: const Icon(Icons.refresh_rounded),
                                ),
                        ),
                      );
                    }
                    final position = history.length - 1 - index;
                    final message = history[position];
                    final previous = position > 0
                        ? history[position - 1]
                        : null;
                    final grouped =
                        previous != null &&
                        previous['sender'] == message['sender'] &&
                        ((message['timestamp'] as num? ?? 0) -
                                    (previous['timestamp'] as num? ?? 0))
                                .abs() <
                            180000;
                    final photos = history
                        .where((entry) {
                          final url = entry['imageUrl']?.toString() ?? '';
                          return url.startsWith('https://') ||
                              url.startsWith('http://');
                        })
                        .toList(growable: false);
                    final photoIndex = photos.indexWhere(
                      (entry) => identical(entry, message),
                    );
                    final replyId = message['replyTo']?.toString();
                    Map<String, dynamic>? quote;
                    for (final entry in history) {
                      if (entry['id'] == replyId) {
                        quote = entry;
                        break;
                      }
                    }
                    final bubble = _MergeMessageBubble(
                      key: ValueKey(message['id']),
                      isSelf: message['sender']?.toString() == myRole,
                      grouped: grouped,
                      onOpenPhoto: () => SoulMergePhotoViewer.show(
                        context,
                        urls: photos
                            .map((entry) => entry['imageUrl'].toString())
                            .toList(growable: false),
                        initialIndex: photoIndex < 0 ? 0 : photoIndex,
                        imageProviderBuilder: imageProviderBuilder,
                      ),
                      text: message['text']?.toString() ?? '',
                      imageUrl: message['imageUrl']?.toString() ?? '',
                      reactions: _readReactions(message['reactions']),
                      replyPreview: replyId == null
                          ? null
                          : soulMessagePreview(context, quote),
                      imageProvider: imageProviderBuilder?.call(
                        message['imageUrl']?.toString() ?? '',
                      ),
                      time: formatTime((message['timestamp'] as num?)?.toInt()),
                      onLongPress: () => SoulMergeMessageActions.show(
                        context,
                        message,
                        uid: currentUid,
                        onReact: onReactMessage,
                        onRemoveReaction: onRemoveReaction,
                        onHide: onHideMessage,
                        onDelete: onDeleteMessage,
                        onReply: onReplyMessage,
                        canDelete: canDeleteMessage?.call(message) ?? false,
                        onOpenPhoto: photoIndex < 0
                            ? null
                            : () => SoulMergePhotoViewer.show(
                                context,
                                urls: photos
                                    .map(
                                      (entry) => entry['imageUrl'].toString(),
                                    )
                                    .toList(growable: false),
                                initialIndex: photoIndex,
                                imageProviderBuilder: imageProviderBuilder,
                              ),
                      ),
                    );
                    return watchMessage == null || onMessageChanged == null
                        ? bubble
                        : SoulMergeLiveMessage(
                            key: ValueKey(message['id']),
                            messageId: message['id'].toString(),
                            watch: watchMessage!,
                            enabled:
                                shouldWatchMessage?.call(
                                  message['id'].toString(),
                                ) ??
                                true,
                            onChanged: onMessageChanged!,
                            child: bubble,
                          );
                  },
                ),
              ),
      ),
    );
  }

  static Map<String, String> _readReactions(Object? raw) {
    if (raw is! Map) return const <String, String>{};
    return raw.map<String, String>(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
}

class _MergeMessageBubble extends StatelessWidget {
  const _MergeMessageBubble({
    super.key,
    required this.isSelf,
    required this.grouped,
    required this.onOpenPhoto,
    this.imageProvider,
    required this.text,
    required this.imageUrl,
    required this.time,
    required this.reactions,
    this.onLongPress,
    this.replyPreview,
  });

  final bool isSelf;
  final bool grouped;
  final VoidCallback onOpenPhoto;
  final ImageProvider? imageProvider;
  final String text;
  final String imageUrl;
  final String time;
  final Map<String, String> reactions;
  final VoidCallback? onLongPress;
  final String? replyPreview;

  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    final localSticker = SoulLocketStickerCatalog.find(imageUrl);
    final isLegacySticker = imageUrl.startsWith(
      'assets/images/anhtomau_stickers/',
    );
    final isSticker = localSticker != null || isLegacySticker;
    final hasImage = imageUrl.isNotEmpty;

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(
            top: grouped ? 2 : 12,
            bottom: 3,
            left: isSelf ? 42 : 0,
            right: isSelf ? 0 : 42,
          ),
          padding: isSticker
              ? EdgeInsets.zero
              : hasImage
              ? const EdgeInsets.all(5)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: isSticker
              ? null
              : BoxDecoration(
                  color: isSelf ? colors.sent : colors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isSelf ? 18 : 5),
                    bottomRight: Radius.circular(isSelf ? 5 : 18),
                  ),
                  border: Border.all(color: isSelf ? colors.sent : colors.line),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF754653).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
          child: Column(
            crossAxisAlignment: isSelf
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyPreview != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isSelf
                        ? Colors.white.withValues(alpha: .16)
                        : colors.blush,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    replyPreview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelf ? Colors.white : colors.ink,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (hasImage)
                _MergeMessageMedia(
                  imageUrl: imageUrl,
                  localSticker: localSticker,
                  legacySticker: isLegacySticker,
                  onOpenPhoto: onOpenPhoto,
                  imageProvider: imageProvider,
                ),
              if (text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: hasImage ? 5 : 0),
                  child: Text(
                    text,
                    style: SLTheme.quicksand(
                      color: isSelf ? Colors.white : colors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              if (time.isNotEmpty && !isSticker)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    time,
                    style: SLTheme.quicksand(
                      color: isSelf
                          ? Colors.white.withValues(alpha: 0.78)
                          : colors.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: reactions.values
                        .map(
                          (reaction) => _SoulReactionChip(reference: reaction),
                        )
                        .toList(growable: false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoulReactionChip extends StatelessWidget {
  const _SoulReactionChip({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final spec = SoulMergeReactionCatalog.find(reference);
    final sticker = SoulLocketStickerCatalog.find(reference);
    if (spec == null || sticker == null) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: spec.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: SoulLocketAnimatedSticker(
          sticker: sticker,
          size: 25,
          animate: false,
          semanticLabel: context.tr(spec.labelKey),
        ),
      ),
    );
  }
}

class _MergeMessageMedia extends StatelessWidget {
  const _MergeMessageMedia({
    required this.imageUrl,
    required this.localSticker,
    required this.legacySticker,
    required this.onOpenPhoto,
    this.imageProvider,
  });

  final String imageUrl;
  final SoulLocketStickerSpec? localSticker;
  final bool legacySticker;
  final VoidCallback onOpenPhoto;
  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    if (localSticker != null) {
      return SoulLocketAnimatedSticker(sticker: localSticker!, size: 104);
    }
    if (legacySticker) {
      return Image.asset(imageUrl, fit: BoxFit.contain, width: 104);
    }
    return SoulMergePhotoTile(
      url: imageUrl,
      onOpen: onOpenPhoto,
      imageProvider: imageProvider,
    );
  }
}

class _MergePresetRow extends StatelessWidget {
  const _MergePresetRow({required this.presets, required this.onSelected});

  final List<String> presets;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets
            .map(
              (preset) => Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelected(preset),
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.line),
                      ),
                      child: Text(
                        preset,
                        style: SLTheme.quicksand(
                          color: colors.rose,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _MergeComposer extends StatelessWidget {
  const _MergeComposer({
    required this.controller,
    required this.isUploadingPhoto,
    required this.onPickImage,
    required this.onShowSticker,
    required this.onSend,
    this.focusNode,
    this.isSending = false,
  });

  final TextEditingController controller;
  final bool isUploadingPhoto;
  final VoidCallback onPickImage;
  final VoidCallback onShowSticker;
  final VoidCallback onSend;
  final FocusNode? focusNode;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF754653).withValues(alpha: 0.11),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
        child: Row(
          children: [
            _ComposerAction(
              onTap: isUploadingPhoto ? null : onPickImage,
              semanticLabel: context.tr('community_compose_action_photo'),
              icon: isUploadingPhoto ? null : Icons.add_photo_alternate_rounded,
              child: isUploadingPhoto
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE9577D),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 2),
            _ComposerAction(
              onTap: onShowSticker,
              icon: Icons.emoji_emotions_rounded,
              semanticLabel: context.tr('sticker'),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                style: SLTheme.quicksand(
                  color: colors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: context.tr('p4_soul_message_hint'),
                  hintStyle: SLTheme.quicksand(
                    color: colors.muted,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) {
                  if (!isSending) onSend();
                },
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isSending ? null : onSend,
                borderRadius: BorderRadius.circular(15),
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.sent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: isSending
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    required this.onTap,
    this.icon,
    this.child,
    this.semanticLabel,
  });

  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.blush,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: child ?? Icon(icon, color: colors.rose, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _MergeReplyBanner extends StatelessWidget {
  const _MergeReplyBanner({required this.preview, required this.onCancel});
  final String preview;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) {
    final colors = SoulMergeColors(context);
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: colors.blush,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: colors.rose, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('p4_soul_action_reply'),
                  style: TextStyle(
                    color: colors.rose,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.ink, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('p4_soul_reply_cancel'),
            onPressed: onCancel,
            icon: Icon(Icons.close_rounded, color: colors.muted),
          ),
        ],
      ),
    );
  }
}
