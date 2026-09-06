part of '../../love_card_screen.dart';

final Expando<({String houseId, Stream<List<Map<dynamic, dynamic>>> stream})>
_loveCardCardsStreamCache =
    Expando<({String houseId, Stream<List<Map<dynamic, dynamic>>> stream})>(
      'love_card_cards_stream',
    );

extension _LoveCardSharedCardsStream on _LoveCardScreenState {
  Stream<List<Map<dynamic, dynamic>>> get _cardsStream {
    final normalizedHouseId = widget.houseId.trim();
    final cached = _loveCardCardsStreamCache[this];
    if (cached != null && cached.houseId == normalizedHouseId) {
      return cached.stream;
    }

    final stream = _svc.listenToCards(normalizedHouseId).asBroadcastStream();
    _loveCardCardsStreamCache[this] = (
      houseId: normalizedHouseId,
      stream: stream,
    );
    return stream;
  }
}

class _LoveCardScreenBody extends StatelessWidget {
  final _LoveCardScreenState state;

  const _LoveCardScreenBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = state._themeOf(state._selectedTheme);
    final colors = state._themeColors(theme.key);

    return Scaffold(
      backgroundColor: state.widget.isEmbedded
          ? Colors.transparent
          : const Color(0xFF172036),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF172036), Color(0xFF27304D), Color(0xFF382C4C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -84,
              right: -58,
              child: _LoveCardThemeOrb(
                size: 230,
                color: colors.first.withValues(alpha: 0.24),
              ),
            ),
            Positioned(
              left: -72,
              bottom: -92,
              child: _LoveCardThemeOrb(
                size: 250,
                color: colors.last.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              top: 148,
              left: 22,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 24,
                color: colors.last.withValues(alpha: 0.20),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 132,
              child: Icon(
                theme.accentIcon,
                size: 42,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  if (!state.widget.isEmbedded)
                    _LoveCardHeaderSection(
                      state: state,
                      theme: theme,
                      colors: colors,
                    ),
                  _LoveCardTabSwitcher(state: state, theme: theme),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: state._handleScrollNotification,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey(state._currentIndex),
                          child: state._currentIndex == 0
                              ? _LoveCardCreateView(state: state)
                              : _LoveCardHistoryView(state: state),
                        ),
                      ),
                    ),
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

class _LoveCardHeaderSection extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardHeaderSection({
    required this.state,
    required this.theme,
    required this.colors,
  });

  Future<void> _showInfoDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.first.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.mark_email_read_rounded, color: colors.first),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('love_card_info_title'),
                style: SLTheme.quicksand(
                  color: const Color(0xFF26324A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LoveCardInfoRow(
              icon: Icons.palette_outlined,
              title: context.tr('love_card_info_create_title'),
              body: context.tr('love_card_info_create_body'),
            ),
            const SizedBox(height: 14),
            _LoveCardInfoRow(
              icon: Icons.link_rounded,
              title: context.tr('love_card_info_share_title'),
              body: context.tr('love_card_info_share_body'),
            ),
            const SizedBox(height: 14),
            _LoveCardInfoRow(
              icon: Icons.lock_clock_outlined,
              title: context.tr('love_card_info_private_title'),
              body: context.tr('love_card_info_private_body'),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF26324A),
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('love_card_info_done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          _LoveCardRoundButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 11),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.last.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(theme.icon, color: const Color(0xFF26324A), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('love_card_studio_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('love_card_studio_subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _LoveCardRoundButton(
            icon: Icons.info_outline_rounded,
            onTap: () => _showInfoDialog(context),
          ),
        ],
      ),
    );
  }
}

class _LoveCardInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _LoveCardInfoRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: const Color(0xFF675A89)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  color: const Color(0xFF26324A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: SLTheme.quicksand(
                  color: const Color(0xFF687086),
                  fontSize: 12.5,
                  height: 1.42,
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

class _LoveCardTabSwitcher extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;

  const _LoveCardTabSwitcher({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    final accent = Color(theme.colors.first);
    return Container(
      margin: EdgeInsets.fromLTRB(14, state.widget.isEmbedded ? 10 : 2, 14, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LoveCardTabButton(
              icon: Icons.edit_note_rounded,
              label: context.tr('util_tothip_b2b416'),
              isActive: state._currentIndex == 0,
              accent: accent,
              onTap: state._showCreateTab,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<dynamic, dynamic>>>(
              stream: state._cardsStream,
              initialData: const <Map<dynamic, dynamic>>[],
              builder: (context, snapshot) {
                final unread = snapshot.hasData
                    ? state._unreadCount(snapshot.data!)
                    : 0;
                return _LoveCardTabButton(
                  icon: Icons.auto_stories_rounded,
                  label: context.tr('util_lchs_3061f5'),
                  isActive: state._currentIndex == 1,
                  accent: accent,
                  unreadCount: unread,
                  onTap: state._showHistoryTab,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;
  final int unreadCount;

  const _LoveCardTabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.accent,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFFBF4) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isActive ? accent : Colors.white.withValues(alpha: 0.64),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: isActive
                        ? const Color(0xFF26324A)
                        : Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoveCardThemeOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _LoveCardThemeOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _LoveCardRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _LoveCardRoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

class _LoveCardGlassIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _LoveCardGlassIcon({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }
}

class _LoveCardStatusPill extends StatelessWidget {
  final String label;
  final Color background;

  const _LoveCardStatusPill({required this.label, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LoveCardHistoryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _LoveCardHistoryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
