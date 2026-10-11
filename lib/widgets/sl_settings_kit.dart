import 'package:flutter/material.dart';

import '../core/sl_theme.dart';
import '../views/ui_prefs.dart';

/// Bộ token và thành phần dùng chung cho khu Cài đặt.
///
/// Mọi màn con (tài khoản, bảo mật, giao diện, widget, thông báo, dữ liệu…)
/// lấy màu, bo góc và kiểu chữ từ đây để toàn khu có cùng một ngôn ngữ thiết
/// kế: nền giấy ấm, bề mặt trắng ngà, nhấn hồng thương hiệu.
abstract final class SLSettingsColors {
  // Nền và bề mặt
  static const canvas = Color(0xFFF7F1EB);
  static const canvasTop = Color(0xFFFCF5F1);
  static const surface = Color(0xFFFFFDFA);
  static const surfaceMuted = Color(0xFFF7F0EA);
  static const border = Color(0xFFEDE2D8);
  static const divider = Color(0xFFF1E8E0);

  // Chữ
  static const ink = Color(0xFF2F2329);
  static const inkSecondary = Color(0xFF76656C);
  static const inkTertiary = Color(0xFF77676E);

  // Nhấn thương hiệu
  static const accent = SLColors.primary;
  static const accentStrong = Color(0xFFB32F50);
  static const accentSoft = Color(0xFFFDE8ED);

  // Ngữ nghĩa
  static const success = Color(0xFF237750);
  static const successSoft = Color(0xFFE5F4EC);
  static const warning = Color(0xFF92600E);
  static const warningSoft = Color(0xFFFBF0DC);
  static const danger = Color(0xFFBB3341);
  static const dangerSoft = Color(0xFFFCE8E9);
  static const info = Color(0xFF3269A5);
  static const infoSoft = Color(0xFFE7F0FA);
  static const premium = Color(0xFF88621A);
  static const premiumSoft = Color(0xFFFAF0D9);

  // Sắc độ cho ô biểu tượng: cùng độ sáng để danh sách nhìn đều mắt.
  static const rose = Color(0xFFE5677F);
  static const coral = Color(0xFFEA8256);
  static const amber = Color(0xFFDDA03A);
  static const sage = Color(0xFF4F9E7C);
  static const teal = Color(0xFF3A9AA2);
  static const sky = Color(0xFF4C8CD2);
  static const indigo = Color(0xFF6A6FD4);
  static const violet = Color(0xFF9469CB);
  static const slate = Color(0xFF7B8592);
  static const red = Color(0xFFDB4F5B);

  // Chế độ tối (chỉ dùng cho màn chính khi người dùng chọn theme đêm).
  static const darkCanvas = Color(0xFF151116);
  static const darkSurface = Color(0xFF211B22);
  static const darkSurfaceMuted = Color(0xFF2A232B);
  static const darkBorder = Color(0xFF362D37);
  static const darkDivider = Color(0xFF2E2630);
  static const darkInk = Color(0xFFF6EFF3);
  static const darkInkSecondary = Color(0xFFBBAAB4);
  static const darkInkTertiary = Color(0xFF9B8992);
}

abstract final class SLSettingsRadius {
  static const double tile = 11;
  static const double control = 14;
  static const double card = 20;
  static const double sheet = 28;
}

/// Bảng màu đã phân giải theo chế độ sáng/tối.
@immutable
class SLSettingsPalette {
  const SLSettingsPalette._({
    required this.isDark,
    required this.canvas,
    required this.canvasTop,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.divider,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.accent,
    required this.accentSoft,
    required this.shadow,
  });

  final bool isDark;
  final Color canvas;
  final Color canvasTop;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color divider;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color accent;
  final Color accentSoft;
  final List<BoxShadow> shadow;

