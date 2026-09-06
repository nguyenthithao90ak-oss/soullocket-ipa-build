import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';

/// Khung giao diện dùng riêng cho trang tuỳ chỉnh widget.
///
/// Các thành phần ở đây chỉ lo phần trình bày để màn cài đặt vẫn giữ nguyên
/// luồng lưu dữ liệu và đồng bộ widget ở lớp cha.
class WidgetStudioPanel extends StatelessWidget {
  const WidgetStudioPanel({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.onBack,
    this.onClose,
  });

  final String title;
  final Widget child;
  final Widget? leading;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFC),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF0E5E8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4B2C38).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFF1F5), Color(0xFFF4FCFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  if (onBack != null) ...[
                    _HeaderButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack!,
                    ),
                    const SizedBox(width: 10),
                  ],
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.84),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF5D7E0)),
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child:
                            leading ??
                            const Icon(
                              Icons.favorite_rounded,
                              size: 20,
                              color: Color(0xFFE9567D),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF312C36),
                      ),
                    ),
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 8),
                    _HeaderButton(icon: Icons.close_rounded, onTap: onClose!),
                  ],
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFF1E5E9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEEDDE3)),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF796C75)),
        ),
      ),
    );
  }
}

class WidgetStudioPreviewStage extends StatelessWidget {
  const WidgetStudioPreviewStage({
    super.key,
    required this.title,
    required this.themeName,
    required this.child,
  });

  final String title;
  final String themeName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9FA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF4E2E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4EC),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    size: 17,
                    color: Color(0xFFE9567D),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF302D35),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 112),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF0DEE4)),
                  ),
                  child: Text(
                    themeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF8E6A76),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WidgetStudioSection extends StatelessWidget {
  const WidgetStudioSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.leading,
    this.accent = const Color(0xFFE9567D),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E5E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child:
                          leading ??
                          Icon(
                            icon ?? Icons.tune_rounded,
                            size: 19,
                            color: accent,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SLTheme.quicksand(
                          fontSize: 13.8,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF302D35),
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: SLTheme.quicksand(
                            fontSize: 11.4,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7B7280),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            child,
          ],
        ),
      ),
    );
  }
}

class WidgetStudioTab {
  const WidgetStudioTab({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

class WidgetStudioSegmentedControl extends StatelessWidget {
  const WidgetStudioSegmentedControl({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onChanged,
  });

  final List<WidgetStudioTab> items;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F4F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0E4E8)),
        ),
        child: Row(
          children: items
              .map((item) {
                final selected = item.id == selectedId;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.label,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(item.id),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF643344,
                                      ).withValues(alpha: 0.09),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: selected
                                    ? const Color(0xFFE9567D)
                                    : const Color(0xFF8B7B82),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: 10.6,
                                  fontWeight: selected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: selected
                                      ? const Color(0xFFB83D60)
                                      : const Color(0xFF746A70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class WidgetStudioThemeOption {
  const WidgetStudioThemeOption({
    required this.id,
    required this.label,
    required this.colors,
    required this.icon,
  });

  final String id;
  final String label;
  final List<Color> colors;
  final IconData icon;
}

class WidgetStudioThemePicker extends StatelessWidget {
  const WidgetStudioThemePicker({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final List<WidgetStudioThemeOption> options;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 410 ? 5 : 4;
        const gap = 9.0;
        final itemWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: options
              .map((option) {
                final selected = option.id == selectedId;
                final isLight = option.id == 'white';
                return SizedBox(
                  width: itemWidth,
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: option.label,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(option.id),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: selected
                                ? option.colors.first.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? option.colors.last.withValues(alpha: 0.9)
                                  : const Color(0xFFE9E2E5),
                              width: selected ? 1.7 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AspectRatio(
                                aspectRatio: 1.28,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: option.colors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                    border: isLight
                                        ? Border.all(
                                            color: const Color(0xFFDDE3EA),
                                          )
                                        : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 6,
                                        left: 7,
                                        child: Icon(
                                          option.icon,
                                          size: 16,
                                          color: isLight
                                              ? const Color(0xFF93A1B2)
                                              : Colors.white.withValues(
                                                  alpha: 0.78,
                                                ),
                                        ),
                                      ),
                                      if (selected)
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Container(
                                            margin: const EdgeInsets.all(5),
                                            width: 20,
                                            height: 20,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check_rounded,
                                              size: 14,
                                              color: option.colors.last,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 27,
                                child: Center(
                                  child: Text(
                                    option.label,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: SLTheme.quicksand(
                                      fontSize: 10.1,
                                      fontWeight: selected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: selected
                                          ? const Color(0xFFB83D60)
                                          : const Color(0xFF70666C),
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}
