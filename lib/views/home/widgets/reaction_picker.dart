import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/services.dart';
import '../../../core/sl_theme.dart';

/// ============================================================
///  ReactionPicker — Emoji Reaction cho Feed Post
///  Gọi bằng: ReactionPicker.show(context, onSelect: (emoji) {...})
/// ============================================================

final _kReactions = [
  ('❤️', L10nService().translate('home_yu_b0b34f')),
  ('😍', L10nService().translate('home_thch_436ce5')),
  ('😂', 'Haha'),
  ('😮', 'Wow'),
  ('😢', L10nService().translate('home_bun_cc7bc1')),
  ('😡', L10nService().translate('home_gin_6a4c8c')),
  ('🔥', 'Hot'),
  ('👏', L10nService().translate('home_vtay_880b85')),
];

class ReactionPicker extends StatelessWidget {
  final void Function(String emoji, String label) onSelect;
  final String? currentReaction;

  const ReactionPicker({
    super.key,
    required this.onSelect,
    this.currentReaction,
  });

  // ── Helper: show as bottom sheet overlay ──────────────────
  static Future<void> show(
    BuildContext context, {
    required void Function(String emoji, String label) onSelect,
    String? currentReaction,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => ReactionPicker(
        onSelect: onSelect,
        currentReaction: currentReaction,
      ),
    );
  }

  // ── Helper: show as popup near a widget ───────────────────
  static Future<void> showPopup(
    BuildContext context,
    Offset position, {
    required void Function(String emoji, String label) onSelect,
    String? currentReaction,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Reaction',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim, _) {
        return _ReactionPopup(
          position: position,
          onSelect: onSelect,
          currentReaction: currentReaction,
          animation: anim,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SLSpacing.h16,
          Text(
            context.tr('home_cmxc_0d1460'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SLSpacing.h16,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _kReactions.map((r) {
              final isActive = currentReaction == r.$1;
              return _ReactionItem(
                emoji: r.$1,
                label: r.$2,
                isSelected: isActive,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  onSelect(r.$1, r.$2);
                },
              );
            }).toList(),
          ),
          SLSpacing.h16,
          // Remove reaction option
          if (currentReaction != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onSelect('', '');
              },
              child: Text(
                context.tr('home_xacmxc_ba960b'),
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

// ─── Single Reaction Item ─────────────────────────────────────
class _ReactionItem extends StatefulWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReactionItem({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ReactionItem> createState() => _ReactionItemState();
}

class _ReactionItemState extends State<_ReactionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      upperBound: 1.0,
      lowerBound: 0.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFE91E8C).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: SLRadius.lgAll,
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFFE91E8C)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 28)),
              SLSpacing.h4,
              Text(
                widget.label,
                style: const TextStyle(color: Colors.white60, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Popup variant (floating near post) ──────────────────────
class _ReactionPopup extends StatelessWidget {
  final Offset position;
  final void Function(String, String) onSelect;
  final String? currentReaction;
  final Animation<double> animation;

  const _ReactionPopup({
    required this.position,
    required this.onSelect,
    required this.currentReaction,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    double left = position.dx - 180;
    if (left < 8) left = 8;
    if (left + 360 > size.width) left = size.width - 368;
    double top = position.dy - 80;
    if (top < 60) top = position.dy + 20;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: SLRadius.pillAll,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _kReactions.map((r) {
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        onSelect(r.$1, r.$2);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(r.$1, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reaction Count Display Widget ───────────────────────────
class ReactionCountBar extends StatelessWidget {
  final Map<String, int> reactions; // {'❤️': 5, '😂': 2}
  final String? myReaction;
  final VoidCallback onTap;

  const ReactionCountBar({
    super.key,
    required this.reactions,
    required this.myReaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty && myReaction == null) {
      return GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border, size: 18, color: Colors.white54),
            SLSpacing.w4,
            Text(context.tr('home_yuthch_2958ea'),
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
    }

    final top = reactions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEmojis = top.take(3).map((e) => e.key).toList();
    final totalCount = reactions.values.fold(0, (a, b) => a + b);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: myReaction != null
              ? const Color(0xFFE91E8C).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: myReaction != null
                ? const Color(0xFFE91E8C).withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...topEmojis
                .map((e) => Text(e, style: const TextStyle(fontSize: 14))),
            if (totalCount > 0) ...[
              SLSpacing.w4,
              Text(
                '$totalCount',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}