import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bảng màu riêng của Album/Sự kiện; không thay theme toàn ứng dụng.
class KeepsakeStyle {
  static const rosewood = Color(0xFF864758);
  static const charcoal = Color(0xFF302D34);
  static const champagne = Color(0xFFC9B590);
  static const sage = Color(0xFF60715F);

  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color canvas(BuildContext context) =>
      dark(context) ? const Color(0xFF1D1C20) : const Color(0xFFF6F4F0);
  static Color surface(BuildContext context) =>
      dark(context) ? const Color(0xFF27262B) : const Color(0xFFFFFEFB);
  static Color line(BuildContext context) =>
      dark(context) ? const Color(0xFF434048) : const Color(0xFFE5E1DA);
  static Color ink(BuildContext context) =>
      dark(context) ? const Color(0xFFF0ECE6) : charcoal;
  static Color muted(BuildContext context) =>
      dark(context) ? const Color(0xFFBEB7B8) : const Color(0xFF716D70);
  static Color accent(BuildContext context) =>
      dark(context) ? const Color(0xFFE0AEBB) : rosewood;
  static Color accentSurface(BuildContext context) =>
      dark(context) ? const Color(0xFF3C2E36) : const Color(0xFFF1E8E9);
  static Color button(BuildContext context) =>
      dark(context) ? const Color(0xFFE3D9D3) : charcoal;
  static Color onButton(BuildContext context) =>
      dark(context) ? charcoal : const Color(0xFFFFFEFB);

  static TextStyle text(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => GoogleFonts.beVietnamPro(
    fontSize: size,
    fontWeight: weight,
    height: 1.55,
    color: color ?? ink(context),
    letterSpacing: size >= 22 ? -0.7 : 0,
  );

  static ButtonStyle primary(BuildContext context) => FilledButton.styleFrom(
    backgroundColor: button(context),
    foregroundColor: onButton(context),
    minimumSize: const Size.fromHeight(54),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: text(context, weight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 0,
  );

  static AppBar appBar(
    BuildContext context, {
    required Widget title,
    Widget? leading,
    List<Widget>? actions,
  }) => AppBar(
    backgroundColor: canvas(context),
    foregroundColor: ink(context),
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    elevation: 0,
    centerTitle: false,
    titleSpacing: 4,
    toolbarHeight: 64,
    title: title,
    leading: leading,
    actions: actions,
    titleTextStyle: text(context, size: 16, weight: FontWeight.w600),
    iconTheme: IconThemeData(color: ink(context), size: 21),
    actionsIconTheme: IconThemeData(color: muted(context), size: 21),
  );
}

class KeepsakeHeader extends StatelessWidget {
  const KeepsakeHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.summary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? summary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: KeepsakeStyle.surface(context),
                border: Border.all(color: KeepsakeStyle.line(context)),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: KeepsakeStyle.accent(context), size: 20),
            ),
            if (summary != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary!,
                  style: KeepsakeStyle.text(
                    context,
                    size: 12,
                    color: KeepsakeStyle.muted(context),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: KeepsakeStyle.text(context, size: 28, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: KeepsakeStyle.text(
            context,
            color: KeepsakeStyle.muted(context),
          ),
        ),
      ],
    ),
  );
}

enum KeepsakeKind { album, events }

