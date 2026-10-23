import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/sl_theme.dart';
import '../../../../widgets/sl_settings_kit.dart';

/// Đầu trang Cài đặt: nút quay lại, tiêu đề và hành động tìm kiếm.
class SettingsHomeHeader extends StatelessWidget {
  const SettingsHomeHeader({
    super.key,
    required this.title,
    required this.isDark,
    this.onBack,
    this.backLabel,
    this.actions = const <Widget>[],
  });

  final String title;
  final bool isDark;
  final VoidCallback? onBack;
  final String? backLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          12,
          MediaQuery.paddingOf(context).top + 8,
          12,
          8,
        ),
        decoration: BoxDecoration(
          color: palette.canvasTop.withValues(alpha: 0.97),
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              if (onBack != null) ...[
                SLSettingsBackButton(
                  onPressed: onBack!,
                  tooltip: backLabel,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
              ] else
                const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: SLTheme.quicksand(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: palette.ink,
                    ),
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút hành động tròn ở đầu trang (tìm kiếm…).
class SettingsHeaderAction extends StatelessWidget {
  const SettingsHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isDark = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) => SLSettingsBackButton(
    onPressed: onTap,
    tooltip: tooltip,
    isDark: isDark,
    icon: icon,
  );
}

/// Thẻ hồ sơ ở đầu Cài đặt.
class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard({
    super.key,
    required this.avatar,
    required this.name,
    required this.detail,
    required this.footerLabel,
    required this.onTap,
    this.isPro = false,
    this.proLabel = 'PRO',
    this.isDark = false,
  });

  final Widget avatar;
  final String name;
  final String detail;
  final String footerLabel;
  final VoidCallback onTap;
  final bool isPro;
  final String proLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    return Semantics(
      button: true,
      label: '$name. $detail',
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: palette.shadow,
        ),
        child: Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            highlightColor: palette.ink.withValues(alpha: 0.03),
            child: Stack(
              children: [
                // Dải màu mềm phía sau ảnh đại diện, giữ chút ấm áp thương hiệu.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 92,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? const [Color(0x2EE65372), Color(0x00E65372)]
                            : const [Color(0xFFFDE8EE), Color(0x00FDE8EE)],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  SLSettingsColors.rose,
                                  SLSettingsColors.coral,
                                ],
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.surface,
                              ),
                              child: avatar,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SLTheme.quicksand(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          height: 1.25,
                                          color: palette.ink,
                                        ),
                                      ),
                                    ),
                                    if (isPro) ...[
                                      const SizedBox(width: 8),
                                      SLSettingsPill(
                                        label: proLabel,
                                        tone: SLSettingsTone.premium,
                                        icon: Icons.workspace_premium_rounded,
                                        isDark: isDark,
                                        dense: true,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SLSettingsText.caption(
                                    palette.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: palette.divider),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.manage_accounts_outlined,
                            size: 18,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              footerLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: palette.accent,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                            color: palette.inkTertiary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Các ô nhanh cùng chiều cao. Đủ chỗ thì xếp một hàng; có ô thứ ba mà màn
/// hẹp thì chia lưới hai cột; chữ lớn hoặc màn rất hẹp thì xếp dọc để đọc đủ.
class SettingsQuickActionsLayout extends StatelessWidget {
  const SettingsQuickActionsLayout({
    super.key,
    required this.primary,
    required this.secondary,
    this.tertiary,
  });

  final Widget primary;
  final Widget secondary;
  final Widget? tertiary;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final growth = scale < 1 ? 1.0 : scale;
      final width = constraints.maxWidth;
      final third = tertiary;
      // Ba ô một hàng: từ 100dp/ô vẫn vừa icon 40dp cạnh nhãn PRO gọn.
      if (third != null && width >= 100 * growth * 3 + _gap * 2) {
        return _row([primary, secondary, third]);
      }
      if (width < 132 * growth * 2 + _gap) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primary,
            const SizedBox(height: _gap),
            secondary,
            if (third != null) ...[const SizedBox(height: _gap), third],
          ],
        );
      }
      if (third == null) return _row([primary, secondary]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row([primary, secondary]),
          const SizedBox(height: _gap),
          // Giữ ô thứ ba rộng bằng một cột để lưới không lệch.
          _row([third, const SizedBox.shrink()]),
        ],
      );
    },
  );

  static Widget _row(List<Widget> tiles) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(child: tiles[i]),
        ],
      ],
    ),
  );
}

