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
            'Chưa tải được lịch sử',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dữ liệu thiệp đang lỗi hoặc phản hồi chậm. Kéo xuống để thử lại hoặc gửi một thiệp mới rồi mở lại tab này.',
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
                      'Kho link thiệp đã tạo',
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chỉ hiện các liên kết bạn đã tạo. Link hết hạn hoặc bị gỡ sẽ tự biến mất.',
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
                  label: 'Link đã tạo',
                  value: '${cards.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LoveCardHistoryMetric(
                  label: 'Sắp hết hạn',
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
                  label: 'Bạn tạo',
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
            'Chưa có thiệp nào',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy tạo tấm thiệp đầu tiên. Sau khi gửi, chỉ các link bạn đã tạo sẽ hiện ở đây để chia sẻ lại hoặc gỡ bỏ.',
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
    final expiryText = expiresAt > 0 ? _formatTime(expiresAt) : 'Không có hạn';
    const previewText = 'Liên kết thiệp đã tạo sẵn để bạn gửi lại nhanh.';

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
                title: const Text('Xóa liên kết thiệp?'),
                content: const Text(
                  'Liên kết này sẽ bị gỡ khỏi lịch sử chia sẻ. Bạn vẫn muốn xóa chứ?',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Xóa'),
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
                colors.first.withValues(alpha: isUnread ? 0.42 : 0.30),
                colors.last.withValues(alpha: isUnread ? 0.34 : 0.20),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isUnread
                  ? Colors.white.withValues(alpha: 0.42)
                  : Colors.white.withValues(alpha: 0.16),
              width: isUnread ? 1.4 : 1,
            ),
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
                          'Link thiệp đã tạo',
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
                    label: 'Đang hoạt động',
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
                        'Có ảnh công khai',
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
