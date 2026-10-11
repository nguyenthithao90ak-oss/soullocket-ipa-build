part of '../../love_card_screen.dart';

class _LoveCardHistoryView extends StatelessWidget {
  final _LoveCardScreenState state;
  const _LoveCardHistoryView({required this.state});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AsyncSnapshot<List<Map<dynamic, dynamic>>>>(
      valueListenable: state._cardsSnapshot,
      builder: (context, snapshot, _) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _LoveCardPalette.of(context).accent,
              strokeWidth: 2,
            ),
          );
        }
        final cards = snapshot.data ?? const <Map<dynamic, dynamic>>[];
        final now = DateTime.now().millisecondsSinceEpoch;
        final expiring = cards.where((card) {
          final expiresAt = _timestampFromValue(card['expiresAt']);
          final remaining = expiresAt - now;
          return expiresAt > 0 &&
              remaining > 0 &&
              remaining <= const Duration(days: 7).inMilliseconds;
        }).length;

        return ListView.separated(
          key: const PageStorageKey('love_card_history_scroll'),
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          itemCount:
              1 + (snapshot.hasError || cards.isEmpty ? 1 : cards.length),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return LoveCardStudioHistorySummary(
                total: cards.length,
                expiring: expiring,
              );
            }
            if (snapshot.hasError) {
              return _LoveCardHistoryPlaceholder(
                isError: true,
                onRetry: state._bindCards,
              );
            }
            if (cards.isEmpty) {
              return _LoveCardHistoryPlaceholder(
                isError: false,
                onCreate: state._showCreateTab,
              );
            }
            return _LoveCardHistoryItem(state: state, card: cards[index - 1]);
          },
        );
      },
    );
  }
}

class LoveCardStudioHistorySummary extends StatelessWidget {
  final int total;
  final int expiring;
  const LoveCardStudioHistorySummary({
    super.key,
    required this.total,
    required this.expiring,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('util_kholinkthi_b841c6'),
          style: SLTheme.quicksand(
            color: palette.ink,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.tr('util_chhincclin_49d684'),
          style: SLTheme.quicksand(
            color: palette.muted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LoveCardTag(
              label: '$total · ${context.tr('util_linkto_430227')}',
              icon: Icons.link_rounded,
            ),
            if (expiring > 0)
              _LoveCardTag(
                label: '$expiring · ${context.tr('util_sphthn_bb4223')}',
                icon: Icons.schedule_rounded,
              ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _LoveCardHistoryPlaceholder extends StatelessWidget {
  final bool isError;
  final VoidCallback? onCreate;
  final VoidCallback? onRetry;
  const _LoveCardHistoryPlaceholder({
    required this.isError,
    this.onCreate,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 42),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isError
                  ? Icons.cloud_off_outlined
                  : Icons.mark_email_unread_outlined,
              color: palette.accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr(
              isError ? 'util_chaticlchs_2c4d6b' : 'util_chacthipno_e7e271',
            ),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: palette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              isError ? 'util_dliuthipan_d76963' : 'util_hytotmthip_4c0a66',
            ),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: palette.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: isError ? onRetry : onCreate,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.accent,
              side: BorderSide(color: palette.line),
              minimumSize: const Size(48, 48),
            ),
            icon: Icon(
              isError ? Icons.refresh_rounded : Icons.edit_note_rounded,
              size: 20,
            ),
            label: Text(
              context.tr(isError ? 'core_retry' : 'util_tothip_b2b416'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardHistoryItem extends StatelessWidget {
  final _LoveCardScreenState state;
  final Map<dynamic, dynamic> card;
  const _LoveCardHistoryItem({required this.state, required this.card});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SLAlertDialog(
        title: Text(context.tr('util_xalinktthi_8b9f9b')),
        content: Text(context.tr('util_linktnysbg_b62df1')),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('util_hy_1e4050')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('util_xa_4ed187')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await state._deleteLoveCardLink(card);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = _timestampFromValue(card['expiresAt']);
    final expiry = expiresAt > 0
        ? _formatTime(expiresAt)
        : context.tr('util_khngchn_a4f770');
    return LoveCardStudioHistoryTile(
      theme: state._themeOf((card['theme'] ?? 'love').toString()),
      content: (card['content'] ?? '').toString(),
      senderName: (card['senderName'] ?? '').toString(),
      createdLabel: _formatTime(_timestampOf(card)),
      expiryLabel: L10nService().format('love_card_expires_at', {
        'time': expiry,
      }),
      hasImage: (card['imageUrl'] ?? '').toString().trim().isNotEmpty,
      onShare: () async {
        final link = await state._buildPublicLinkForCard(card);
        await state._shareLoveCardLink(
          link: link,
          content: (card['content'] ?? '').toString(),
        );
      },
      onDelete: () => _confirmDelete(context),
    );
  }
}

class LoveCardStudioHistoryTile extends StatelessWidget {
  final LoveCardStudioTheme theme;
  final String content;
  final String senderName;
  final String createdLabel;
  final String expiryLabel;
  final bool hasImage;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const LoveCardStudioHistoryTile({
    super.key,
    required this.theme,
    required this.content,
    required this.senderName,
    required this.createdLabel,
    required this.expiryLabel,
    this.hasImage = false,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _LoveCardPalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Material(
          color: palette.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.line),
          ),
          child: InkWell(
            onTap: onShare,
            onLongPress: onDelete,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 46,
                        decoration: BoxDecoration(
                          color: palette.soft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          theme.icon,
                          color: palette.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              theme.chip,
                              style: SLTheme.quicksand(
                                color: palette.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (senderName.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                senderName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  color: palette.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('love_card_history_delete'),
                        tooltip: context.tr('util_xa_4ed187'),
                        onPressed: onDelete,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: palette.muted,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Text(
                    content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      color: palette.ink,
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LoveCardTag(
                        label: context.tr('util_anghotng_cfaecd'),
                        icon: Icons.link_rounded,
                      ),
                      if (hasImage)
                        _LoveCardTag(
                          label: context.tr('util_cnhcngkhai_091717'),
                          icon: Icons.image_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Divider(height: 1, color: palette.line),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: palette.muted,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              createdLabel,
                              style: SLTheme.quicksand(
                                color: palette.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              expiryLabel,
                              style: SLTheme.quicksand(
                                color: palette.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      key: const ValueKey('love_card_history_share'),
                      onPressed: onShare,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.accent,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(
                        context.tr('share'),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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
