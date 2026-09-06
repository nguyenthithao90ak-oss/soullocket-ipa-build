import 'package:flutter/material.dart';
import 'auth_visual_style.dart';

/// Ô nhập dùng chung cho màn xác thực.
class AuroraTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enableSuggestions;
  final bool autocorrect;
  final bool isPassword;
  final TextCapitalization textCapitalization;

  const AuroraTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.focusNode,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.isPassword = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<AuroraTextField> createState() => _AuroraTextFieldState();
}

class _AuroraTextFieldState extends State<AuroraTextField> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AuroraTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    final focused = _focusNode.hasFocus;
    final radius = BorderRadius.circular(14);
    return Semantics(
      label: widget.labelText,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: style.accent.withValues(alpha: 0.08),
                    spreadRadius: 3,
                  ),
                ]
              : const [],
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          textCapitalization: widget.textCapitalization,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onSubmitted: widget.onSubmitted,
          enableSuggestions: widget.enableSuggestions,
          autocorrect: widget.autocorrect,
          style: style.text(size: 15, height: 1.35),
          cursorColor: style.accent,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: style.text(size: 14, color: style.muted),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.all(9),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: style.accentFill,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconTheme(
                        data: IconThemeData(size: 20, color: style.accent),
                        child: widget.prefixIcon!,
                      ),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 52,
            ),
            suffixIcon: widget.suffixIcon,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            filled: true,
            fillColor: focused ? style.surface : style.field,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(borderRadius: radius),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: style.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: style.accent, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Giữ nguyên callback kiểm tra dữ liệu của hai luồng xác thực.
class AuroraPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onDisabledTap;
  final bool isLoading;
  final bool enabled;
  final IconData icon;

  const AuroraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onDisabledTap,
    this.isLoading = false,
    this.enabled = true,
    this.icon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    final action = isLoading
        ? null
        : enabled
        ? onPressed
        : onDisabledTap;
    final active = enabled && !isLoading && onPressed != null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: action,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          backgroundColor: active ? style.button : style.accentFill,
          foregroundColor: active ? Colors.white : style.accent,
          disabledBackgroundColor: style.accentFill,
          disabledForegroundColor: style.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: style.text(size: 15, weight: FontWeight.w600),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: style.accent,
                ),
              )
            : Row(
                children: [
                  Expanded(child: Text(label, textAlign: TextAlign.center)),
                  const SizedBox(width: 8),
                  Icon(icon, size: 19),
                ],
              ),
      ),
    );
  }
}
