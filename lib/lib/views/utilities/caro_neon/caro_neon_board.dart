part of '../caro_neon_screen.dart';

class _ArenaBoardPanel extends StatelessWidget {
  const _ArenaBoardPanel({
    required this.room,
    required this.winLength,
    required this.boardSize,
    required this.myRole,
    required this.isBotMode,
    required this.onTapCell,
    this.myName,
    this.opponentName,
    this.compactMode = false,
    this.onJoin,
    this.onExit,
    this.onReplay,
  });

  final CaroRoom? room;
  final int winLength;
  final int boardSize;
  final String myRole;
  final bool isBotMode;
  final void Function(int row, int col) onTapCell;
  final String? myName;
  final String? opponentName;
  final bool compactMode;
  final VoidCallback? onJoin;
  final VoidCallback? onExit;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final currentRoom = room;
    final isWideBoard = winLength == 5;
    final cellSize = isWideBoard ? 54.0 : 92.0;
    final gap = isWideBoard ? 6.0 : 8.0;
    final boardExtent = (cellSize * boardSize) + (gap * (boardSize - 1));
    final winningCells = currentRoom?.winningCells.toSet() ?? const <String>{};
    final allowTap =
        currentRoom?.isActive == true && currentRoom?.turnRole == myRole;

    final resolvedMyName =
        (myName ?? context.tr('util_bn_1fd75b')).trim().isEmpty ? context.tr('util_bn_1fd75b') : (myName ?? context.tr('util_bn_1fd75b')).trim();
    final resolvedOpponentName = (opponentName ?? context.tr('util_ngiy_5bab37')).trim().isEmpty
        ? context.tr('util_ngiy_5bab37')
        : (opponentName ?? context.tr('util_ngiy_5bab37')).trim();

    String subtitle;
    if (currentRoom == null) {
      subtitle = isBotMode
          ? context.tr('util_btutsnhriq_65fc48')
          : context.tr('util_mbntsnhrit_a75c8b');
    } else if (currentRoom.isWaiting) {
      subtitle = currentRoom.createdByRole == myRole
          ? 'Đang chờ $resolvedOpponentName vào bàn.'
          : '$resolvedOpponentName đã mở sẵn bàn cho bạn.';
    } else if (currentRoom.isActive) {
      subtitle = allowTap
          ? context.tr('util_tiltbnchmt_8fabaf')
          : 'Đang chờ $resolvedOpponentName đi tiếp.';
    } else if (currentRoom.isDraw) {
      subtitle = context.tr('util_vnnyha_f96721');
    } else {
      subtitle = currentRoom.winnerRole == myRole
          ? context.tr('util_bnvathngvn_5a2b5b')
          : '$resolvedOpponentName đã thắng ván này.';
    }

    String? overlayTitle;
    String? overlayCaption;
    IconData overlayIcon = Icons.play_circle_fill_rounded;
    String? primaryActionLabel;
    VoidCallback? primaryAction;
    String? secondaryActionLabel;
    VoidCallback? secondaryAction;
    if (currentRoom == null) {
      overlayTitle = isBotMode ? context.tr('util_chacvnno_79d99b') : context.tr('util_chambn_96d88c');
      overlayCaption = isBotMode
          ? context.tr('util_quaylitabs_53de85')
          : context.tr('util_quaylitabs_725d3f');
      overlayIcon =
          isBotMode ? Icons.smart_toy_rounded : Icons.rocket_launch_rounded;
    } else if (currentRoom.isWaiting) {
      overlayTitle = currentRoom.createdByRole == myRole
          ? 'Đang chờ $resolvedOpponentName'
          : '$resolvedOpponentName mời bạn vào chơi';
      overlayCaption = currentRoom.createdByRole == myRole
          ? 'Không gian riêng đã sẵn sàng. Khi $resolvedOpponentName vào, ván sẽ bắt đầu ngay.'
          : context.tr('util_bnringmxon_50ff73');
      overlayIcon = currentRoom.createdByRole == myRole
          ? Icons.hourglass_top_rounded
          : Icons.login_rounded;
      if (currentRoom.createdByRole != myRole) {
        primaryActionLabel = context.tr('util_vochi_e0d812');
        primaryAction = onJoin;
      }
      secondaryActionLabel = context.tr('util_thot_8df314');
      secondaryAction = onExit;
    } else if (currentRoom.isDone) {
      if (currentRoom.isDraw) {
        overlayTitle = context.tr('util_vnha_b83a70');
        overlayCaption =
            context.tr('util_khngaichin_cf71f0');
        overlayIcon = Icons.handshake_rounded;
      } else if (currentRoom.winnerRole == myRole) {
        overlayTitle = context.tr('util_bnchinthng_5edacf');
        overlayCaption =
            '$resolvedMyName đã hoàn thành hàng ${currentRoom.winLength} ô trước $resolvedOpponentName.';
        overlayIcon = Icons.emoji_events_rounded;
      } else {
        overlayTitle = '$resolvedOpponentName chiến thắng';
        overlayCaption =
            '$resolvedOpponentName đã hoàn thành hàng ${currentRoom.winLength} ô và kết thúc ván này.';
        overlayIcon = Icons.flag_rounded;
      }
      primaryActionLabel = context.tr('util_chitip_027082');
      primaryAction = onReplay;
      secondaryActionLabel = context.tr('util_thot_8df314');
      secondaryAction = onExit;
    }

