// lib/views/home/tabs/settings/theme/theme_preview_builder.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// 🎨 PHASE 3 — Theme Preview Screen (Aurora Soft)
// ══════════════════════════════════════════════════════════════════════════════
//
// Mục đích: Preview tất cả Aurora Soft components trong một màn hình.
// Dùng cho designer QA và user xem trước theme trước khi apply.
//
// Cách kết nối:
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (_) => const AuroraThemePreviewScreen(),
//     ),
//   );
//
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/widgets/sl_toast.dart';

class AuroraThemePreviewScreen extends StatefulWidget {
  const AuroraThemePreviewScreen({super.key});

  @override
  State<AuroraThemePreviewScreen> createState() =>
      _AuroraThemePreviewScreenState();
}

class _AuroraThemePreviewScreenState extends State<AuroraThemePreviewScreen> {
  bool _isDark = false;
  String _fontKey = 'plusJakarta';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark
          ? const Color(0xFF1A1625)
          : const Color(0xFFFFF8FA),
      appBar: AppBar(
        title: Text(
          context.tr('p7_aurora_preview_title'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: _isDark ? Colors.white : const Color(0xFF4A3040),
          ),
        ),
        backgroundColor: _isDark
            ? const Color(0xFF1A1625)
            : Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        actions: [
          // Light/Dark toggle
          IconButton(
            tooltip: context.tr('p7_toggle_color_mode'),
            icon: Icon(
              _isDark ? Icons.light_mode : Icons.dark_mode,
              color: _isDark ? Colors.white : const Color(0xFF4A3040),
            ),
            onPressed: () => setState(() => _isDark = !_isDark),
          ),
          // Font toggle
          IconButton(
            tooltip: context.tr('p7_toggle_preview_font'),
            icon: Text(
              'Aa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _isDark ? Colors.white : const Color(0xFF4A3040),
              ),
            ),
            onPressed: () => setState(() {
              _fontKey = _fontKey == 'plusJakarta'
                  ? 'quicksand'
                  : 'plusJakarta';
            }),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 720 ? 32.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              40,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────────────
                    _SectionTitle(
                      title: context.tr('p7_preview_section_palette'),
                      isDark: _isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildColorSwatches(),
                    const SizedBox(height: 32),

                    // ── Buttons ──────────────────────────────────────────────────────
                    _SectionTitle(
                      title: context.tr('p7_preview_section_buttons'),
                      isDark: _isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildButtonShowcase(),
                    const SizedBox(height: 32),

                    // ── Cards ───────────────────────────────────────────────────────
                    _SectionTitle(
                      title: context.tr('p7_preview_section_cards'),
                      isDark: _isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildCardShowcase(),
                    const SizedBox(height: 32),

                    // ── Inputs ──────────────────────────────────────────────────────
                    _SectionTitle(
                      title: context.tr('p7_preview_section_inputs'),
                      isDark: _isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildInputShowcase(),
                    const SizedBox(height: 32),

                    // ── Chat Bubbles ───────────────────────────────────────────────
                    _SectionTitle(
                      title: context.tr('p7_preview_section_chat'),
                      isDark: _isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildChatBubbleShowcase(),
                    const SizedBox(height: 32),

                    // ── Aurora Gradients ───────────────────────────────────────────
                    _SectionTitle(
                      title: context.tr('p7_preview_section_gradients'),
                      isDark: _isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildGradientShowcase(),
                    const SizedBox(height: 32),

                    // ── Toasts & Dialogs (NEW) ────────────────────────────────────
                    _SectionTitle(
                      title: context.tr('p7_preview_section_feedback'),
                      isDark: _isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildToastShowcase(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToastShowcase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('p7_preview_feedback_description'),
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _isDark ? Colors.white60 : const Color(0xFF6D5A6D),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),

        // ── Snackbar variants ──
        Text(
          context.tr('p7_preview_snackbar'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: _isDark ? Colors.white38 : const Color(0xFF8E7B8E),
          ),
        ),
        const SizedBox(height: 10),
        _buildToastDemoButton(
          context.tr('p7_preview_success'),
          Icons.check_circle_rounded,
          const Color(0xFF00C853),
          () =>
              SLToast.success(context, context.tr('p7_preview_logout_success')),
        ),
        const SizedBox(height: 8),
        _buildToastDemoButton(
          context.tr('p7_preview_error'),
          Icons.error_rounded,
          const Color(0xFFFF5252),
          () => SLToast.error(context, context.tr('p7_preview_network_error')),
        ),
        const SizedBox(height: 8),
        _buildToastDemoButton(
          context.tr('p7_preview_warning'),
          Icons.warning_amber_rounded,
          const Color(0xFFFFAB00),
          () => SLToast.warning(context, context.tr('p7_preview_daily_limit')),
        ),
        const SizedBox(height: 8),
        _buildToastDemoButton(
          context.tr('p7_preview_information'),
          Icons.info_rounded,
          const Color(0xFF2979FF),
          () =>
              SLToast.info(context, context.tr('p7_preview_encrypted_message')),
        ),
        const SizedBox(height: 8),
        _buildToastDemoButton(
          context.tr('p7_preview_default_with_action'),
          Icons.favorite_rounded,
          const Color(0xFFFF4B91),
          () => SLToast.show(
            context,
            context.tr('p7_preview_pending_uploads'),
            variant: SLToastVariant.warning,
            actionLabel: context.tr('p7_retry'),
            onAction: () {
              SLToast.info(context, context.tr('p7_preview_retrying'));
            },
          ),
        ),
        const SizedBox(height: 20),

        // ── Dialog variants ──
        Text(
          context.tr('p7_preview_confirmation_dialogs'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: _isDark ? Colors.white38 : const Color(0xFF8E7B8E),
          ),
        ),
        const SizedBox(height: 10),
        _buildToastDemoButton(
          context.tr('p7_preview_logout_warning'),
          Icons.logout_rounded,
          const Color(0xFFFFAB00),
          () async {
            final ok = await SLToast.confirm(
              context,
              title: context.tr('p7_preview_logout_question'),
              message: context.tr('p7_preview_logout_message'),
              confirmLabel: context.tr('p7_preview_logout_action'),
              variant: SLToastVariant.warning,
            );
            if (ok && mounted) {
              SLToast.success(context, context.tr('p7_preview_logout_success'));
            }
          },
        ),
        const SizedBox(height: 8),
        _buildToastDemoButton(
          context.tr('p7_preview_delete_danger'),
          Icons.delete_forever_rounded,
          const Color(0xFFFF5252),
          () async {
            final ok = await SLToast.confirm(
              context,
              title: context.tr('p7_preview_delete_all_question'),
              message: context.tr('p7_preview_delete_all_message'),
              confirmLabel: context.tr('p7_preview_delete_permanently'),
              variant: SLToastVariant.danger,
            );
            if (ok && mounted) {
              SLToast.error(context, context.tr('p7_preview_deleted_all'));
            }
          },
        ),
        const SizedBox(height: 8),
        _buildToastDemoButton(
          context.tr('p7_preview_upgrade_primary'),
          Icons.star_rounded,
          const Color(0xFFFF4B91),
          () async {
            final ok = await SLToast.confirm(
              context,
              title: context.tr('p7_preview_upgrade_question'),
              message: context.tr('p7_preview_upgrade_message'),
              confirmLabel: context.tr('p7_preview_upgrade_action'),
              variant: SLToastVariant.primary,
            );
            if (ok && mounted) {
              SLToast.success(
                context,
                context.tr('p7_preview_upgrade_success'),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        _buildToastDemoButton(
          context.tr('p7_preview_alert_info'),
          Icons.notifications_active_rounded,
          const Color(0xFF2979FF),
          () => SLToast.alert(
            context,
            title: context.tr('p7_preview_update_success'),
            message: context.tr('p7_preview_update_installed'),
          ),
        ),
      ],
    );
  }

  Widget _buildToastDemoButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: _isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: _isDark ? Colors.white38 : const Color(0xFF9A8A9A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSwatches() {
    final colors = [
      (context.tr('p7_preview_color_rose_deep'), const Color(0xFFFF6B9D)),
      (context.tr('p7_preview_color_rose_mid'), const Color(0xFFFF8FB1)),
      (context.tr('p7_preview_color_lavender'), const Color(0xFFB19CD9)),
      (context.tr('p7_preview_color_lavender_deep'), const Color(0xFF7B68B6)),
      (context.tr('p7_preview_color_peach'), const Color(0xFFFFAB91)),
      (context.tr('p7_preview_color_mint'), const Color(0xFF80CBC4)),
      (context.tr('p7_preview_color_gold'), const Color(0xFFFFB74D)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((c) {
        return Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.$2,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: c.$2.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              c.$1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _isDark ? Colors.white70 : const Color(0xFF4A3040),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildButtonShowcase() {
    final buttons = [
      (context.tr('p7_preview_button_primary'), 'primary'),
      (context.tr('p7_preview_button_secondary'), 'secondary'),
      (context.tr('p7_preview_button_ghost'), 'ghost'),
      (context.tr('p7_preview_button_premium'), 'premium'),
      (context.tr('p7_preview_button_destructive'), 'destructive'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: buttons
              .map(
                (button) => SizedBox(
                  width: itemWidth,
                  child: _AuroraPreviewButton(
                    label: button.$1,
                    variant: button.$2,
                    isDark: _isDark,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildCardShowcase() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumns = constraints.maxWidth >= 520;
        final itemWidth = useColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _AuroraPreviewCard(
                title: context.tr('p7_preview_highlight_card'),
                subtitle: context.tr('p7_preview_special_moment'),
                icon: Icons.favorite_rounded,
                variant: 'highlight',
                isDark: _isDark,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _AuroraPreviewCard(
                title: context.tr('p7_preview_insight_card'),
                subtitle: context.tr('p7_preview_love_statistics'),
                icon: Icons.insights_rounded,
                variant: 'insight',
                isDark: _isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputShowcase() {
    return Column(
      children: [
        _AuroraPreviewInput(
          hint: context.tr('p7_preview_email_address'),
          icon: Icons.email_outlined,
          isDark: _isDark,
        ),
        const SizedBox(height: 12),
        _AuroraPreviewInput(
          hint: context.tr('p7_preview_password'),
          icon: Icons.lock_outlined,
          isDark: _isDark,
          obscure: true,
        ),
      ],
    );
  }

  Widget _buildChatBubbleShowcase() {
    return Column(
      children: [
        // Sent bubble
        Align(
          alignment: Alignment.centerRight,
          child: _AuroraChatBubble(
            text: context.tr('p7_preview_chat_sent'),
            isFromMe: true,
            isDark: _isDark,
          ),
        ),
        const SizedBox(height: 8),
        // Received bubble
        Align(
          alignment: Alignment.centerLeft,
          child: _AuroraChatBubble(
            text: context.tr('p7_preview_chat_received'),
            isFromMe: false,
            isDark: _isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildGradientShowcase() {
    final gradients = [
      (
        context.tr('p7_preview_gradient_rose_dawn'),
        [
          const Color(0xFFFF6B9D),
          const Color(0xFFFF8FB1),
          const Color(0xFFB19CD9),
        ],
      ),
      (
        context.tr('p7_preview_gradient_lavender_dusk'),
        [
          const Color(0xFF7B68B6),
          const Color(0xFFB19CD9),
          const Color(0xFFFF8FB1),
        ],
      ),
      (
        context.tr('p7_preview_gradient_peach_sunset'),
        [
          const Color(0xFFFFAB91),
          const Color(0xFFFF8FB1),
          const Color(0xFFFF6B9D),
        ],
      ),
      (
        context.tr('p7_preview_gradient_mint_bloom'),
        [
          const Color(0xFF80CBC4),
          const Color(0xFFB19CD9),
          const Color(0xFF7B68B6),
        ],
      ),
    ];

    return Column(
      children: gradients.map((g) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: g.$2,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: g.$2.first.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                g.$1,
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Preview Widgets ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: SLTheme.quicksand(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : const Color(0xFF4A3040),
      ),
    );
  }
}

class _AuroraPreviewButton extends StatelessWidget {
  final String label;
  final String variant;
  final bool isDark;

  const _AuroraPreviewButton({
    required this.label,
    required this.variant,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (variant) {
      case 'primary':
        bgColor = const Color(0xFFFF6B9D);
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case 'secondary':
        bgColor = Colors.transparent;
        textColor = const Color(0xFFFF6B9D);
        borderColor = const Color(0xFFFF6B9D);
        break;
      case 'ghost':
        bgColor = Colors.transparent;
        textColor = isDark ? Colors.white70 : const Color(0xFF6B5B6B);
        borderColor = Colors.transparent;
        break;
      case 'premium':
        bgColor = const Color(0xFFFFB74D);
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case 'destructive':
        bgColor = const Color(0xFFEF5350);
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      default:
        bgColor = const Color(0xFFFF6B9D);
        textColor = Colors.white;
        borderColor = Colors.transparent;
    }

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != Colors.transparent
            ? Border.all(color: borderColor, width: 1.5)
            : null,
        boxShadow: variant == 'primary' || variant == 'premium'
            ? [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: SLTheme.quicksand(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AuroraPreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String variant;
  final bool isDark;

  const _AuroraPreviewCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.variant,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientColors;
    if (variant == 'highlight') {
      gradientColors = [const Color(0xFFFF6B9D), const Color(0xFFB19CD9)];
    } else {
      gradientColors = [const Color(0xFF80CBC4), const Color(0xFFB19CD9)];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2640) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFFFD9E6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : gradientColors.first).withValues(
              alpha: 0.1,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF4A3040),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF8A7A8A),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraPreviewInput extends StatefulWidget {
  final String hint;
  final IconData icon;
  final bool isDark;
  final bool obscure;

  const _AuroraPreviewInput({
    required this.hint,
    required this.icon,
    required this.isDark,
    this.obscure = false,
  });

  @override
  State<_AuroraPreviewInput> createState() => _AuroraPreviewInputState();
}

class _AuroraPreviewInputState extends State<_AuroraPreviewInput> {
  final _controller = TextEditingController();
  bool _focused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF2D2640) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focused
                ? const Color(0xFFFF6B9D)
                : (widget.isDark ? Colors.white12 : const Color(0xFFFFD9E6)),
            width: _focused ? 2 : 1,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF6B9D).withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              widget.icon,
              color: _focused
                  ? const Color(0xFFFF6B9D)
                  : (widget.isDark ? Colors.white38 : const Color(0xFF9A8A9A)),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                obscureText: widget.obscure,
                style: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : const Color(0xFF4A3040),
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? Colors.white38
                        : const Color(0xFF9A8A9A),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _AuroraChatBubble extends StatelessWidget {
  final String text;
  final bool isFromMe;
  final bool isDark;

  const _AuroraChatBubble({
    required this.text,
    required this.isFromMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isFromMe) {
      return Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.68,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B9D), Color(0xFFB19CD9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B9D).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.68,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2640) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(22),
        ),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: SLTheme.quicksand(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