  static const light = SLSettingsPalette._(
    isDark: false,
    canvas: SLSettingsColors.canvas,
    canvasTop: SLSettingsColors.canvasTop,
    surface: SLSettingsColors.surface,
    surfaceMuted: SLSettingsColors.surfaceMuted,
    border: SLSettingsColors.border,
    divider: SLSettingsColors.divider,
    ink: SLSettingsColors.ink,
    inkSecondary: SLSettingsColors.inkSecondary,
    inkTertiary: SLSettingsColors.inkTertiary,
    accent: SLSettingsColors.accentStrong,
    accentSoft: SLSettingsColors.accentSoft,
    shadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x0D4A2A33),
        blurRadius: 18,
        spreadRadius: -6,
        offset: Offset(0, 8),
      ),
    ],
  );

  static const dark = SLSettingsPalette._(
    isDark: true,
    canvas: SLSettingsColors.darkCanvas,
    canvasTop: Color(0xFF1C161D),
    surface: SLSettingsColors.darkSurface,
    surfaceMuted: SLSettingsColors.darkSurfaceMuted,
    border: SLSettingsColors.darkBorder,
    divider: SLSettingsColors.darkDivider,
    ink: SLSettingsColors.darkInk,
    inkSecondary: SLSettingsColors.darkInkSecondary,
    inkTertiary: SLSettingsColors.darkInkTertiary,
    accent: Color(0xFFF2849B),
    accentSoft: Color(0x33E65372),
    shadow: <BoxShadow>[],
  );

  static SLSettingsPalette resolve(bool isDark) => isDark ? dark : light;

  /// Theme đêm của SoulLocket được chọn qua UiPrefs, không qua Brightness.
  static bool get isNightTheme {
    final key = UiPrefs.notifier.value.themeKey;
    return key == 'theme-night' ||
        key == 'theme-dark' ||
        key == 'theme-true-black';
  }

  /// Màu nhấn đã làm dịu cho nền tối để giữ độ tương phản.
  Color tint(Color color) =>
      isDark ? Color.lerp(color, const Color(0xFFFFF3F6), 0.28)! : color;
}

/// Kiểu chữ dùng chung, luôn theo phông người dùng chọn.
abstract final class SLSettingsText {
  static TextStyle pageTitle(Color color) => SLTheme.quicksand(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.2,
    color: color,
  );

  static TextStyle sectionLabel(Color color) => SLTheme.quicksand(
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    height: 1.3,
    letterSpacing: 0.3,
    color: color,
  );

  static TextStyle title(Color color) => SLTheme.quicksand(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: color,
  );

  static TextStyle body(Color color) => SLTheme.quicksand(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: color,
  );

  static TextStyle caption(Color color) => SLTheme.quicksand(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: color,
  );
}

/// Nền chung cho trang cài đặt: chuyển sắc rất nhẹ, không hoa văn gây nhiễu.
class SLSettingsBackdrop extends StatelessWidget {
  const SLSettingsBackdrop({super.key, this.isDark = false, this.child});

  final bool isDark;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.42],
          colors: [palette.canvasTop, palette.canvas],
        ),
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}

/// Ô biểu tượng bo góc. `filled` = nền đặc chữ trắng (danh mục chính);
/// ngược lại là nền nhạt, biểu tượng màu (nội dung bên trong trang con).
class SLSettingsIconTile extends StatelessWidget {
  const SLSettingsIconTile({
    super.key,
    required this.icon,
    this.color = SLSettingsColors.rose,
    this.size = 36,
    this.filled = true,
    this.isDark = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool filled;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.31);
    if (filled) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.14)!, color],
          ),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      );
    }
    final palette = SLSettingsPalette.resolve(isDark);
    final tone = palette.tint(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: radius,
      ),
      child: Icon(icon, color: tone, size: size * 0.52),
    );
  }
}

/// Nhãn nhóm phía trên mỗi khối cài đặt.
class SLSettingsSectionLabel extends StatelessWidget {
  const SLSettingsSectionLabel({
    super.key,
    required this.title,
    this.isDark = false,
    this.topPadding = 22,
    this.horizontalPadding = 20,
    this.trailing,
  });

