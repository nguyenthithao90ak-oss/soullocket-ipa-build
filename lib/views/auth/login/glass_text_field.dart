import 'package:flutter/material.dart';

import 'aurora_form_widgets.dart';

/// Legacy API adapter. Keeps the old form logic untouched while rendering the
/// new soft Locket Garden field.
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final Color? accentColor;
  final bool enableSuggestions;
  final bool autocorrect;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.focusNode,
    this.accentColor,
    this.enableSuggestions = true,
    this.autocorrect = true,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraTextField(
      controller: controller,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
      isPassword: obscureText,
    );
  }
}
