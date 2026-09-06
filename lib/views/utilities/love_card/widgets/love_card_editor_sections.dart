part of '../../love_card_screen.dart';

class _LoveCardCreateView extends StatelessWidget {
  final _LoveCardScreenState state;

  const _LoveCardCreateView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = state._themeOf(state._selectedTheme);
    final colors = state._themeColors(theme.key);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 390 ? 14.0 : 18.0;
        return ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            4,
            horizontal,
            bottomInset + 28,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LoveCardCreateHero(theme: theme, colors: colors),
                    const SizedBox(height: 22),
                    _LoveCardSectionLabel(
                      icon: Icons.local_activity_outlined,
                      title: context.tr('love_card_theme_section'),
                      subtitle: context.tr('love_card_theme_section_hint'),
                    ),
                    const SizedBox(height: 11),
                    _LoveCardThemePicker(state: state),
                    const SizedBox(height: 24),
                    _LoveCardSectionLabel(
                      icon: Icons.visibility_outlined,
                      title: context.tr('love_card_preview_section'),
                      subtitle: context.tr('love_card_preview_hint'),
                    ),
                    const SizedBox(height: 11),
                    GestureDetector(
                      onTap: () =>
                          state._showFullScreenPreview(context, theme, colors),
                      child: RepaintBoundary(
                        child: _LoveCardPreviewPanel(
                          state: state,
                          theme: theme,
                          colors: colors,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _LoveCardComposerPanel(
                      state: state,
                      theme: theme,
                      colors: colors,
                    ),
                    const SizedBox(height: 16),
                    _LoveCardSendAction(
                      state: state,
                      theme: theme,
                      colors: colors,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('util_saukhigiap_ef330c'),
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoveCardSectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _LoveCardSectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoveCardCreateHero extends StatelessWidget {
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardCreateHero({required this.theme, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -32,
            right: -18,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                width: 94,
                height: 112,
                decoration: BoxDecoration(
                  color: colors.last.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.first.withValues(alpha: 0.26),
                    width: 2,
                  ),
                ),
                child: Icon(theme.icon, color: colors.first, size: 34),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 76),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF26324A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    color: colors.last,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('love_card_create_hero_title'),
                        style: SLTheme.quicksand(
                          color: const Color(0xFF26324A),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('love_card_create_hero_subtitle'),
                        style: SLTheme.quicksand(
                          color: const Color(0xFF6A7183),
                          fontSize: 11.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _LoveCardThemePicker extends StatelessWidget {
  final _LoveCardScreenState state;

  const _LoveCardThemePicker({required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 330 ? 2 : 4;
        const gap = 8.0;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: state._themes.entries
              .map((entry) {
                final data = entry.value;
                final selected = state._selectedTheme == entry.key;
                final colors = state._themeColors(data.key);
                return SizedBox(
                  width: itemWidth,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => state._selectTheme(entry.key),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 170),
                        height: 94,
                        padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFFFBF4)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? colors.first
                                : Colors.white.withValues(alpha: 0.10),
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: colors.first.withValues(alpha: 0.20),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? colors.last.withValues(alpha: 0.55)
                                        : colors.first.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    data.icon,
                                    color: selected
                                        ? colors.first
                                        : colors.last,
                                    size: 21,
                                  ),
                                ),
                                if (selected)
                                  Positioned(
                                    top: -5,
                                    right: -7,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF26324A),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              data.chip,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                color: selected
                                    ? const Color(0xFF26324A)
                                    : Colors.white.withValues(alpha: 0.84),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _LoveCardPreviewPanel extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;
  final List<Color> colors;
  final bool fullBleed;

  const _LoveCardPreviewPanel({
    required this.state,
    required this.theme,
    required this.colors,
    this.fullBleed = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = state._selectedImageBytes != null;
    final radius = fullBleed ? 30.0 : 26.0;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: fullBleed ? 430 : 310),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.first.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -38,
            right: -34,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.last.withValues(alpha: 0.30),
              ),
            ),
          ),
          Positioned(
            right: 22,
            top: 20,
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                width: 62,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.last.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: colors.first.withValues(alpha: 0.50),
                    width: 1.5,
                  ),
                ),
                child: Icon(theme.icon, color: colors.first, size: 27),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              fullBleed ? 26 : 20,
              fullBleed ? 26 : 20,
              fullBleed ? 26 : 20,
              fullBleed ? 28 : 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 210,
                  child: Row(children: [_LoveCardEffectPill(theme: theme)]),
                ),
                SizedBox(height: hasImage ? 18 : 30),
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.memory(
                        state._selectedImageBytes!,
                        fit: BoxFit.cover,
                        cacheWidth: 900,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  theme.title,
                  style: SLTheme.quicksand(
                    color: const Color(0xFF26324A),
                    fontSize: fullBleed ? 18 : 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state._previewContent(),
                  maxLines: hasImage ? 4 : 7,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dancingScript(
                    color: const Color(0xFF31384D),
                    fontSize: fullBleed ? 34 : 29,
                    height: 1.28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: colors.first.withValues(alpha: 0.18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(theme.accentIcon, color: colors.first, size: 18),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.first.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: colors.first,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state._resolveSenderName(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF26324A),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state._resolveSignature(theme.key),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF7A8090),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardEffectPill extends StatelessWidget {
  final _LoveThemeData theme;

  const _LoveCardEffectPill({required this.theme});

  @override
  Widget build(BuildContext context) {
    final color = Color(theme.colors.first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.accentIcon, color: color, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              theme.effectLabel,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardComposerPanel extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardComposerPanel({
    required this.state,
    required this.theme,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EEE4),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.first.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.draw_rounded, color: colors.first, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('love_card_compose_title'),
                      style: SLTheme.quicksand(
                        color: const Color(0xFF26324A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      theme.subtitle,
                      style: SLTheme.quicksand(
                        color: const Color(0xFF72798A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LoveCardMetaField(
            label: context.tr('util_tnhinth_6cccad'),
            hintText: state._defaultSenderName(),
            controller: state._senderNameCtrl,
            icon: Icons.person_outline_rounded,
            themeColors: colors,
            maxLength: 30,
            onChanged: (_) => state._refreshUi(),
          ),
          const SizedBox(height: 10),
          _LoveCardMetaField(
            label: context.tr('util_dngkghich_b5c3f9'),
            hintText: state._defaultSignatureForTheme(theme.key),
            controller: state._signatureCtrl,
            icon: Icons.auto_awesome_rounded,
            themeColors: colors,
            minLines: 1,
            maxLines: 2,
            maxLength: 100,
            onChanged: (_) => state._refreshUi(),
          ),
          const SizedBox(height: 10),
          _LoveCardContentEditor(
            controller: state._contentCtrl,
            theme: theme,
            colors: colors,
            onChanged: state._refreshUi,
            hintText: context.tr('util_vitiubnmun_f241e9'),
            suggestions: theme.suggestions,
            onSuggestionTap: (text) {
              state._setControllerText(state._contentCtrl, text);
              state._refreshUi();
            },
          ),
          const SizedBox(height: 12),
          _LoveCardImageAttachmentPanel(state: state, theme: theme),
        ],
      ),
    );
  }
}

class _LoveCardMetaField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;
  final List<Color>? themeColors;
  final int? maxLength;

  const _LoveCardMetaField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.icon,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.themeColors,
    this.maxLength,
  });

  @override
  State<_LoveCardMetaField> createState() => _LoveCardMetaFieldState();
}

class _LoveCardMetaFieldState extends State<_LoveCardMetaField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (mounted && _focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.themeColors?.first ?? const Color(0xFF6C7FF2);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _focused
              ? accent.withValues(alpha: 0.62)
              : const Color(0xFFE1D9CD),
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.icon,
                color: _focused ? accent : const Color(0xFF7A8090),
                size: 15,
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: SLTheme.quicksand(
                  color: _focused ? accent : const Color(0xFF7A8090),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            cursorColor: accent,
            onChanged: widget.onChanged,
            style: SLTheme.quicksand(
              color: const Color(0xFF26324A),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hintText,
              hintStyle: SLTheme.quicksand(
                color: const Color(0xFF9A9EAA),
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 7),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardContentEditor extends StatefulWidget {
  final TextEditingController controller;
  final _LoveThemeData theme;
  final List<Color> colors;
  final VoidCallback onChanged;
  final String hintText;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  const _LoveCardContentEditor({
    required this.controller,
    required this.theme,
    required this.colors,
    required this.onChanged,
    required this.hintText,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  State<_LoveCardContentEditor> createState() => _LoveCardContentEditorState();
}

class _LoveCardContentEditorState extends State<_LoveCardContentEditor> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (mounted && _focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.colors.first;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _focused
              ? accent.withValues(alpha: 0.62)
              : const Color(0xFFE1D9CD),
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: accent, size: 15),
              const SizedBox(width: 7),
              Text(
                context.tr('util_vitnidungt_69403f'),
                style: SLTheme.quicksand(
                  color: accent,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.controller.text.characters.length}/500',
                style: SLTheme.quicksand(
                  color: const Color(0xFF9A9EAA),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            minLines: 4,
            maxLines: 7,
            maxLength: 500,
            cursorColor: accent,
            onChanged: (_) => widget.onChanged(),
            style: SLTheme.quicksand(
              color: const Color(0xFF26324A),
              fontSize: 14.5,
              height: 1.48,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: SLTheme.quicksand(
                color: const Color(0xFF9A9EAA),
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          if (widget.suggestions.isNotEmpty) ...[
            Divider(color: accent.withValues(alpha: 0.12), height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: widget.suggestions
                    .map((suggestion) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ActionChip(
                          onPressed: () => widget.onSuggestionTap(suggestion),
                          avatar: Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: accent,
                          ),
                          label: Text(
                            suggestion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          labelStyle: SLTheme.quicksand(
                            color: const Color(0xFF4D556A),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                          backgroundColor: accent.withValues(alpha: 0.08),
                          side: BorderSide(
                            color: accent.withValues(alpha: 0.12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoveCardImageAttachmentPanel extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;

  const _LoveCardImageAttachmentPanel({
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = state._selectedImageBytes != null;
    final accent = Color(theme.colors.first);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasImage ? null : state._pickCardImage,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1D9CD)),
          ),
          child: hasImage
              ? Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.memory(
                        state._selectedImageBytes!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        cacheWidth: 240,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('util_thipskmnhk_d2a84e'),
                            style: SLTheme.quicksand(
                              color: const Color(0xFF26324A),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('util_nginhnsthy_de894b'),
                            style: SLTheme.quicksand(
                              color: const Color(0xFF7A8090),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('util_xa_4ed187'),
                      onPressed: state._clearSelectedImage,
                      icon: Icon(Icons.close_rounded, color: accent),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: state._isPickingImage
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            )
                          : Icon(
                              Icons.add_photo_alternate_outlined,
                              color: accent,
                            ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state._isPickingImage
                                ? context.tr('util_angchnnh_aa478d')
                                : context.tr('util_thmnhchoth_4d9184'),
                            style: SLTheme.quicksand(
                              color: const Color(0xFF26324A),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            L10nService().format('love_card_image_note', {
                              'theme': theme.chip.toLowerCase(),
                            }),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SLTheme.quicksand(
                              color: const Color(0xFF7A8090),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LoveCardSendAction extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardSendAction({
    required this.state,
    required this.theme,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final enabled =
        state._contentCtrl.text.trim().isNotEmpty &&
        !state._isSending &&
        !state._isPickingImage;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.52,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: state._sendCard,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF26324A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.24),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.last,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: state._isSending
                        ? Padding(
                            padding: const EdgeInsets.all(11),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.first,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: const Color(0xFF26324A),
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state._isSending
                              ? context.tr('util_angtothip_573c10')
                              : context.tr('util_githipvtol_f437a3'),
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('love_card_send_hint'),
                          style: SLTheme.quicksand(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    theme.icon,
                    color: colors.last.withValues(alpha: 0.82),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
