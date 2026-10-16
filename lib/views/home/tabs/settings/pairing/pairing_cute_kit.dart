import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/widgets/couple_default_avatar.dart';

/// Bộ giao diện dùng chung cho các hộp ghép nối (ghép nhanh, tạo mã, nhập mã):
/// hộp nổi giữa màn hình, bo góc, tông hồng phấn – kem, chữ màu mận.
abstract final class PairingCutePalette {
  static const blush = Color(0xFFFFEEF3);
  static const cream = Color(0xFFFFFBF6);
  static const petal = Color(0xFFFFD9E4);
  static const line = Color(0xFFF2C4D2);
  static const heart = Color(0xFFEE7C9C);
  static const rose = Color(0xFFCC3D66);
  static const roseDeep = Color(0xFFA82A4B);
  static const plum = Color(0xFF4A2638);
  static const plumSoft = Color(0xFF7A5868);
  static const hint = Color(0xFFC3A7B3);
  static const lilac = Color(0xFFF5EEFB);
  static const violet = Color(0xFF8A62C2);
  static const mint = Color(0xFFE5F4EC);
  static const mintDeep = Color(0xFF237750);
}

/// Mở một hộp ghép nối nổi giữa màn hình (nền tối mờ, phóng nhẹ khi hiện).
/// Chạm ra ngoài hoặc nút Quay lại để đóng, trừ khi hộp chặn bằng `canPop`.
Future<T?> showPairingCuteDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x8C2A1420),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Khung thẻ nổi: tối đa 400dp, lề 16dp, bo 32, tránh bàn phím, cuộn khi dài.
class PairingCuteDialogFrame extends StatelessWidget {
  const PairingCuteDialogFrame({
    super.key,
    required this.child,
    required this.closeTooltip,
    required this.onClose,
    this.showClose = true,
    this.canPop = true,
    this.cardKey,
  });

  final Widget child;
  final String closeTooltip;

  /// null thì nút đóng mờ đi (đang xử lý).
  final VoidCallback? onClose;
  final bool showClose;
  final bool canPop;
  final Key? cardKey;

  static const _radius = BorderRadius.all(Radius.circular(32));

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: canPop,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  type: MaterialType.transparency,
                  child: DecoratedBox(
                    key: cardKey,
                    decoration: BoxDecoration(
                      borderRadius: _radius,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          PairingCutePalette.blush,
                          PairingCutePalette.cream,
                        ],
                        stops: [0, 0.45],
                      ),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40A82A4B),
                          blurRadius: 36,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: _radius,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _PairingBackdropPainter(),
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                            child: child,
                          ),
                          if (showClose)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: IconButton(
                                tooltip: closeTooltip,
                                onPressed: onClose,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.86,
                                  ),
                                  disabledBackgroundColor: Colors.white
                                      .withValues(alpha: 0.6),
                                ),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: PairingCutePalette.plumSoft,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Đầu hộp: hình minh họa, tiêu đề và mô tả căn giữa.
class PairingCuteHeader extends StatelessWidget {
  const PairingCuteHeader({
    super.key,
    required this.badge,
    required this.title,
    this.subtitle,
  });

  final Widget badge;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        badge,
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            color: PairingCutePalette.plum,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: PairingCutePalette.plumSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

/// Hai bé chibi mặc định của app nối với nhau bằng một biểu tượng tròn.
class PairingCoupleHeartBadge extends StatelessWidget {
  const PairingCoupleHeartBadge({
    super.key,
    required this.size,
    this.together = false,
    this.centerIcon = Icons.favorite_rounded,
  });

  final double size;

  /// Lúc ghép xong hai bé đứng sát nhau hơn.
  final bool together;
  final IconData centerIcon;

