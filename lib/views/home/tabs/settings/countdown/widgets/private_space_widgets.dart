import 'package:flutter/material.dart';

import '../../../../../../core/sl_theme.dart';
import '../../../../../../utils/services/l10n_service.dart';
import '../../theme/appearance_panel_widgets.dart';

/// Thẻ co theo nội dung thay vì ép chiều cao, kể cả khi tăng cỡ chữ.
class PrivateSpaceCard extends StatelessWidget {
  const PrivateSpaceCard({
    super.key,
    required this.title,
    required this.status,
    required this.caption,
    required this.days,
    required this.statusIcon,
    required this.onOpen,
    required this.onRename,
    this.busy = false,
  });

  final String title, status, caption, days;
  final IconData statusIcon;
  final VoidCallback? onOpen, onRename;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
    color: AppearancePanelStyle.paper,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: AppearancePanelStyle.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: busy ? null : onOpen,
      onLongPress: busy ? null : onRename,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: SLTheme.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppearancePanelStyle.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('home_ttnkhnggia_9d2bdf'),
                  onPressed: busy ? null : onRename,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppearancePanelStyle.muted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, size: 17, color: AppearancePanelStyle.rose),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    status,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      color: AppearancePanelStyle.rose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: AppearancePanelStyle.blush,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      days,
                      style: SLTheme.quicksand(
                        fontSize: 44,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppearancePanelStyle.rose,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.favorite_border_rounded,
                    size: 34,
                    color: AppearancePanelStyle.rose,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    caption,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      height: 1.5,
                      color: AppearancePanelStyle.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppearancePanelStyle.rose,
                    size: 20,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class PrivateSpaceDirectory extends StatelessWidget {
  const PrivateSpaceDirectory({
    super.key,
    required this.cards,
    required this.onBack,
    required this.onInvite,
    required this.onInvitations,
    required this.invitationLabel,
    this.busy = false,
    this.notice,
  });
  final List<Widget> cards;
  final VoidCallback onBack, onInvitations;
  final VoidCallback? onInvite;
  final String invitationLabel;
  final bool busy;
  final Widget? notice;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppearancePanelStyle.canvas,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton.filledTonal(
                    onPressed: onBack,
                    tooltip: context.tr('p7_back'),
                    style: IconButton.styleFrom(
                      backgroundColor: AppearancePanelStyle.paper,
                      foregroundColor: AppearancePanelStyle.ink,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const BackButtonIcon(),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  context.tr('p7_private_space_title'),
                  style: SLTheme.quicksand(
                    fontSize: 28,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppearancePanelStyle.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('home_nhpmnhuser_1f2686'),
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    height: 1.6,
                    color: AppearancePanelStyle.muted,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onInvite,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppearancePanelStyle.rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: Text(
                      context.tr('space_invite_friends'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onInvitations,
                  style: TextButton.styleFrom(
                    foregroundColor: AppearancePanelStyle.rose,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.mark_email_unread_outlined, size: 19),
                  label: Text(invitationLabel),
                ),
                ?notice,
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        constraints.maxWidth >= 680 &&
                        MediaQuery.textScalerOf(context).scale(14) < 24;
                    final width = wide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final card in cards)
                          SizedBox(width: width, child: card),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

double privateSpaceDialSize(double availableWidth, double preferredSize) =>
    preferredSize
        .clamp(160.0, 520.0)
        .clamp(0.0, availableWidth.clamp(0.0, 520.0));

/// Các nhãn ở ngoài vòng để chữ lớn không bị cắt hoặc thu nhỏ.
class PrivateSpaceDial extends StatelessWidget {
  const PrivateSpaceDial({
    super.key,
    required this.value,
    required this.topLabel,
    required this.bottomLabel,
    required this.size,
    this.onDate,
    this.onTop,
    this.onBottom,
    this.dark = false,
    this.fontKey = SLTheme.defaultFontKey,
    this.transparent = false,
  });
  final String value, topLabel, bottomLabel;
  final double size;
  final VoidCallback? onDate, onTop, onBottom;
  final bool dark, transparent;
  final String fontKey;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? const Color(0xFFF7EDF1) : AppearancePanelStyle.ink;
    return Column(
      children: [
        TextButton(
          onPressed: onTop,
          child: Text(
            topLabel,
            textAlign: TextAlign.center,
            style: SLTheme.textStyleForKey(
              fontKey,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          button: onDate != null,
          label: '$topLabel, $value, $bottomLabel',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onDate,
              child: Container(
                width: size,
                height: size,
                padding: EdgeInsets.all(size * .14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: transparent
                      ? Colors.white.withValues(alpha: .12)
                      : null,
                  gradient: transparent
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFF5F6), Color(0xFFEFD5DF)],
                        ),
                  border: Border.all(color: const Color(0xFFFFFAFC), width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAA5E79).withValues(alpha: .13),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: SLTheme.textStyleForKey(
                        fontKey,
                        fontSize: size * .32,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: transparent ? ink : AppearancePanelStyle.rose,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: onBottom,
          child: Text(
            bottomLabel,
            textAlign: TextAlign.center,
            style: SLTheme.textStyleForKey(
              fontKey,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
      ],
    );
  }
}

class PrivateSpaceTimeCell extends StatelessWidget {
  const PrivateSpaceTimeCell({
    super.key,
    required this.value,
    required this.label,
  });
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 76),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppearancePanelStyle.paper,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppearancePanelStyle.line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: SLTheme.quicksand(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppearancePanelStyle.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 11,
            color: AppearancePanelStyle.muted,
          ),
        ),
      ],
    ),
  );
}
