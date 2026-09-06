import 'package:flutter/material.dart';

/// Bảng màu riêng cho xác thực, dùng chung ở cả hai phiên bản giao diện.
class AuthVisualStyle {
  final bool dark;

  const AuthVisualStyle({required this.dark});

  factory AuthVisualStyle.of(BuildContext context) =>
      AuthVisualStyle(dark: Theme.of(context).brightness == Brightness.dark);

  Color get background =>
      dark ? const Color(0xFF19171C) : const Color(0xFFFAF8F6);
  Color get surface => dark ? const Color(0xFF242127) : Colors.white;
  Color get field => dark ? const Color(0xFF2C2830) : const Color(0xFFFAF9F8);
  Color get ink => dark ? const Color(0xFFF5EFF3) : const Color(0xFF29252D);
  Color get muted => dark ? const Color(0xFFBBB1BC) : const Color(0xFF726975);
  Color get accent => dark ? const Color(0xFFEEAAC0) : const Color(0xFFAD3D60);
  Color get accentFill =>
      dark ? const Color(0xFF583243) : const Color(0xFFF7E9EE);
  Color get border => dark ? const Color(0xFF443C47) : const Color(0xFFE8E1E5);
  Color get lavender =>
      dark ? const Color(0xFFBFB0DD) : const Color(0xFF8070AC);
  Color get button => const Color(0xFFAD3D60);

  TextStyle text({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.4,
  }) => TextStyle(
    fontFamily: 'Roboto',
    fontSize: size,
    fontWeight: weight,
    color: color ?? ink,
    height: height,
  );
}

class AuthSectionLabel extends StatelessWidget {
  final String label;
  const AuthSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: AuthVisualStyle.of(context).text(size: 13, weight: FontWeight.w600),
  );
}

class AuthSocialDivider extends StatelessWidget {
  final String label;
  const AuthSocialDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: style.border)),
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: style.text(size: 12, color: style.muted),
            ),
          ),
        ),
        Expanded(child: Divider(color: style.border)),
      ],
    );
  }
}
