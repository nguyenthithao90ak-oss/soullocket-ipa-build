part of '../../love_card_screen.dart';

extension on _LoveCardScreenState {
  // ignore: unused_element
  Future<void> _openCardOverlay(Map<dynamic, dynamic> card) async {
    final cardId = (card['id'] ?? '').toString().trim();
    final isMine = card['fromUid'] == widget.myUid;
    final isUnread = !isMine && card['isOpened'] == false && cardId.isNotEmpty;

    if (isUnread) {
      _svc.markOpened(widget.houseId, cardId);
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoveCardPublicViewerScreen(
          payload: _payloadFromCard(card),
        ),
      ),
    );
  }
}