  final String title;
  final bool isDark;
  final double topPadding;
  final double horizontalPadding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        horizontalPadding + 4,
        topPadding,
        horizontalPadding,
        8,
      ),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: SLSettingsText.sectionLabel(palette.inkTertiary),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Khối nhóm các dòng cài đặt (kiểu danh sách có nhóm).
class SLSettingsGroup extends StatelessWidget {
  const SLSettingsGroup({
    super.key,
    required this.children,
    this.isDark = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.dividerIndent = 66,
    this.autoDividers = false,
  });

  final List<Widget> children;
  final bool isDark;
  final EdgeInsetsGeometry margin;
  final double dividerIndent;

  /// Tự chèn đường kẻ giữa các phần tử con.
  final bool autoDividers;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (autoDividers && i > 0) {
        items.add(SLSettingsDivider(isDark: isDark, indent: dividerIndent));
      }
      items.add(children[i]);
    }
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SLSettingsRadius.card),
          boxShadow: palette.shadow,
        ),
        child: Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SLSettingsRadius.card),
            side: BorderSide(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items,
          ),
        ),
      ),
    );
  }
}

class SLSettingsDivider extends StatelessWidget {
  const SLSettingsDivider({super.key, this.isDark = false, this.indent = 66});

  final bool isDark;
  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(start: indent),
    child: Divider(
      height: 1,
      thickness: 1,
      color: SLSettingsPalette.resolve(isDark).divider,
    ),
  );
}

/// Thẻ nội dung tự do (form, mô tả, nút hành động) trong trang con.
class SLSettingsCard extends StatelessWidget {
  const SLSettingsCard({
    super.key,
    required this.child,
    this.isDark = false,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final bool isDark;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: BorderRadius.circular(SLSettingsRadius.card),
        border: Border.all(color: borderColor ?? palette.border),
        boxShadow: palette.shadow,
      ),
      child: child,
    );
  }
}

/// Một dòng cài đặt: biểu tượng, tiêu đề, mô tả, giá trị và mũi tên.
class SLSettingsRow extends StatelessWidget {
  const SLSettingsRow({
    super.key,
    required this.title,
    this.icon,
    this.iconColor = SLSettingsColors.rose,
    this.filledIcon = true,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.isDark = false,
    this.destructive = false,
    this.showChevron,
    this.enabled = true,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 11, 12, 11),
  });

  final String title;
  final IconData? icon;
  final Color iconColor;
  final bool filledIcon;
  final String? subtitle;

  /// Giá trị hiện tại hiển thị bên phải (vd. "Nữ", "Luôn bật").
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDark;
  final bool destructive;
  final bool? showChevron;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    final danger = palette.tint(SLSettingsColors.danger);
    final effectiveIconColor = destructive ? SLSettingsColors.red : iconColor;
    final chevron = showChevron ?? (onTap != null && !destructive);
    final hasSubtitle = subtitle?.trim().isNotEmpty ?? false;
    final hasValue = value?.trim().isNotEmpty ?? false;

    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: hasSubtitle ? 66 : 56),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (icon != null) ...[
              SLSettingsIconTile(
                icon: icon!,
                color: effectiveIconColor,
                filled: filledIcon,
                isDark: isDark,
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SLSettingsText.title(
                      destructive ? danger : palette.ink,
                    ),
                  ),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: SLSettingsText.caption(palette.inkSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (hasValue) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: SLSettingsText.body(palette.inkTertiary),
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            if (chevron) ...[
              const SizedBox(width: 4),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: palette.inkTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final row = Opacity(opacity: enabled ? 1 : 0.5, child: content);
    if (onTap == null) return row;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        splashColor: effectiveIconColor.withValues(alpha: 0.06),
        highlightColor: palette.ink.withValues(alpha: 0.035),
        child: row,
      ),
    );
  }
}

enum SLSettingsTone { neutral, accent, success, warning, danger, info, premium }