  @override
  Widget build(BuildContext context) {
    final heartSize = size * 0.5;
    final overlap = size * (together ? 0.3 : 0.16);
    final width = size * 2 + heartSize - overlap * 2;
    Widget avatar(bool female) => Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x29A82A4B),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(child: CoupleDefaultAvatar(female: female)),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: size,
        child: Stack(
          children: [
            Positioned(left: 0, top: 0, child: avatar(false)),
            Positioned(right: 0, top: 0, child: avatar(true)),
            Positioned(
              left: (width - heartSize) / 2,
              top: (size - heartSize) / 2,
              child: Container(
                width: heartSize,
                height: heartSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PairingCutePalette.heart, PairingCutePalette.rose],
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: Icon(
                  centerIcon,
                  color: Colors.white,
                  size: heartSize * 0.52,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn nhỏ dạng viên thuốc (vd. "Mã của bạn").
class PairingCuteTag extends StatelessWidget {
  const PairingCuteTag({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: PairingCutePalette.blush,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PairingCutePalette.rose),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: SLTheme.quicksand(
                color: PairingCutePalette.roseDeep,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Viên nhỏ hiển thị thời gian (đổi mã/còn hiệu lực).
class PairingCuteTimerPill extends StatelessWidget {
  const PairingCuteTimerPill({
    super.key,
    required this.text,
    this.icon = Icons.autorenew_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: PairingCutePalette.blush,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: PairingCutePalette.roseDeep, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: SLTheme.quicksand(
                  color: PairingCutePalette.roseDeep,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ "vé": nền trắng, viền đứt nét hồng, bo 24.
class PairingCuteTicket extends StatelessWidget {
  const PairingCuteTicket({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 6, 6, 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const PairingDashedBorderPainter(
        color: PairingCutePalette.line,
        radius: 24,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      ),
    );
  }
}

/// Mã QR chấm tròn trong khung trắng viền hồng.
class PairingCuteQr extends StatelessWidget {
  const PairingCuteQr({
    super.key,
    required this.data,
    required this.semanticsLabel,
    this.size = 176,
  });

  final String data;
  final String semanticsLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: PairingCutePalette.line, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size,
            padding: const EdgeInsets.all(8),
            backgroundColor: Colors.white,
            semanticsLabel: semanticsLabel,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.circle,
              color: PairingCutePalette.roseDeep,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.circle,
              color: PairingCutePalette.plum,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghi chú nền tím nhạt có biểu tượng nhỏ.
class PairingCuteNote extends StatelessWidget {
  const PairingCuteNote({
    super.key,
    required this.message,
    this.icon = Icons.tips_and_updates_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: PairingCutePalette.lilac,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: PairingCutePalette.violet),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: SLTheme.quicksand(
                color: PairingCutePalette.plumSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô nhập mã 12 số: chữ to căn giữa, bo 20, viền hồng.
class PairingCuteCodeField extends StatelessWidget {
  const PairingCuteCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.inputFormatters,
    this.fieldKey,
    this.readOnly = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final List<TextInputFormatter> inputFormatters;
  final Key? fieldKey;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: PairingCutePalette.line, width: 1.4),
    );
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      textAlign: TextAlign.center,
      cursorColor: PairingCutePalette.rose,
      style: SLTheme.quicksand(
        color: PairingCutePalette.plum,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: SLTheme.quicksand(
          color: PairingCutePalette.hint,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.8,
        ),
        semanticCounterText: '',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(
            color: PairingCutePalette.rose,
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// Nút phụ dạng chip bo tròn (Dán mã, Quét QR).
class PairingCuteChip extends StatelessWidget {
  const PairingCuteChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: PairingCutePalette.roseDeep,
        backgroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(
          side: BorderSide(color: PairingCutePalette.line, width: 1.2),
        ),
        textStyle: SLTheme.quicksand(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Lựa chọn dạng viên (vd. thời hạn mã); chọn thì nền hồng đậm chữ trắng.
class PairingCuteChoicePill extends StatelessWidget {
  const PairingCuteChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(999));
    return Semantics(
      button: true,
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      PairingCutePalette.rose,
                      PairingCutePalette.roseDeep,
                    ],
                  )
                : null,
            color: selected ? null : Colors.white,
            border: selected
                ? null
                : Border.all(color: PairingCutePalette.line, width: 1.2),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: selected
                          ? Colors.white
                          : PairingCutePalette.plumSoft,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút bo tròn hai kiểu: nền hồng đậm (chính) hoặc nền hồng phấn (phụ).
class PairingCutePillButton extends StatelessWidget {
  const PairingCutePillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = true,
    this.loading = false,
    this.height = 48,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    const radius = BorderRadius.all(Radius.circular(999));
    final foreground = filled ? Colors.white : PairingCutePalette.roseDeep;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: filled
              ? LinearGradient(
                  colors: enabled || loading
                      ? const [
                          PairingCutePalette.rose,
                          PairingCutePalette.roseDeep,
                        ]
                      : const [Color(0xFFE2A6B8), Color(0xFFD493A7)],
                )
              : null,
          color: filled ? null : PairingCutePalette.blush,
          border: filled
              ? null
              : Border.all(color: PairingCutePalette.line, width: 1.2),
          boxShadow: filled && enabled
              ? const [
                  BoxShadow(
                    color: Color(0x40A82A4B),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Center(
                widthFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: foreground,
                        ),
                      )
                    else
                      Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          color: foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Khối trạng thái (đang chờ, đang kết nối, bị từ chối, thành công).
class PairingCuteStatusPanel extends StatelessWidget {
  const PairingCuteStatusPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.footer,
    this.iconColor = PairingCutePalette.rose,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget footer;

  /// Thay biểu tượng tròn bằng hình minh họa riêng (vd. hai bé lúc ghép xong).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
      child: Column(
        children: [
          badge ??
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.25),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x29A82A4B),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: PairingCutePalette.plum,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              color: PairingCutePalette.plumSoft,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          footer,
        ],
      ),
    );
  }
}

/// Viền đứt nét bo góc cho thẻ mã.
class PairingDashedBorderPainter extends CustomPainter {
  const PairingDashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 12) {
        canvas.drawPath(metric.extractPath(distance, distance + 6.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(PairingDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Nền trang trí tĩnh: vài đốm màu và trái tim nhỏ ở phần đầu thẻ.
class _PairingBackdropPainter extends CustomPainter {
  const _PairingBackdropPainter();

  static const _hearts = <(double, double, double)>[
    (0.16, 92.0, 8.0),
    (0.82, 24.0, 6.5),
    (0.9, 118.0, 10.0),
    (0.07, 150.0, 5.5),
    (0.7, 156.0, 5.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final blob = Paint()..color = const Color(0x8CFFD6E2);
    canvas.drawCircle(Offset(size.width * 0.06, 10), 72, blob);
    blob.color = const Color(0xB3EEE3FA);
    canvas.drawCircle(Offset(size.width * 0.98, 64), 56, blob);
    final heart = Paint()..color = const Color(0x59EE7C9C);
    for (final (dx, dy, scale) in _hearts) {
      _drawHeart(canvas, Offset(size.width * dx, dy), scale, heart);
    }
  }

  static void _drawHeart(Canvas canvas, Offset c, double s, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.9)
      ..cubicTo(
        c.dx - s * 1.6,
        c.dy - s * 0.1,
        c.dx - s * 0.7,
        c.dy - s * 1.3,
        c.dx,
        c.dy - s * 0.45,
      )
      ..cubicTo(
        c.dx + s * 0.7,
        c.dy - s * 1.3,
        c.dx + s * 1.6,
        c.dy - s * 0.1,
        c.dx,
        c.dy + s * 0.9,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PairingBackdropPainter oldDelegate) => false;
}
