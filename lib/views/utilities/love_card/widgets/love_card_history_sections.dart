part of '../../love_card_screen.dart';

class _LoveCardHistoryView extends StatelessWidget {
  final _LoveCardScreenState state;

  const _LoveCardHistoryView({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<dynamic, dynamic>>>(
      stream: state._cardsStream,
      initialData: const <Map<dynamic, dynamic>>[],
      builder: (context, snapshot) {
        final cards = snapshot.data ?? const <Map<dynamic, dynamic>>[];

        if (snapshot.hasError) {
          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              _LoveCardHistoryHero(
                state: state,
                cards: cards,
              ),
              const SizedBox(height: 18),
              const _LoveCardHistoryErrorState(),
            ],
          );
        }

        if (cards.isEmpty) {
          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              _LoveCardHistoryHero(
                state: state,
                cards: cards,
              ),
              const SizedBox(height: 18),
              const _LoveCardHistoryEmptyState(),
            ],
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          itemCount: cards.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _LoveCardHistoryHero(
                state: state,
                cards: cards,
              );
            }

            return _LoveCardHistoryItem(
              state: state,
              card: cards[index - 1],
            );
          },
        );
      },
    );
  }
}

class _LoveCardHistoryErrorState extends StatelessWidget {
  const _LoveCardHistoryErrorState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          const _LoveCardGlassIcon(
            icon: Icons.history_toggle_off_rounded,
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('util_chaticlchs_2c4d6b'),
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('util_dliuthipan_d76963'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardHistoryHero extends StatelessWidget {
  final _LoveCardScreenState state;
  final List<Map<dynamic, dynamic>> cards;

  const _LoveCardHistoryHero({
    required this.state,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final mine =
        cards.where((card) => card['fromUid'] == state.widget.myUid).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LoveCardGlassIcon(
                icon: Icons.auto_stories_rounded,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('util_kholinkthi_b841c6'),
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('util_chhincclin_49d684'),
                      style: SLTheme.quicksand(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LoveCardHistoryMetric(
                  label: context.tr('util_linkto_430227'),
                  value: '${cards.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LoveCardHistoryMetric(
                  label: context.tr('util_sphthn_bb4223'),
                  value: '${cards.where((card) {
                    final expiresAt = _timestampFromValue(card['expiresAt']);
                    if (expiresAt <= 0) {
                      return false;
                    }
                    final remaining =
                        expiresAt - DateTime.now().millisecondsSinceEpoch;
                    return remaining > 0 &&
                        remaining <= const Duration(days: 7).inMilliseconds;
                  }).length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LoveCardHistoryMetric(
                  label: context.tr('util_bnto_0ed670'),
                  value: '$mine',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoveCardHistoryEmptyState extends StatelessWidget {
  const _LoveCardHistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          const _LoveCardGlassIcon(
            icon: Icons.mail_outline_rounded,
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('util_chacthipno_e7e271'),
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('util_hytotmthip_4c0a66'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
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

  const _LoveCardHistoryItem({
    required this.state,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = card['fromUid'] == state.widget.myUid;
    final isUnread = !isMine && card['isOpened'] == false;
    final theme = state._themeOf((card['theme'] ?? 'love').toString());
    final colors = state._themeColors(theme.key);
    final timeStr = _formatTime(_timestampOf(card));
    final hasImage = (card['imageUrl'] ?? '').toString().trim().isNotEmpty;
    final expiresAt = _timestampFromValue(card['expiresAt']);
    final expiryText = expiresAt > 0 ? _formatTime(expiresAt) : context.tr('util_khngchn_a4f770');
    final previewText = context.tr('util_linktthipt_730c23');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final link = await state._buildPublicLinkForCard(card);
          await state._shareLoveCardLink(
            link: link,
            content: (card['content'] ?? '').toString(),
          );
        },
        onLongPress: () async {
          final bool? shouldDelete = await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: Text(context.tr('util_xalinktthi_8b9f9b')),
                content: Text(
                  context.tr('util_linktnysbg_b62df1'),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(context.tr('util_hy_1e4050')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(context.tr('util_xa_4ed187')),
                  ),
                ],
              );
            },
          );
          if (shouldDelete == true) {
            await state._deleteLoveCardLink(card);
          }
        },
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.first.withValues(alpha: isUnread ? 0.35 : 0.25),
                colors.last.withValues(alpha: isUnread ? 0.25 : 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: isUnread ? 0.9 : 0.65),
              width: isUnread ? 2.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Icon(
                      isMine
                          ? Icons.send_rounded
                          : isUnread
                              ? Icons.mark_email_unread_rounded
                              : Icons.drafts_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theme.chip,
                          style: SLTheme.quicksand(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr('util_linkthipto_ba42f9'),
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _LoveCardStatusPill(
                    label: context.tr('util_anghotng_cfaecd'),
                    background: isUnread
                        ? Colors.redAccent
                        : Colors.white.withValues(alpha: 0.16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                previewText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: isUnread
                    ? GoogleFonts.dancingScript(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      )
                    : SLTheme.quicksand(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: FontWeight.w700,
                      ),
              ),
              if (hasImage) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('util_cnhcngkhai_091717'),
                        style: SLTheme.quicksand(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: Colors.white.withValues(alpha: 0.58),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timeStr,
                      style: SLTheme.quicksand(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'Hết hạn: $expiryText',
                    style: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