({Color fg, Color bg}) _toneColors(SLSettingsTone tone, bool isDark) {
  final (fg, bg) = switch (tone) {
    SLSettingsTone.neutral => (
      SLSettingsColors.inkSecondary,
      SLSettingsColors.surfaceMuted,
    ),
    SLSettingsTone.accent => (
      SLSettingsColors.accentStrong,
      SLSettingsColors.accentSoft,
    ),
    SLSettingsTone.success => (
      SLSettingsColors.success,
      SLSettingsColors.successSoft,
    ),
    SLSettingsTone.warning => (
      SLSettingsColors.warning,
      SLSettingsColors.warningSoft,
    ),
    SLSettingsTone.danger => (
      SLSettingsColors.danger,
      SLSettingsColors.dangerSoft,
    ),
    SLSettingsTone.info => (SLSettingsColors.info, SLSettingsColors.infoSoft),
    SLSettingsTone.premium => (
      SLSettingsColors.premium,
      SLSettingsColors.premiumSoft,
    ),
  };
  if (!isDark) return (fg: fg, bg: bg);
  return (
    fg: Color.lerp(fg, Colors.white, 0.4)!,
    bg: fg.withValues(alpha: 0.2),
  );
}

/// Nhãn trạng thái nhỏ (Đã bật, Chưa xác thực, PRO…).
class SLSettingsPill extends StatelessWidget {
  const SLSettingsPill({
    super.key,
    required this.label,
    this.tone = SLSettingsTone.neutral,
    this.icon,
    this.isDark = false,
    this.dense = false,
  });

  final String label;
  final SLSettingsTone tone;
  final IconData? icon;
  final bool isDark;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(tone, isDark);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: colors.fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: dense ? 10 : 11.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: colors.fg,
                letterSpacing: dense ? 0.3 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hộp thông báo (thông tin, cảnh báo, nguy hiểm…) trong trang con.
class SLSettingsNotice extends StatelessWidget {
  const SLSettingsNotice({
    super.key,
    required this.message,
    this.title,
    this.tone = SLSettingsTone.info,
    this.icon,
    this.action,
    this.trailing,
    this.isDark = false,
    this.margin = EdgeInsets.zero,
  });

  final String message;
  final String? title;
  final SLSettingsTone tone;
  final IconData? icon;
  final Widget? action;
  final Widget? trailing;
  final bool isDark;
  final EdgeInsetsGeometry margin;

  IconData get _defaultIcon => switch (tone) {
    SLSettingsTone.success => Icons.check_circle_outline_rounded,
    SLSettingsTone.warning => Icons.warning_amber_rounded,
    SLSettingsTone.danger => Icons.error_outline_rounded,
    SLSettingsTone.premium => Icons.workspace_premium_outlined,
    _ => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    final colors = _toneColors(tone, isDark);
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.fg.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _defaultIcon, color: colors.fg, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: SLTheme.quicksand(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: colors.fg,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(message, style: SLSettingsText.caption(palette.ink)),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

enum SLSettingsButtonVariant { primary, secondary, tonal, danger, ghost }

/// Nút chuẩn cho khu Cài đặt.
class SLSettingsButton extends StatelessWidget {
  const SLSettingsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = SLSettingsButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.color,
    this.isDark = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SLSettingsButtonVariant variant;
  final bool loading;
  final bool expand;

  /// Ghi đè màu nhấn (vd. nút xanh cho thao tác Google).
  final Color? color;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    final accent = color ?? SLSettingsColors.accentStrong;
    final (Color bg, Color fg, BorderSide side) = switch (variant) {
      SLSettingsButtonVariant.primary => (
        accent,
        Colors.white,
        BorderSide.none,
      ),
      SLSettingsButtonVariant.secondary => (
        palette.surface,
        palette.ink,
        BorderSide(color: palette.border),
      ),
      SLSettingsButtonVariant.tonal => (
        accent.withValues(alpha: isDark ? 0.2 : 0.1),
        isDark ? Color.lerp(accent, Colors.white, 0.4)! : accent,
        BorderSide.none,
      ),
      SLSettingsButtonVariant.danger => (
        SLSettingsColors.dangerSoft,
        SLSettingsColors.danger,
        BorderSide(color: SLSettingsColors.danger.withValues(alpha: 0.18)),
      ),
      SLSettingsButtonVariant.ghost => (
        Colors.transparent,
        isDark ? Color.lerp(accent, Colors.white, 0.4)! : accent,
        BorderSide.none,
      ),
    };
    final disabled = onPressed == null || loading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
              backgroundColor: fg.withValues(alpha: 0.18),
            ),
          )
        else if (icon != null)
          Icon(icon, size: compact ? 16 : 18),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
    final button = TextButton(
      onPressed: disabled ? null : onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(compact ? 40 : 48, compact ? 40 : 50),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 9 : 13,
        ),
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: variant == SLSettingsButtonVariant.ghost
            ? Colors.transparent
            : (variant == SLSettingsButtonVariant.primary
                  ? accent.withValues(alpha: 0.42)
                  : bg),
        disabledForegroundColor: variant == SLSettingsButtonVariant.primary
            ? Colors.white.withValues(alpha: 0.9)
            : fg.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SLSettingsRadius.control),
          side: side,
        ),
      ),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Nút quay lại tròn dùng ở đầu mọi trang con.
