import 'package:flutter/material.dart';

import '../../../../../../core/sl_theme.dart';
import '../../../../../../utils/services/l10n_service.dart';
import '../../../../../../widgets/sl_settings_kit.dart';
import '../../theme/appearance_panel_widgets.dart';
import '../../../../widgets/main_home/hero/balanced_countdown_style.dart';

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
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(SLSettingsPalette.isNightTheme);
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.border),
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
                        color: palette.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('home_ttnkhnggia_9d2bdf'),
                    onPressed: busy ? null : onRename,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: palette.inkSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(statusIcon, size: 17, color: palette.accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      status,
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        color: palette.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              days,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontSize: 44,
                                height: 1.05,
                                fontWeight: FontWeight.w700,
                                color: palette.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              context.tr('p7_day_lowercase'),
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: palette.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 34,
                      color: palette.accent,
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
                        color: palette.inkSecondary,
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
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: palette.accent,
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
}

class PrivateSpaceDirectory extends StatelessWidget {
  const PrivateSpaceDirectory({
    super.key,
    required this.cards,
    required this.onBack,
    required this.onInvite,
    required this.onInvitations,
    required this.invitationLabel,
    required this.houseCode,
    required this.onCopyHouseCode,
    required this.onShareHouseCode,
    this.busy = false,
    this.notice,
  });
  final List<Widget> cards;
  final VoidCallback onBack, onInvitations;
  final VoidCallback? onInvite;
  final String invitationLabel;
  final String houseCode;
  final VoidCallback? onCopyHouseCode, onShareHouseCode;
  final bool busy;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(SLSettingsPalette.isNightTheme);
    return ColoredBox(
      color: palette.canvas,
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
                        backgroundColor: palette.surface,
                        foregroundColor: palette.ink,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const BackButtonIcon(),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.tr('home_khnggianmn_5b94a7'),
                    style: SLTheme.quicksand(
                      fontSize: 28,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('home_nhpmnhuser_1f2686'),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      height: 1.6,
                      color: palette.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  PrivateSpaceCodeCard(
                    code: houseCode,
                    onCopy: onCopyHouseCode,
                    onShare: onShareHouseCode,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : onInvite,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent,
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
                          : const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 20,
                            ),
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
                      foregroundColor: palette.accent,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 19,
                    ),
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
}

/// Mã nhà được đặt ngay trên trang để người dùng không phải mở thêm hộp thoại
/// khi muốn gửi mã cho người kia.
class PrivateSpaceCodeCard extends StatelessWidget {
  const PrivateSpaceCodeCard({
    super.key,
    required this.code,
    this.onCopy,
    this.onShare,
  });

  final String code;
  final VoidCallback? onCopy, onShare;

  @override
  Widget build(BuildContext context) {
    final normalizedCode = code.trim();
    final hasCode = normalizedCode.isNotEmpty && normalizedCode != 'local_self';
    final palette = SLSettingsPalette.resolve(SLSettingsPalette.isNightTheme);
    final codeGradient = palette.isDark
        ? const [Color(0xFF33202A), Color(0xFF4A2637)]
        : const [Color(0xFFFFF2F6), Color(0xFFFFE4EC)];

    return Container(
      key: const ValueKey<String>('private-space-code-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: codeGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.accent.withValues(alpha: .48)),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: .12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.surface.withValues(
                    alpha: palette.isDark ? .72 : .76,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.key_rounded, color: palette.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('countdown_space_code_title'),
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('countdown_space_code_hint'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        height: 1.45,
                        color: palette.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasCode) ...[
            Container(
              key: const ValueKey<String>('private-space-code-value'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.surface.withValues(
                  alpha: palette.isDark ? .86 : .84,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: palette.accent.withValues(alpha: .42),
                ),
              ),
              child: SelectableText(
                normalizedCode,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: palette.accent,
                ),
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackActions =
                    constraints.maxWidth < 350 ||
                    MediaQuery.textScalerOf(context).scale(14) > 17;
                final copy = OutlinedButton.icon(
                  key: const ValueKey<String>('private-space-copy-code'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(context.tr('p7_copy_house_code')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.accent,
                    side: BorderSide(
                      color: palette.accent.withValues(alpha: .66),
                    ),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                );
                final share = FilledButton.icon(
                  key: const ValueKey<String>('private-space-share-code'),
                  onPressed: onShare,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(context.tr('pairing_ui_share')),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                );
                if (stackActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [copy, const SizedBox(height: 8), share],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 8),
                    Expanded(child: share),
                  ],
                );
              },
            ),
          ] else
            Text(
              context.tr('p7_current_house_missing'),
              style: SLTheme.quicksand(
                color: palette.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
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
    this.dark = false,
  });
  final String value, label;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final palette = BalancedCountdownPalette(dark: dark);
    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.paper, palette.blush],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border.withValues(alpha: .55)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: SLTheme.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: SLTheme.quicksand(fontSize: 11, color: palette.muted),
          ),
        ],
      ),
    );
  }
}
