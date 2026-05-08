import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../../core/sl_theme.dart';

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF070B14),
              Color(0xFF0E1322),
              Color(0xFF151A2F),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              left: -40,
              child: _blurCircle(
                size: 260,
                color: const Color(0xFFFF4B91).withValues(alpha: 0.26),
              ),
            ),
            Positioned(
              right: -80,
              top: 120,
              child: _blurCircle(
                size: 280,
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.24),
              ),
            ),
            Positioned(
              bottom: -120,
              left: 220,
              child: _blurCircle(
                size: 320,
                color: const Color(0xFF00C896).withValues(alpha: 0.12),
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }

  Widget _blurCircle({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size,
              spreadRadius: size / 4,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminTopBar extends StatelessWidget {
  final firebase_auth.User user;
  final bool isRefreshing;
  final DateTime? lastUpdatedAt;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;
  final String title;

  const AdminTopBar({
    super.key,
    required this.user,
    required this.isRefreshing,
    required this.lastUpdatedAt,
    required this.onRefresh,
    required this.onSignOut,
    this.title = 'SoulLocket Admin',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        return Flex(
          direction: isCompact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment:
              isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SLSpacing.h8,
                  Text(
                    '${user.email ?? 'Admin'} · ${lastUpdatedAt == null ? 'Chưa đồng bộ dữ liệu' : 'Cập nhật ${formatDateTime(lastUpdatedAt!)}'}',
                    style: SLTheme.quicksand(
                      color: const Color(0xFF9AA8C4),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isCompact ? 0 : 16, height: isCompact ? 16 : 0),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: isRefreshing ? null : onRefresh,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF29334D)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.lgAll,
                    ),
                  ),
                  icon: isRefreshing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    'Làm mới',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onSignOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF161E32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.lgAll,
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(
                    'Đăng xuất',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class AdminGlassCard extends StatelessWidget {
  const AdminGlassCard({
    super.key,
    required this.child,
    required this.padding,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC10182A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF222D45)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class AdminTextField extends StatelessWidget {
  const AdminTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: SLTheme.quicksand(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: SLTheme.quicksand(
          color: const Color(0xFF91A1C0),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF91A1C0)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF0D1424),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: SLRadius.lgAll,
          borderSide: const BorderSide(color: Color(0xFF25314A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SLRadius.lgAll,
          borderSide: const BorderSide(color: Color(0xFF25314A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SLRadius.lgAll,
          borderSide: const BorderSide(color: Color(0xFFFF4B91), width: 1.3),
        ),
      ),
    );
  }
}

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AdminGlassCard(
        padding: SLSpacing.all20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: SLRadius.mdAll,
              ),
              child: Icon(icon, color: color),
            ),
            SLSpacing.h16,
            Text(
              title,
              style: SLTheme.quicksand(
                color: const Color(0xFF9AA8C4),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            SLSpacing.h8,
            Text(
              value,
              style: SLTheme.quicksand(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            SLSpacing.h8,
            Text(
              subtitle,
              style: SLTheme.quicksand(
                color: const Color(0xFF6F7E9E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OverviewListTile extends StatelessWidget {
  const OverviewListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: SLRadius.mdAll,
          ),
          child: Icon(icon, color: const Color(0xFFFF4B91)),
        ),
        SLSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SLSpacing.h8,
              Text(
                subtitle,
                style: SLTheme.quicksand(
                  color: const Color(0xFF9AA8C4),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MetaRow extends StatelessWidget {
  const MetaRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SLTheme.quicksand(
            color: const Color(0xFF6F7E9E),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        SLSpacing.h8,
        SelectableText(
          value,
          style: SLTheme.quicksand(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class HighlightChip extends StatelessWidget {
  const HighlightChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141C30),
        borderRadius: SLRadius.pillAll,
        border: Border.all(color: const Color(0xFF26304A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFF4B91)),
          SLSpacing.w8,
          Text(
            label,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Widget sectionTag(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x1AFFFFFF),
      borderRadius: SLRadius.pillAll,
      border: Border.all(color: const Color(0x26FFFFFF)),
    ),
    child: Text(
      text,
      style: SLTheme.quicksand(
        color: const Color(0xFFFFB5CF),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

String formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute · $day/$month/${value.year}';
}
