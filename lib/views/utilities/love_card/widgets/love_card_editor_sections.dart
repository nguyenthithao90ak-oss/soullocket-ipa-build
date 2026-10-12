part of '../../love_card_screen.dart';

class LoveCardStudioComposer extends StatelessWidget {
  final List<LoveCardStudioTheme> themes;
  final LoveCardStudioTheme theme;
  final TextEditingController senderController;
  final TextEditingController signatureController;
  final TextEditingController contentController;
  final String senderFallback;
  final Uint8List? imageBytes;
  final bool isPickingImage;
  final bool isSending;
  final ValueChanged<String> onThemeSelected;
  final VoidCallback onImageSelected;
  final VoidCallback onImageRemoved;
  final VoidCallback onSend;
  final VoidCallback onPreview;

  const LoveCardStudioComposer({
    super.key,
    required this.themes,
    required this.theme,
    required this.senderController,
    required this.signatureController,
    required this.contentController,
    required this.senderFallback,
    this.imageBytes,
    this.isPickingImage = false,
    this.isSending = false,
    required this.onThemeSelected,
    required this.onImageSelected,
    required this.onImageRemoved,
    required this.onSend,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const PageStorageKey('love_card_editor_scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('love_card_theme_section'),
                        style: SLTheme.quicksand(
                          color: palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _LoveCardThemeRail(
                        key: const ValueKey('love_card_theme_rail'),
                        themes: themes,
                        selectedKey: theme.key,
                        onSelected: isSending ? null : onThemeSelected,
                      ),
                      const SizedBox(height: 18),
                      LoveCardDraftPreview(
                        theme: theme,
                        senderController: senderController,
                        signatureController: signatureController,
                        contentController: contentController,
                        senderFallback: senderFallback,
                        imageBytes: imageBytes,
                        onPreview: onPreview,
                      ),
                      const SizedBox(height: 18),
                      _LoveCardWritingDesk(
                        theme: theme,
                        senderController: senderController,
                        signatureController: signatureController,
                        contentController: contentController,
                        senderFallback: senderFallback,
                        readOnly: isSending,
                      ),
                      const SizedBox(height: 12),
                      _LoveCardAttachment(
                        imageBytes: imageBytes,
                        isPicking: isPickingImage,
                        enabled: !isSending && !isPickingImage,
                        onPick: onImageSelected,
                        onRemove: onImageRemoved,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _LoveCardSendBar(
          contentController: contentController,
          isSending: isSending,
          isPicking: isPickingImage,
          onSend: onSend,
        ),
      ],
    );
  }
}

class _LoveCardThemeRail extends StatelessWidget {
  final List<LoveCardStudioTheme> themes;
  final String selectedKey;
  final ValueChanged<String>? onSelected;

  const _LoveCardThemeRail({
    super.key,
    required this.themes,
    required this.selectedKey,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return SingleChildScrollView(
      key: const PageStorageKey('love_card_theme_scroll'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final theme in themes)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Semantics(
                selected: selectedKey == theme.key,
                button: true,
                child: Material(
                  color: selectedKey == theme.key
                      ? palette.accent
                      : palette.paper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selectedKey == theme.key
                          ? palette.accent
                          : palette.line,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('love_card_theme_${theme.key}'),
                    onTap: onSelected == null
                        ? null
                        : () => onSelected!(theme.key),
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              theme.icon,
                              size: 19,
                              color: selectedKey == theme.key
                                  ? palette.onAccent
                                  : palette.accent,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              theme.chip,
                              style: SLTheme.quicksand(
                                color: selectedKey == theme.key
                                    ? palette.onAccent
                                    : palette.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            // Mẫu thuộc bộ PRO luôn có nhãn để người dùng nhận ra.
                            if (ProFeatureLimits.proLoveCardThemes.contains(
                              theme.key,
                            )) ...[
                              const SizedBox(width: 6),
                              const UtilityVipBadge(compact: true),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LoveCardDraftPreview extends StatelessWidget {
  final LoveCardStudioTheme theme;
  final TextEditingController senderController;
  final TextEditingController signatureController;
  final TextEditingController contentController;
  final String senderFallback;
  final Uint8List? imageBytes;
  final bool expanded;
  final VoidCallback? onPreview;

  const LoveCardDraftPreview({
    super.key,
    required this.theme,
    required this.senderController,
    required this.signatureController,
    required this.contentController,
    required this.senderFallback,
    this.imageBytes,
    this.expanded = false,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        senderController,
        signatureController,
        contentController,
      ]),
      builder: (context, _) {
        final sender = senderController.text.trim();
        final signature = signatureController.text.trim();
        final content = contentController.text.trim();
        final accent = Color.alphaBlend(
          const Color(0x6639313D),
          Color(theme.colors.first),
        );
        return RepaintBoundary(
          child: Container(
            key: const ValueKey('love_card_draft_paper'),
            width: double.infinity,
            padding: EdgeInsets.all(expanded ? 24 : 18),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Color(theme.colors.last).withValues(alpha: 0.12),
                const Color(0xFFFFFCF8),
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Color(theme.colors.first).withValues(alpha: 0.30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('love_card_preview_section'),
                            style: SLTheme.quicksand(
                              color: const Color(0xFF8B7681),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            theme.title,
                            style: SLTheme.quicksand(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _LoveCardStamp(theme: theme),
                  ],
                ),
                const SizedBox(height: 13),
                if (imageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: expanded ? 4 / 3 : 2.4,
                      child: Image.memory(
                        imageBytes!,
                        fit: BoxFit.cover,
                        cacheWidth: expanded ? 1080 : 720,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.broken_image_outlined, color: accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                SizedBox(
                  height: expanded
                      ? null
                      : (MediaQuery.textScalerOf(context).scale(24) * 1.28)
                                .ceilToDouble() *
                            3,
                  child: Text(
                    content.isEmpty
                        ? context.tr('util_vitvicuchn_98d4af')
                        : content,
                    key: const ValueKey('love_card_draft_message'),
                    maxLines: expanded ? null : 3,
                    overflow: expanded ? null : TextOverflow.ellipsis,
                    style: GoogleFonts.dancingScript(
                      color: const Color(0xFF483947),
                      fontSize: expanded ? 30 : 24,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: accent.withValues(alpha: 0.18)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.favorite_outline_rounded,
                      color: accent,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sender.isEmpty ? senderFallback : sender,
                            maxLines: expanded ? null : 1,
                            overflow: expanded ? null : TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF483947),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            signature.isEmpty ? theme.signature : signature,
                            maxLines: expanded ? null : 1,
                            overflow: expanded ? null : TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF8B7681),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!expanded && onPreview != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: IconButton(
                          key: const ValueKey('love_card_preview_open'),
                          tooltip: context.tr('love_card_preview_hint'),
                          onPressed: onPreview,
                          color: accent,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(
                            Icons.open_in_full_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoveCardStamp extends StatelessWidget {
  final LoveCardStudioTheme theme;
  const _LoveCardStamp({required this.theme});

  @override
  Widget build(BuildContext context) {
    final color = Color(theme.colors.first);
    return SizedBox(
      width: 46,
      height: 54,
      child: CustomPaint(
        painter: _LoveCardStampPainter(color),
        child: Center(
          child: Icon(
            theme.icon,
            color: Color.alphaBlend(const Color(0x5539313D), color),
            size: 23,
          ),
        ),
      ),
    );
  }
}

class _LoveCardStampPainter extends CustomPainter {
  final Color color;
  const _LoveCardStampPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withValues(alpha: 0.12);
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(frame, fill);
    canvas.drawRRect(frame, stroke);
    final holes = Paint()..color = const Color(0xFFFFFCF8);
    for (var offset = 10.0; offset < size.height - 6; offset += 8) {
      canvas.drawCircle(Offset(3, offset), 2, holes);
      canvas.drawCircle(Offset(size.width - 3, offset), 2, holes);
    }
    for (var offset = 10.0; offset < size.width - 6; offset += 8) {
      canvas.drawCircle(Offset(offset, 3), 2, holes);
      canvas.drawCircle(Offset(offset, size.height - 3), 2, holes);
    }
  }

  @override
  bool shouldRepaint(covariant _LoveCardStampPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LoveCardWritingDesk extends StatelessWidget {
  final LoveCardStudioTheme theme;
  final TextEditingController senderController;
  final TextEditingController signatureController;
  final TextEditingController contentController;
  final String senderFallback;
  final bool readOnly;

  const _LoveCardWritingDesk({
    required this.theme,
    required this.senderController,
    required this.signatureController,
    required this.contentController,
    required this.senderFallback,
    required this.readOnly,
  });

  Future<void> _showSuggestions(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _LoveCardPalette.of(context).paper,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('p6_suggestions_for_you'),
                  style: SLTheme.quicksand(
                    color: _LoveCardPalette.of(context).ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                for (final suggestion in theme.suggestions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 12,
                    leading: Icon(
                      Icons.auto_awesome_outlined,
                      color: _LoveCardPalette.of(context).accent,
                      size: 20,
                    ),
                    title: Text(
                      suggestion,
                      style: SLTheme.quicksand(
                        color: _LoveCardPalette.of(context).ink,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(suggestion),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!context.mounted || selected == null || readOnly) return;
    contentController.value = TextEditingValue(
      text: selected,
      selection: TextSelection.collapsed(offset: selected.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return Material(
      color: palette.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.draw_outlined, color: palette.accent, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.tr('love_card_compose_title'),
                    style: SLTheme.quicksand(
                      color: palette.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('love_card_message_field'),
              controller: contentController,
              readOnly: readOnly,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              cursorColor: palette.accent,
              style: SLTheme.quicksand(
                color: palette.ink,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.tr('util_vitiubnmun_f241e9'),
                hintStyle: SLTheme.quicksand(
                  color: palette.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            Row(
              children: [
                if (theme.suggestions.isNotEmpty)
                  Flexible(
                    child: TextButton.icon(
                      onPressed: readOnly
                          ? null
                          : () => _showSuggestions(context),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.accent,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsetsDirectional.only(end: 10),
                      ),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                      label: Text(
                        context.tr('p6_suggestions_for_you'),
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: contentController,
                  builder: (context, value, _) => Text(
                    '${value.text.characters.length}/500',
                    style: SLTheme.quicksand(
                      color: palette.muted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 1, color: palette.line),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const PageStorageKey('love_card_signature_details'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                iconColor: palette.accent,
                collapsedIconColor: palette.muted,
                minTileHeight: 48,
                maintainState: true,
                title: Text(
                  context.tr('util_dngkghich_b5c3f9'),
                  style: SLTheme.quicksand(
                    color: palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  _LoveCardMetaField(
                    controller: senderController,
                    label: context.tr('util_tnhinth_6cccad'),
                    hint: senderFallback,
                    maxLength: 30,
                    readOnly: readOnly,
                  ),
                  const SizedBox(height: 12),
                  _LoveCardMetaField(
                    controller: signatureController,
                    label: context.tr('util_dngkghich_b5c3f9'),
                    hint: theme.signature,
                    maxLength: 100,
                    readOnly: readOnly,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoveCardMetaField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLength;
  final bool readOnly;

  const _LoveCardMetaField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLength,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLength: maxLength,
      minLines: 1,
      maxLines: 2,
      cursorColor: palette.accent,
      style: SLTheme.quicksand(color: palette.ink, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: false,
        labelStyle: SLTheme.quicksand(color: palette.muted, fontSize: 12),
        hintStyle: SLTheme.quicksand(color: palette.muted, fontSize: 14),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}

class _LoveCardAttachment extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool isPicking;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _LoveCardAttachment({
    this.imageBytes,
    required this.isPicking,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return Material(
      color: palette.soft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('love_card_attachment'),
        onTap: imageBytes == null && enabled ? onPick : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
          child: Row(
            children: [
              if (imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.memory(
                    imageBytes!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    cacheWidth: 144,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.broken_image_outlined,
                      color: palette.accent,
                    ),
                  ),
                )
              else if (isPicking)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: palette.accent,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: palette.accent,
                  size: 24,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  imageBytes != null
                      ? context.tr('util_thipskmnhk_d2a84e')
                      : isPicking
                      ? context.tr('util_angchnnh_aa478d')
                      : context.tr('util_thmnhchoth_4d9184'),
                  style: SLTheme.quicksand(
                    color: palette.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('love_card_attachment_action'),
                tooltip: imageBytes == null
                    ? context.tr('util_thmnhchoth_4d9184')
                    : context.tr('util_xa_4ed187'),
                onPressed: enabled
                    ? imageBytes == null
                          ? onPick
                          : onRemove
                    : null,
                color: palette.accent,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  imageBytes == null ? Icons.add_rounded : Icons.close_rounded,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoveCardSendBar extends StatelessWidget {
  final TextEditingController contentController;
  final bool isSending;
  final bool isPicking;
  final VoidCallback onSend;
  const _LoveCardSendBar({
    required this.contentController,
    required this.isSending,
    required this.isPicking,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 692),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: contentController,
                    builder: (context, value, _) => SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('love_card_create_link'),
                        onPressed:
                            !isSending &&
                                !isPicking &&
                                value.text.trim().isNotEmpty
                            ? onSend
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: palette.onAccent,
                          disabledBackgroundColor: palette.soft,
                          disabledForegroundColor: palette.muted,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: isSending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.accent,
                                ),
                              )
                            : const Icon(Icons.outgoing_mail, size: 20),
                        label: Text(
                          isSending
                              ? context.tr('util_angtothip_573c10')
                              : context.tr('util_githipvtol_f437a3'),
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.tr('love_card_send_hint'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: palette.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
