import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/soullocket_animated_sticker.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (spamWarning != null) ...[
            _MergeWarning(message: spamWarning!),
            const SizedBox(height: 8),
          ],
          _MergeChatHistory(
            history: chatHistory,
            myRole: myRole,
            controller: scrollController,
            formatTime: formatTime,
          ),
          if (presets.isNotEmpty) ...[
            const SizedBox(height: 9),
            _MergePresetRow(presets: presets, onSelected: onSendPreset),
          ],
          const SizedBox(height: 10),
          _MergeComposer(
            controller: textController,
            isUploadingPhoto: isUploadingPhoto,
            onPickImage: onPickImage,
            onShowSticker: onShowSticker,
            onSend: onSendCustomMessage,
          ),
        ],
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
  });

  final List<Map<String, dynamic>> history;
  final String myRole;
  final ScrollController controller;
  final String Function(int? timestamp) formatTime;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.96)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF935363).withValues(alpha: 0.09),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: history.isEmpty
            ? SizedBox(
                height: 94,
                child: Center(
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
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: RepaintBoundary(
                  child: ListView.builder(
                    controller: controller,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final message = history.reversed.elementAt(index);
                      return _MergeMessageBubble(
                        isSelf: message['sender']?.toString() == myRole,
                        text: message['text']?.toString() ?? '',
                        imageUrl: message['imageUrl']?.toString() ?? '',
                        time: formatTime(message['timestamp'] as int?),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

class _MergeMessageBubble extends StatelessWidget {
  const _MergeMessageBubble({
    required this.isSelf,
    required this.text,
    required this.imageUrl,
    required this.time,
  });

  final bool isSelf;
  final String text;
  final String imageUrl;
  final String time;

  @override
  Widget build(BuildContext context) {
    final localSticker = SoulLocketStickerCatalog.find(imageUrl);
    final isLegacySticker = imageUrl.startsWith(
      'assets/images/anhtomau_stickers/',
    );
    final isSticker = localSticker != null || isLegacySticker;
    final hasImage = imageUrl.isNotEmpty;

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: isSelf ? 56 : 0,
          right: isSelf ? 0 : 56,
        ),
        padding: isSticker
            ? EdgeInsets.zero
            : hasImage
            ? const EdgeInsets.all(5)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: isSticker
            ? null
            : BoxDecoration(
                color: isSelf ? const Color(0xFFE9587E) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isSelf ? 18 : 5),
                  bottomRight: Radius.circular(isSelf ? 5 : 18),
                ),
                border: Border.all(
                  color: isSelf
                      ? const Color(0xFFE9587E)
                      : const Color(0xFFF0E1E5),
                ),
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
            if (hasImage)
              _MergeMessageMedia(
                imageUrl: imageUrl,
                localSticker: localSticker,
                legacySticker: isLegacySticker,
              ),
            if (text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: hasImage ? 5 : 0),
                child: Text(
                  text,
                  style: SLTheme.quicksand(
                    color: isSelf ? Colors.white : const Color(0xFF43363D),
                    fontSize: 13.4,
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
                        : const Color(0xFF9B8A91),
                    fontSize: 9.5,
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

class _MergeMessageMedia extends StatelessWidget {
  const _MergeMessageMedia({
    required this.imageUrl,
    required this.localSticker,
    required this.legacySticker,
  });

  final String imageUrl;
  final SoulLocketStickerSpec? localSticker;
  final bool legacySticker;

  @override
  Widget build(BuildContext context) {
    if (localSticker != null) {
      return SoulLocketAnimatedSticker(sticker: localSticker!, size: 146);
    }
    if (legacySticker) {
      return Image.asset(imageUrl, fit: BoxFit.contain, width: 146);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: 188,
        height: 142,
        memCacheWidth: 376,
        memCacheHeight: 284,
        placeholder: (_, _) => const SizedBox(
          width: 188,
          height: 142,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFE9577D),
            ),
          ),
        ),
        errorWidget: (_, _, _) => const SizedBox(
          width: 188,
          height: 142,
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: Color(0xFFC6B2B8)),
          ),
        ),
      ),
    );
  }
}

class _MergePresetRow extends StatelessWidget {
  const _MergePresetRow({required this.presets, required this.onSelected});

  final List<String> presets;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
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
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF2DDE3)),
                      ),
                      child: Text(
                        preset,
                        style: SLTheme.quicksand(
                          color: const Color(0xFF9B3F59),
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
  });

  final TextEditingController controller;
  final bool isUploadingPhoto;
  final VoidCallback onPickImage;
  final VoidCallback onShowSticker;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0DFE4)),
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
              onTap: onPickImage,
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
                textCapitalization: TextCapitalization.sentences,
                style: SLTheme.quicksand(
                  color: const Color(0xFF43363D),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('p4_soul_message_hint'),
                  hintStyle: SLTheme.quicksand(
                    color: const Color(0xFFAA99A0),
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
                onSubmitted: (_) => onSend(),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSend,
                borderRadius: BorderRadius.circular(15),
                child: Ink(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9577D),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
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

  final VoidCallback onTap;
  final IconData? icon;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDF2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child:
                  child ?? Icon(icon, color: const Color(0xFFE9577D), size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