class KeepsakeEmptyPanel extends StatelessWidget {
  const KeepsakeEmptyPanel({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  final KeepsakeKind kind;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
    decoration: BoxDecoration(
      color: KeepsakeStyle.surface(context),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: KeepsakeStyle.line(context)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            height: 172,
            width: 230,
            child: CustomPaint(
              painter: _KeepsakeIllustration(
                kind: kind,
                paper: KeepsakeStyle.surface(context),
                line: KeepsakeStyle.line(context),
                accent: KeepsakeStyle.accent(context),
                wash: KeepsakeStyle.accentSurface(context),
                isDark: KeepsakeStyle.dark(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: KeepsakeStyle.text(context, size: 19, weight: FontWeight.w600),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: KeepsakeStyle.text(
              context,
              size: 13,
              color: KeepsakeStyle.muted(context),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Minh họa tĩnh bằng canvas; không tải asset/mạng hoặc chạy animation nền.
class _KeepsakeIllustration extends CustomPainter {
  const _KeepsakeIllustration({
    required this.kind,
    required this.paper,
    required this.line,
    required this.accent,
    required this.wash,
    required this.isDark,
  });

  final KeepsakeKind kind;
  final Color paper;
  final Color line;
  final Color accent;
  final Color wash;
  final bool isDark;

  void _heart(Canvas canvas, Offset center, double radius, Color color) {
    final p = Path()
      ..moveTo(center.dx, center.dy + radius)
      ..cubicTo(
        center.dx - radius * 2,
        center.dy - radius * 0.3,
        center.dx - radius * 0.7,
        center.dy - radius * 1.6,
        center.dx,
        center.dy - radius * 0.65,
      )
      ..cubicTo(
        center.dx + radius * 0.7,
        center.dy - radius * 1.6,
        center.dx + radius * 2,
        center.dy - radius * 0.3,
        center.dx,
        center.dy + radius,
      )
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 230, size.height / 172);
    final fill = Paint()..color = wash;
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(const Offset(114, 86), 72, fill);
    canvas.drawArc(
      const Rect.fromLTWH(27, 5, 174, 163),
      math.pi * 1.06,
      math.pi * 0.62,
      false,
      stroke,
    );
    canvas.drawCircle(
      const Offset(30, 117),
      4,
      Paint()..color = KeepsakeStyle.champagne,
    );
    canvas.drawCircle(const Offset(193, 48), 3, Paint()..color = accent);
    canvas.save();
    canvas.translate(116, 85);
    canvas.rotate(-0.10);
    final back = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-49, -54, 112, 126),
      const Radius.circular(12),
    );
    canvas.drawRRect(back, Paint()..color = line);
    canvas.drawRRect(back, stroke);
    canvas.rotate(0.13);
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-60, -65, 112, 126),
      const Radius.circular(12),
    );
    canvas.drawRRect(card, Paint()..color = paper);
    canvas.drawRRect(card, stroke);
    if (kind == KeepsakeKind.events) {
      canvas.drawLine(const Offset(-60, -31), const Offset(52, -31), stroke);
      final ring = Paint()
        ..color = accent
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-34, -71), const Offset(-34, -56), ring);
      canvas.drawLine(const Offset(25, -71), const Offset(25, -56), ring);
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 4; col++) {
          final position = Offset(-36 + col * 21, -9 + row * 21);
          if (row == 1 && col == 2) {
            _heart(canvas, position, 7, accent);
          } else {
            canvas.drawCircle(position, 2.5, Paint()..color = line);
          }
        }
      }
    } else {
      final image = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-50, -55, 92, 85),
        const Radius.circular(5),
      );
      canvas.drawRRect(image, fill);
      canvas.save();
      canvas.clipRRect(image);
      final hills = Path()
        ..moveTo(-53, 27)
        ..lineTo(-26, -6)
        ..lineTo(-7, 12)
        ..lineTo(12, -10)
        ..lineTo(46, 27)
        ..close();
      canvas.drawPath(hills, Paint()..color = accent.withValues(alpha: 0.34));
      canvas.drawCircle(
        const Offset(18, -31),
        9,
        Paint()..color = KeepsakeStyle.champagne,
      );
      canvas.restore();
      canvas.drawLine(const Offset(-40, 44), const Offset(16, 44), stroke);
      _heart(canvas, const Offset(33, 44), 5, accent);
    }
    canvas.restore();
    final seal = Paint()
      ..color = isDark ? const Color(0xFF4B4032) : const Color(0xFFEEE5D5);
    canvas.drawCircle(const Offset(173, 132), 18, seal);
    _heart(canvas, const Offset(173, 132), 7, accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KeepsakeIllustration oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.paper != paper ||
      oldDelegate.line != line ||
      oldDelegate.accent != accent ||
      oldDelegate.wash != wash ||
      oldDelegate.isDark != isDark;
}

class KeepsakeStorageNote extends StatelessWidget {
  const KeepsakeStorageNote({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.phone_android_outlined,
          size: 17,
          color: KeepsakeStyle.muted(context),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: KeepsakeStyle.text(
              context,
              size: 12,
              color: KeepsakeStyle.muted(context),
            ),
          ),
        ),
      ],
    ),
  );
}

class KeepsakeActionBar extends StatelessWidget {
  const KeepsakeActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: KeepsakeStyle.canvas(context),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                label: Text(label, textAlign: TextAlign.center),
                style: KeepsakeStyle.primary(context),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class KeepsakeMediaTile extends StatelessWidget {
  const KeepsakeMediaTile({
    super.key,
    required this.child,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
    this.badge,
  });
  final Widget child;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;
  final String? badge;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Material(
      color: KeepsakeStyle.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? KeepsakeStyle.accent(context)
              : KeepsakeStyle.line(context),
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (selecting)
                  ColoredBox(
                    color: selected ? Colors.black26 : Colors.transparent,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                if (badge != null && !selecting)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: KeepsakeStyle.charcoal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: KeepsakeStyle.text(
                          context,
                          size: 11,
                          color: Colors.white,
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
}