    final rawBoard = SizedBox(
      width: boardExtent,
      height: boardExtent,
      child: Column(
        children: List.generate(boardSize, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: row == boardSize - 1 ? 0 : gap),
            child: Row(
              children: List.generate(boardSize, (col) {
                final key = '$row:$col';
                final symbol = currentRoom?.cellAt(row, col);
                final canTap = allowTap && symbol == null;
                return Padding(
                  padding:
                      EdgeInsets.only(right: col == boardSize - 1 ? 0 : gap),
                  child: _BoardCell(
                    size: cellSize,
                    symbol: symbol,
                    isWinning: winningCells.contains(key),
                    isEnabled: canTap,
                    onTap: canTap ? () => onTapCell(row, col) : null,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );

    final board = LayoutBuilder(
      builder: (context, constraints) {
        if (!isWideBoard) {
          return Center(child: rawBoard);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: math.max(constraints.maxWidth, boardExtent),
            ),
            child: Center(child: rawBoard),
          ),
        );
      },
    );

    return Container(
      width: double.infinity,
      padding: compactMode
          ? const EdgeInsets.fromLTRB(12, 12, 12, 14)
          : const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE80C0918), Color(0xD0101830), Color(0xE80A0815)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(34),
        ),
        border: Border.all(color: const Color(0x2F7AF6FF)),
      ),
      child: Column(
        children: [
          if (compactMode && currentRoom?.isActive == true) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x14101827),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x225AF1FF)),
              ),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE4DDF2),
                  height: 1.4,
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BÀN ĐẤU ${boardSize}x$boardSize',
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: SLTheme.quicksand(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFC9C2DB),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _TinyPill(
                  text: isWideBoard ? context.tr('util_5thng_5e66bf') : context.tr('util_3thng_080f34'),
                  color: isWideBoard
                      ? const Color(0xFFFFD76F)
                      : const Color(0xFF4EDBFF),
                  darkText: isWideBoard,
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isWideBoard ? 14 : 16),
            decoration: BoxDecoration(
              color: const Color(0x36101920),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x2D78F5FF)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                board,
                if (overlayTitle != null && overlayCaption != null)
                  Positioned.fill(
                    child: _BoardStateCallout(
                      title: overlayTitle,
                      caption: overlayCaption,
                      icon: overlayIcon,
                      accent: currentRoom?.isDone == true
                          ? (currentRoom!.isDraw
                              ? const Color(0xFF9FE2FF)
                              : currentRoom.winnerRole == myRole
                                  ? const Color(0xFFFFD76F)
                                  : const Color(0xFFFF7DA8))
                          : (currentRoom?.createdByRole == myRole
                              ? const Color(0xFF9FE2FF)
                              : const Color(0xFFFF7DA8)),
                      primaryLabel: primaryActionLabel,
                      onPrimaryTap: primaryAction,
                      secondaryLabel: secondaryActionLabel,
                      onSecondaryTap: secondaryAction,
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

class _BoardStateCallout extends StatelessWidget {
  const _BoardStateCallout({
    required this.title,
    required this.caption,
    required this.icon,
    required this.accent,
    this.primaryLabel,
    this.onPrimaryTap,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  final String title;
  final String caption;
  final IconData icon;
  final Color accent;
  final String? primaryLabel;
  final VoidCallback? onPrimaryTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x7D06050E),
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xED151022),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.46)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.55)),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 12.4,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD7D1E7),
                height: 1.45,
              ),
            ),
            if ((primaryLabel != null && onPrimaryTap != null) ||
                (secondaryLabel != null && onSecondaryTap != null)) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (secondaryLabel != null && onSecondaryTap != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSecondaryTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: accent.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          secondaryLabel!,
                          style: SLTheme.quicksand(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (secondaryLabel != null &&
                      onSecondaryTap != null &&
                      primaryLabel != null &&
                      onPrimaryTap != null)
                    const SizedBox(width: 10),
                  if (primaryLabel != null && onPrimaryTap != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onPrimaryTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: const Color(0xFF14051A),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          primaryLabel!,
                          style: SLTheme.quicksand(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _BoardPanel extends StatelessWidget {
  const _BoardPanel({
    required this.room,
    required this.winLength,
    required this.boardSize,
    required this.myRole,
    required this.onTapCell,
  });

  final CaroRoom? room;
  final int winLength;
  final int boardSize;
  final String myRole;
  final void Function(int row, int col) onTapCell;

  @override
  Widget build(BuildContext context) {
    final isWideBoard = winLength == 5;
    final cellSize = isWideBoard ? 54.0 : 92.0;
    final gap = isWideBoard ? 6.0 : 8.0;
    final boardExtent = (cellSize * boardSize) + (gap * (boardSize - 1));
    final winningCells = room?.winningCells.toSet() ?? const <String>{};
    final allowTap = room?.isActive == true && room?.turnRole == myRole;

    Widget board = SizedBox(
      width: boardExtent,
      height: boardExtent,
      child: Column(
        children: List.generate(boardSize, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: row == boardSize - 1 ? 0 : gap),
            child: Row(
              children: List.generate(boardSize, (col) {
                final key = '$row:$col';
                final symbol = room?.cellAt(row, col);
                final canTap = allowTap && symbol == null;
                return Padding(
                  padding:
                      EdgeInsets.only(right: col == boardSize - 1 ? 0 : gap),
                  child: _BoardCell(
                    size: cellSize,
                    symbol: symbol,
                    isWinning: winningCells.contains(key),
                    isEnabled: canTap,
                    onTap: canTap ? () => onTapCell(row, col) : null,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );

    if (isWideBoard) {
      board = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: board,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE80C0918), Color(0xD0101830), Color(0xE80A0815)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(34),
        ),
        border: Border.all(color: const Color(0x2F7AF6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isWideBoard
                      ? context.tr('util_bn10x10thn_b9b2a7')
                      : context.tr('util_bn3x3thngk_37ac70'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              _TinyPill(
                text: isWideBoard ? context.tr('util_kongang_2ac68f') : context.tr('util_chmnh_373341'),
                color: isWideBoard
                    ? const Color(0xFFFFD76F)
                    : const Color(0xFF4EDBFF),
                darkText: isWideBoard,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isWideBoard
                ? context.tr('util_bnrngchovn_233fd9')
                : context.tr('util_bngngingnh_ce6b3c'),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFC9C2DB),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          board,
        ],
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell({
    required this.size,
    required this.symbol,
    required this.isWinning,
    required this.isEnabled,
    required this.onTap,
  });

  final double size;
  final String? symbol;
  final bool isWinning;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isWinning
        ? const Color(0xFFFFD76F)
        : symbol == 'X'
            ? const Color(0xFF4EDBFF)
            : symbol == 'O'
                ? const Color(0xFFFF5E9E)
                : const Color(0x66A7B7DA);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size > 60 ? 24 : 16),
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isWinning
                ? const [Color(0x22FFD76F), Color(0x12FFE0A0)]
                : isEnabled
                    ? const [Color(0x20254B66), Color(0x10142334)]
                    : const [Color(0x180F1323), Color(0x16080B15)],
          ),
          borderRadius: BorderRadius.circular(size > 60 ? 24 : 16),
          border: Border.all(color: borderColor, width: isWinning ? 1.8 : 1.2),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: isWinning ? 0.34 : 0.16),
              blurRadius: isWinning ? 18 : 12,
              spreadRadius: isWinning ? 1 : 0,
            ),
          ],
        ),
        child: symbol == null
            ? Center(
                child: Container(
                  width: size * 0.16,
                  height: size * 0.16,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? const Color(0xFF4EDBFF).withValues(alpha: 0.7)
                        : const Color(0x20FFFFFF),
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : Padding(
                padding: EdgeInsets.all(size * 0.18),
                child: CustomPaint(
                  painter:
                      _NeonMarkPainter(symbol: symbol!, highlight: isWinning),
                ),
              ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.text,
    required this.color,
    this.darkText = false,
  });

  final String text;
  final Color color;
  final bool darkText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: SLTheme.quicksand(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: darkText ? const Color(0xFF3A2500) : Colors.white,
        ),
      ),
    );
  }
}