/// Ô truy cập nhanh (ghép nối, không gian đếm ngày).
class SettingsQuickTile extends StatelessWidget {
  const SettingsQuickTile({
    super.key,
    required this.title,
    required this.onTap,
    this.icon,
    this.color = SLSettingsColors.rose,
    this.leading,
    this.caption,
    this.captionTone = SLSettingsTone.neutral,
    this.semanticLabel,
    this.isDark = false,
    this.badge,
    this.backgroundColor,
    this.borderColor,
    this.background,
  });

  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;

  /// Thay biểu tượng bằng nội dung riêng (vd. hai ảnh đại diện).
  final Widget? leading;
  final String? caption;
  final SLSettingsTone captionTone;
  final String? semanticLabel;
  final bool isDark;
  final Widget? badge;
  final Color? backgroundColor;
  final Color? borderColor;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    final captionColor = switch (captionTone) {
      SLSettingsTone.success => palette.tint(SLSettingsColors.success),
      SLSettingsTone.accent => palette.accent,
      SLSettingsTone.warning => palette.tint(SLSettingsColors.warning),
      _ => palette.inkSecondary,
    };
    return Semantics(
      button: true,
      label: semanticLabel ?? (caption == null ? title : '$title. $caption'),
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SLSettingsRadius.card),
          boxShadow: palette.shadow,
        ),
        child: Material(
          color: backgroundColor ?? palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SLSettingsRadius.card),
            side: BorderSide(color: borderColor ?? palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            highlightColor: palette.ink.withValues(alpha: 0.03),
            child: Stack(
              children: [
                if (background != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(child: background!),
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(minHeight: 116),
                  padding: const EdgeInsets.fromLTRB(12, 13, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 40,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child:
                                  leading ??
                                  SLSettingsIconTile(
                                    icon: icon ?? Icons.circle_outlined,
                                    color: color,
                                    size: 40,
                                    isDark: isDark,
                                  ),
                            ),
                            // Lấn vào lề phải của thẻ để ô hẹp (ba ô một hàng
                            // trên màn 360dp) không đè nhãn lên icon.
                            if (badge != null)
                              PositionedDirectional(
                                top: 0,
                                end: -4,
                                child: badge!,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: palette.ink,
                        ),
                      ),
                      if (caption?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 3),
                        Text(
                          caption!,
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: captionColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chân trang: logo, tên ứng dụng, khẩu hiệu và phiên bản.
class SettingsMenuFooter extends StatefulWidget {
  const SettingsMenuFooter({
    super.key,
    required this.tagline,
    this.versionLabel,
    this.isDark = false,
  });

  final String tagline;

  /// Nhãn "Phiên bản"; để trống thì không hiển thị số phiên bản.
  final String? versionLabel;
  final bool isDark;

  @override
  State<SettingsMenuFooter> createState() => _SettingsMenuFooterState();
}

class _SettingsMenuFooterState extends State<SettingsMenuFooter> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    if (widget.versionLabel != null) _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final build = info.buildNumber.trim();
      setState(() {
        _version = build.isEmpty ? info.version : '${info.version} ($build)';
      });
    } catch (_) {
      // Không có thông tin phiên bản thì chỉ ẩn dòng này.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(widget.isDark);
    return Padding(
      // Giữ chân trang gọn khi người dùng tăng cỡ chữ hệ thống.
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset('assets/icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'SoulLocket',
              style: SLTheme.textStyleForKey(
                'dancingScript',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.tagline,
              textAlign: TextAlign.center,
              style: SLSettingsText.caption(palette.inkTertiary),
            ),
            if (_version.isNotEmpty && widget.versionLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                '${widget.versionLabel} $_version',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.inkTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
