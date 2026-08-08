import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';

class GlassTextField extends StatefulWidget {
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
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField>
    with SingleTickerProviderStateMixin {
  late final FocusNode _internalFocusNode = widget.focusNode ?? FocusNode();
  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<double> _scaleAnim =
      Tween<double>(begin: 1.0, end: 1.02).animate(
    CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
  );

  @override
  void initState() {
    super.initState();
    _internalFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _internalFocusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    _animCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_internalFocusNode.hasFocus) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: TextField(
        controller: widget.controller,
        focusNode: _internalFocusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onSubmitted: widget.onSubmitted,
        enableSuggestions: widget.enableSuggestions,
        autocorrect: widget.autocorrect,
        style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 16),
        cursorColor: widget.accentColor ?? const Color(0xFFD4956B),
        cursorRadius: const Radius.circular(2),
        cursorWidth: 2.5,
        decoration: SLTheme.authInputDecoration(
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          focusColor: widget.accentColor ?? const Color(0xFFD4956B),
        ),
      ),
    );
  }
}
