part of '../../love_card_screen.dart';

class _LoveCardPalette {
  final bool dark;
  const _LoveCardPalette(this.dark);
  factory _LoveCardPalette.of(BuildContext context) =>
      _LoveCardPalette(Theme.of(context).brightness == Brightness.dark);
  Color get background =>
      dark ? const Color(0xFF211E29) : const Color(0xFFF7F3ED);
  Color get paper => dark ? const Color(0xFF2D2937) : const Color(0xFFFFFCF8);
  Color get soft => dark ? const Color(0xFF39323F) : const Color(0xFFF0E8E2);
  Color get line => dark ? const Color(0xFF494151) : const Color(0xFFE5DCD4);
  Color get ink => dark ? const Color(0xFFF6EEE7) : const Color(0xFF39313D);
  Color get muted => dark ? const Color(0xFFBEB1C2) : const Color(0xFF817481);
  Color get accent => dark ? const Color(0xFFE5B0C4) : const Color(0xFF83526A);
  Color get onAccent => dark ? const Color(0xFF34232F) : Colors.white;
}

class _LoveCardScreenBody extends StatelessWidget {
  final _LoveCardScreenState state;
  const _LoveCardScreenBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = state._themeOf(state._selectedTheme);
    return ValueListenableBuilder<AsyncSnapshot<List<Map<dynamic, dynamic>>>>(
      valueListenable: state._cardsSnapshot,
      child: LoveCardStudioComposer(
        themes: state._themes.values.toList(growable: false),
        theme: theme,
        senderController: state._senderNameCtrl,
        signatureController: state._signatureCtrl,
        contentController: state._contentCtrl,
        senderFallback: state._defaultSenderName(),
        imageBytes: state._selectedImageBytes,
        isPickingImage: state._isPickingImage,
        isSending: state._isSending,
        onThemeSelected: state._selectTheme,
        onImageSelected: state._pickCardImage,
        onImageRemoved: state._clearSelectedImage,
        onSend: state._sendCard,
        onPreview: () => state._showFullScreenPreview(context, theme),
      ),
      builder: (context, snapshot, editor) => LoveCardStudioShell(
        isEmbedded: state.widget.isEmbedded,
        currentIndex: state._currentIndex,
        unreadCount: state._unreadCount(snapshot.data ?? const []),
        onCreate: state._showCreateTab,
        onHistory: state._showHistoryTab,
        onInfo: () => showDialog<void>(
          context: context,
          builder: (_) => const _LoveCardInfoDialog(),
        ),
        editor: editor!,
        history: _LoveCardHistoryView(state: state),
      ),
    );
  }
}

class LoveCardStudioShell extends StatefulWidget {
  final bool isEmbedded;
  final int currentIndex;
  final int unreadCount;
  final VoidCallback onCreate;
  final VoidCallback onHistory;
  final VoidCallback onInfo;
  final Widget editor;
  final Widget history;

  const LoveCardStudioShell({
    super.key,
    this.isEmbedded = false,
    required this.currentIndex,
    this.unreadCount = 0,
    required this.onCreate,
    required this.onHistory,
    required this.onInfo,
    required this.editor,
    required this.history,
  });

  @override
  State<LoveCardStudioShell> createState() => _LoveCardStudioShellState();
}

class _LoveCardStudioShellState extends State<LoveCardStudioShell> {
  late bool _historyVisited = widget.currentIndex == 1;

  @override
  void didUpdateWidget(covariant LoveCardStudioShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex == 1) _historyVisited = true;
  }

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!widget.isEmbedded)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                      color: palette.ink,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('love_card_studio_title'),
                            style: SLTheme.quicksand(
                              color: palette.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              context.tr('love_card_studio_subtitle'),
                              style: SLTheme.quicksand(
                                color: palette.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('love_card_info_title'),
                      onPressed: widget.onInfo,
                      color: palette.muted,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.info_outline_rounded, size: 21),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                widget.isEmbedded ? 12 : 10,
                16,
                10,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _LoveCardStudioTab(
                          label: context.tr('util_tothip_b2b416'),
                          icon: Icons.edit_note_rounded,
                          selected: widget.currentIndex == 0,
                          onTap: widget.onCreate,
                        ),
                      ),
                      Expanded(
                        child: _LoveCardStudioTab(
                          label: context.tr('util_lchs_3061f5'),
                          icon: Icons.mail_outline_rounded,
                          selected: widget.currentIndex == 1,
                          count: widget.unreadCount,
                          onTap: widget.onHistory,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: widget.currentIndex,
                children: [
                  TickerMode(
                    enabled: widget.currentIndex == 0,
                    child: RepaintBoundary(child: widget.editor),
                  ),
                  if (_historyVisited)
                    TickerMode(
                      enabled: widget.currentIndex == 1,
                      child: RepaintBoundary(child: widget.history),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoveCardStudioTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  const _LoveCardStudioTab({
    required this.label,
    required this.icon,
    required this.selected,
    this.count = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? palette.paper : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? palette.accent : palette.muted,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: selected ? palette.ink : palette.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    _LoveCardTag(label: '$count'),
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

class _LoveCardTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _LoveCardTag({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: palette.accent, size: 14),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: SLTheme.quicksand(
                color: palette.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardInfoDialog extends StatelessWidget {
  const _LoveCardInfoDialog();

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return SLAlertDialog(
      title: Text(context.tr('love_card_info_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in [
            (Icons.palette_outlined, 'love_card_info_create'),
            (Icons.link_rounded, 'love_card_info_share'),
            (Icons.schedule_rounded, 'love_card_info_private'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$1, color: palette.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('${item.$2}_title'),
                          style: SLTheme.quicksand(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('${item.$2}_body'),
                          style: SLTheme.quicksand(fontSize: 13, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        SLDialogAction(
          primary: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('love_card_info_done')),
        ),
      ],
    );
  }
}
