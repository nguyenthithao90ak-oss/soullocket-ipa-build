import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';

class VisitorProfileStatsSection extends StatelessWidget {
  final int postCount;
  final int heartCount;
  final bool hideLikeCount;
  final bool isMe;
  final bool isFriend;

  const VisitorProfileStatsSection({
    super.key,
    required this.postCount,
    required this.heartCount,
    required this.hideLikeCount,
    required this.isMe,
    required this.isFriend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 14, 10, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: SLColors.bgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SLColors.border),
        boxShadow: SLShadow.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _VisitorProfileStatItem(
              value: '$postCount',
              label: 'Bài đăng',
            ),
          ),
          const _VisitorProfileStatDivider(),
          Expanded(
            child: _VisitorProfileStatItem(
              value: (hideLikeCount && !isMe) ? '***' : '$heartCount',
              label: 'Lửa ❤️',
            ),
          ),
          const _VisitorProfileStatDivider(),
          Expanded(
            child: _VisitorProfileStatItem(
              value: isFriend ? '✓' : '—',
              label: 'Bạn bè',
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorProfileStatItem extends StatelessWidget {
  final String value;
  final String label;

  const _VisitorProfileStatItem({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: SLColors.primary,
          ),
        ),
        SLSpacing.gapH(2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: SLColors.textSecond,
          ),
        ),
      ],
    );
  }
}

class _VisitorProfileStatDivider extends StatelessWidget {
  const _VisitorProfileStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: SLColors.border);
  }
}
