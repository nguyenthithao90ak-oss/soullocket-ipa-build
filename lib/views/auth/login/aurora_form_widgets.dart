import 'package:flutter/material.dart';
import 'package:soullocket_app/core/theme/design_tokens.dart';

/// Aurora-styled floating label input field.
/// Glass white background với Aurora border khi focus.
class AuroraTextField extends StatefulWidget {
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
  final bool enableSuggestions;
  final bool autocorrect;
  final bool isPassword;

  const AuroraTextField({
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
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.isPassword = false,
  });

  @override
  State<AuroraTextField> createState() => _AuroraTextFieldState();
}

class _AuroraTextFieldState extends State<AuroraTextField>
    with SingleTickerProviderStateMixin {
  late final FocusNode _internalFocusNode;
  late final AnimationController _borderAnimCtrl;
  late final Animation<double> _borderAnim;

  bool get _isFocused => _internalFocusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
    _internalFocusNode.addListener(_onFocusChange);
    _borderAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _borderAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _borderAnimCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _internalFocusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    _borderAnimCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
    if (_isFocused) {
      _borderAnimCtrl.forward();
    } else {
      _borderAnimCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _borderAnim,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B9D).withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
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
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              color: const Color(0xFF2F3441),
            ),
            cursorColor: SLAuroraPalette.roseDeep,
            cursorRadius: const Radius.circular(2),
            cursorWidth: 2.5,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 15.5,
                color: const Color(0xFF667085).withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.75),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: const Color(0xFFFFD6E0).withValues(alpha: 0.7),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: SLAuroraPalette.roseDeep.withValues(alpha: 0.8 + _borderAnim.value * 0.2),
                  width: 1.6,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: SLSemanticTokens.danger,
                  width: 1.2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: SLSemanticTokens.danger,
                  width: 1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Aurora primary button với gradient và press animation.
class AuroraPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;

  const AuroraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  State<AuroraPrimaryButton> createState() => _AuroraPrimaryButtonState();
}

class _AuroraPrimaryButtonState extends State<AuroraPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool get _isDisabled => widget.onPressed == null || widget.isLoading || !widget.enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isDisabled ? null : (_) => _pressCtrl.forward(),
      onTapUp: _isDisabled
          ? null
          : (_) {
              _pressCtrl.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: _isDisabled ? null : () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressAnim,
        child: Opacity(
          opacity: _isDisabled ? 0.65 : 1.0,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: _isDisabled
                  ? const LinearGradient(
                      colors: [Color(0xFFFFD6E0), Color(0xFFFFC2D1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        SLAuroraPalette.roseDeep, // rose → lavender
                        SLAuroraPalette.lavender,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: _isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: SLAuroraPalette.roseDeep.withValues(alpha: 0.38),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                alignment: Alignment.center,
                child: widget.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        widget.label,
                        style: const TextStyle(
                          fontFamily: 'Quicksand',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 1.0,
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
