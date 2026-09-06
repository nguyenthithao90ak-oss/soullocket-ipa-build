import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'auth_visual_style.dart';
import 'aurora_tab_switcher.dart';

/// Khung xác thực dùng chung, tự đổi bố cục theo chiều rộng khả dụng.
class AuroraLoginShell extends StatelessWidget {
  final bool compact;
  final bool isLoginTab;
  final VoidCallback onSelectLogin;
  final VoidCallback onSelectRegister;
  final Widget authSection;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenContact;

  const AuroraLoginShell({
    super.key,
    required this.compact,
    required this.isLoginTab,
    required this.onSelectLogin,
    required this.onSelectRegister,
    required this.authSection,
    required this.onOpenGuide,
    required this.onOpenContact,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        final header = _AuthBrandHeader(isLoginTab: isLoginTab, wide: wide);
        final form = Material(
          color: style.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: style.border),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 20 : 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuroraTabSwitcher(
                  isLoginTab: isLoginTab,
                  onSelectLogin: onSelectLogin,
                  onSelectRegister: onSelectRegister,
                ),
                const SizedBox(height: 24),
                AnimatedSize(
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  alignment: Alignment.topCenter,
                  child: authSection,
                ),
              ],
            ),
          ),
        );
        final help = Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            children: [
              _HelpLink(
                icon: Icons.help_outline_rounded,
                label: context.tr('auth_refresh_guide'),
                onTap: onOpenGuide,
              ),
              _HelpLink(
                icon: Icons.chat_bubble_outline_rounded,
                label: context.tr('auth_refresh_support'),
                onTap: onOpenContact,
              ),
            ],
          ),
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 64),
                  child: header,
                ),
              ),
              SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [form, help],
                ),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: header,
            ),
            form,
            help,
          ],
        );
      },
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  final bool isLoginTab;
  final bool wide;
  const _AuthBrandHeader({required this.isLoginTab, required this.wide});

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AuthLocketMark(size: 38),
            const SizedBox(width: 10),
            Text(
              context.tr('auth_refresh_brand'),
              style: style
                  .text(size: 20, weight: FontWeight.w600)
                  .copyWith(letterSpacing: -0.6),
            ),
          ],
        ),
        SizedBox(height: wide ? 40 : 22),
        Text(
          context.tr(
            isLoginTab
                ? 'auth_refresh_login_title'
                : 'auth_refresh_register_title',
          ),
          style: style
              .text(size: wide ? 48 : 30, height: 1.13, weight: FontWeight.w600)
              .copyWith(letterSpacing: wide ? -1.8 : -0.9),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr(
            isLoginTab
                ? 'auth_refresh_login_subtitle'
                : 'auth_refresh_register_subtitle',
          ),
          style: style.text(
            size: wide ? 16 : 14,
            color: style.muted,
            height: 1.5,
          ),
        ),
        if (wide) ...[
          const SizedBox(height: 48),
          const ExcludeSemantics(child: _LocketArtwork()),
        ],
      ],
    );
  }
}

class AuthLocketMark extends StatelessWidget {
  final double size;
  const AuthLocketMark({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: style.accentFill,
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(
          Icons.favorite_border_rounded,
          size: size * 0.57,
          color: style.accent,
        ),
      ),
    );
  }
}

class _LocketArtwork extends StatelessWidget {
  const _LocketArtwork();

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return SizedBox(
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 20,
            top: 12,
            child: Transform.rotate(
              angle: -0.13,
              child: _MemoryFrame(
                color: style.lavender,
                fill: style.field,
                icon: Icons.nightlight_outlined,
              ),
            ),
          ),
          Positioned(
            left: 112,
            top: 34,
            child: Transform.rotate(
              angle: 0.11,
              child: _MemoryFrame(
                color: style.accent,
                fill: style.accentFill,
                icon: Icons.favorite_outline_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryFrame extends StatelessWidget {
  final Color color;
  final Color fill;
  final IconData icon;
  const _MemoryFrame({
    required this.color,
    required this.fill,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Container(
      width: 136,
      height: 162,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: style.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Icon(icon, color: color, size: 38)),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 48,
              height: 3,
              decoration: BoxDecoration(
                color: style.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _HelpLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HelpLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: style.muted,
        minimumSize: const Size(48, 48),
        textStyle: style.text(size: 12, weight: FontWeight.w500),
      ),
    );
  }
}
