import 'package:flutter/material.dart';

/// Text field for the Locket Garden authentication design.
/// Public API is unchanged so the auth logic can remain untouched.
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
  final TextCapitalization textCapitalization;

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
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }

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
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    const ink = Color(0xFF493C46);
    const rose = Color(0xFFE9698B);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: focused
                ? rose.withValues(alpha: 0.16)
                : const Color(0xFFB59AA4).withValues(alpha: 0.07),
            blurRadius: focused ? 18 : 10,
            offset: const Offset(0, 6),
          ),
        ],
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
        style: const TextStyle(
          fontFamily: 'Quicksand',
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: ink,
        ),
        cursorColor: rose,
        cursorWidth: 2.2,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: ink.withValues(alpha: 0.42),
          ),
          prefixIcon: widget.prefixIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: _SoftIconBubble(
                    active: focused,
                    child: widget.prefixIcon!,
                  ),
                ),
          prefixIconConstraints: const BoxConstraints.tightFor(width: 48, height: 48),
          suffixIcon: widget.suffixIcon,
          suffixIconConstraints: const BoxConstraints.tightFor(width: 48, height: 48),
          filled: true,
          fillColor: focused
              ? const Color(0xFFFFFCFD)
              : const Color(0xFFFFFAF8).withValues(alpha: 0.92),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(23),
            borderSide: const BorderSide(
              color: Color(0xFFF1D9E0),
              width: 1.25,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(23),
            borderSide: const BorderSide(
              color: Color(0xFFEA7B98),
              width: 1.7,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(23),
            borderSide: const BorderSide(
              color: Color(0xFFD94A65),
              width: 1.4,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(23),
            borderSide: const BorderSide(
              color: Color(0xFFD94A65),
              width: 1.7,
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftIconBubble extends StatelessWidget {
  final bool active;
  final Widget child;

  const _SoftIconBubble({required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFE7EE) : const Color(0xFFFFF0F3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: IconTheme.merge(
            data: IconThemeData(
              size: 18,
              color: active ? const Color(0xFFE75F83) : const Color(0xFF9C7F89),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Primary CTA with a soft hand-made ribbon feeling.
class AuroraPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onDisabledTap;
  final bool isLoading;
  final bool enabled;

  const AuroraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onDisabledTap,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  State<AuroraPrimaryButton> createState() => _AuroraPrimaryButtonState();
}

class _AuroraPrimaryButtonState extends State<AuroraPrimaryButton> {
  bool _pressed = false;

  bool get _canInteract =>
      !widget.isLoading &&
      (widget.onPressed != null || widget.onDisabledTap != null);

  void _setPressed(bool value) {
    if (!_canInteract || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isActuallyDisabled = !widget.enabled || widget.isLoading;
    final opacity = isActuallyDisabled ? 0.58 : 1.0;

    return Semantics(
      button: true,
      enabled: _canInteract,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: !_canInteract ? null : (_) => _setPressed(true),
        onTapCancel: !_canInteract ? null : () => _setPressed(false),
        onTapUp: !_canInteract
            ? null
            : (_) {
                _setPressed(false);
                if (!widget.enabled) {
                  widget.onDisabledTap?.call();
                } else {
                  widget.onPressed?.call();
                }
              },
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEE6386),
                    Color(0xFFE24B70),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 1.1,
                ),
                boxShadow: isActuallyDisabled
                    ? const []
                    : [
                        BoxShadow(
                          color: const Color(0xFFE8587A).withValues(alpha: 0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 18,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 17,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  if (widget.isLoading)
                    const SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 44),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Quicksand',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.45,
                        ),
                      ),
                    ),
                  Positioned(
                    right: 18,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.78),
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
}