class SLSettingsBackButton extends StatelessWidget {
  const SLSettingsBackButton({
    super.key,
    required this.onPressed,
    this.tooltip,
    this.isDark = false,
    this.icon = Icons.arrow_back_ios_new_rounded,
  });

  final VoidCallback onPressed;
  final String? tooltip;
  final bool isDark;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.border),
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 17),
    );
  }
}

/// Đầu trang con: nút quay lại, tiêu đề lớn, mô tả và biểu tượng nhận diện.
class SLSettingsPageHeader extends StatelessWidget {
  const SLSettingsPageHeader({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.leading,
    this.iconColor = SLSettingsColors.rose,
    this.onBack,
    this.backLabel,
    this.trailing,
    this.isDark = false,
    this.padding = const EdgeInsets.fromLTRB(4, 6, 4, 18),
  });

  final String title;
  final String? description;
  final IconData? icon;

  /// Thay ô biểu tượng bằng nội dung riêng (vd. logo thương hiệu).
  final Widget? leading;
  final Color iconColor;
  final VoidCallback? onBack;
  final String? backLabel;
  final Widget? trailing;
  final bool isDark;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    final showIcon =
        (icon != null || leading != null) &&
        MediaQuery.textScalerOf(context).scale(14) < 22;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null || trailing != null) ...[
            Row(
              children: [
                if (onBack != null)
                  SLSettingsBackButton(
                    onPressed: onBack!,
                    tooltip: backLabel,
                    isDark: isDark,
                  ),
                const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: SLSettingsText.pageTitle(palette.ink),
                  ),
                ),
              ),
              if (showIcon) ...[
                const SizedBox(width: 14),
                ExcludeSemantics(
                  child: leading != null
                      ? Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.accentSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: leading,
                        )
                      : SLSettingsIconTile(
                          icon: icon!,
                          color: iconColor,
                          size: 46,
                          isDark: isDark,
                        ),
                ),
              ],
            ],
          ),
          if (description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: palette.inkSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tiêu đề của một khối nội dung bên trong trang con.
class SLSettingsBlockHeading extends StatelessWidget {
  const SLSettingsBlockHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.iconColor = SLSettingsColors.rose,
    this.trailing,
    this.isDark = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Color iconColor;
  final Widget? trailing;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    final hasSubtitle = subtitle?.trim().isNotEmpty ?? false;
    return Row(
      crossAxisAlignment: hasSubtitle
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.tint(iconColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: leading,
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          SLSettingsIconTile(
            icon: icon!,
            color: iconColor,
            filled: false,
            size: 38,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: SLTheme.quicksand(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: palette.ink,
                  ),
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: SLSettingsText.caption(palette.inkSecondary),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Công tắc theo màu thương hiệu.
class SLSettingsSwitch extends StatelessWidget {
  const SLSettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.isDark = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: SLSettingsColors.accent,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: isDark ? palette.border : const Color(0xFFE6DCD3),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbIcon: const WidgetStatePropertyAll(null),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// Dòng có công tắc, dùng trong cả danh sách và thẻ nội dung.
class SLSettingsSwitchRow extends StatelessWidget {
  const SLSettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.iconColor = SLSettingsColors.rose,
    this.onTap,
    this.ignoreDirectSwitchTap = false,
    this.isDark = false,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool ignoreDirectSwitchTap;
  final bool isDark;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    final toggle = SLSettingsSwitch(
      value: value,
      onChanged: onChanged,
      isDark: isDark,
    );
    final tapHandler =
        onTap ?? (onChanged == null ? null : () => onChanged!(!value));
    return Semantics(
      label: title,
      toggled: value,
      button: true,
      excludeSemantics: true,
      onTap: tapHandler,
      child: InkWell(
        onTap: tapHandler,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (icon != null) ...[
                  SLSettingsIconTile(
                    icon: icon!,
                    color: iconColor,
                    filled: false,
                    size: 36,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 13),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: SLSettingsText.title(palette.ink)),
                      if (subtitle?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!.trim(),
                          style: SLSettingsText.caption(palette.inkSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (ignoreDirectSwitchTap)
                  IgnorePointer(child: toggle)
                else
                  toggle,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô chọn giá trị (mở hộp chọn khi bấm), trông giống ô nhập liệu.
class SLSettingsSelectField extends StatelessWidget {
  const SLSettingsSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.trailingIcon = Icons.expand_more_rounded,
    this.isDark = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData trailingIcon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: palette.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SLSettingsRadius.control),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: palette.inkSecondary),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: SLTheme.quicksand(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: palette.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: SLTheme.quicksand(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(trailingIcon, size: 22, color: palette.inkTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bước hướng dẫn có số thứ tự.
class SLSettingsStep extends StatelessWidget {
  const SLSettingsStep({
    super.key,
    required this.index,
    required this.text,
    this.isDark = false,
  });

  final String index;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = SLSettingsPalette.resolve(isDark);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: SLSettingsColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            index,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: SLSettingsColors.accentStrong,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text, style: SLSettingsText.caption(palette.ink)),
          ),
        ),
      ],
    );
  }
}

/// Trang trí ô nhập liệu thống nhất.
InputDecoration slSettingsInputDecoration({
  String? hint,
  String? label,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
  String? helperText,
  bool isDark = false,
  Color? focusColor,
}) {
  final palette = SLSettingsPalette.resolve(isDark);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(SLSettingsRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    errorText: errorText,
    helperText: helperText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    prefixIconColor: palette.inkTertiary,
    suffixIconColor: palette.inkTertiary,
    hintStyle: SLTheme.quicksand(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      color: palette.inkTertiary,
    ),
    labelStyle: SLTheme.quicksand(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: palette.inkSecondary,
    ),
    helperStyle: SLSettingsText.caption(palette.inkSecondary),
    counterStyle: SLTheme.quicksand(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: palette.inkTertiary,
    ),
    filled: true,
    fillColor: palette.surfaceMuted,
    isDense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: border(palette.border),
    enabledBorder: border(palette.border),
    disabledBorder: border(palette.divider),
    focusedBorder: border(focusColor ?? SLSettingsColors.accent, 1.5),
    errorBorder: border(SLSettingsColors.danger),
    focusedErrorBorder: border(SLSettingsColors.danger, 1.5),
  );
}

TextStyle slSettingsInputTextStyle({bool isDark = false}) => SLTheme.quicksand(
  fontSize: 14.5,
  fontWeight: FontWeight.w700,
  color: SLSettingsPalette.resolve(isDark).ink,
);
