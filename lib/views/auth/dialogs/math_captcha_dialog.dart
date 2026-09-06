import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/services/l10n_service.dart';
import '../login/auth_visual_style.dart';

class MathCaptchaDialog {
  const MathCaptchaDialog._();

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: const Color(0xFF211923).withValues(alpha: 0.44),
      builder: (_) => const _MathCaptchaContent(),
    );
    return result ?? false;
  }
}

class _MathCaptchaContent extends StatefulWidget {
  const _MathCaptchaContent();

  @override
  State<_MathCaptchaContent> createState() => _MathCaptchaContentState();
}

class _MathCaptchaContentState extends State<_MathCaptchaContent> {
  final _controller = TextEditingController();
  late final int _first;
  late final int _second;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _first = random.nextInt(9) + 1;
    _second = random.nextInt(9) + 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim() == (_first + _second).toString()) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _hasError = true);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    final l10n = L10nService();
    return Dialog(
      backgroundColor: style.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: style.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: style.accentFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.verified_user_outlined,
                      color: style.accent,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.translate('auth_refresh_verify_badge'),
                      style: style.text(
                        size: 12,
                        color: style.muted,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l10n.translate('auth_refresh_verify_title'),
                style: style
                    .text(size: 25, weight: FontWeight.w600, height: 1.2)
                    .copyWith(letterSpacing: -0.6),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('auth_refresh_verify_subtitle'),
                style: style.text(size: 14, color: style.muted, height: 1.5),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: style.field,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: style.border),
                ),
                child: Semantics(
                  label: l10n.format('auth_refresh_verify_equation', {
                    'first': _first,
                    'second': _second,
                  }),
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$_first  +  $_second  =  ?',
                      style: style
                          .text(size: 34, weight: FontWeight.w500)
                          .copyWith(letterSpacing: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AuthSectionLabel(
                label: l10n.translate('auth_refresh_answer_label'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('auth_verify_answer'),
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: style.text(size: 18, weight: FontWeight.w500),
                cursorColor: style.accent,
                decoration: InputDecoration(
                  hintText: l10n.translate('auth_refresh_answer_hint'),
                  hintStyle: style.text(size: 14, color: style.muted),
                  filled: true,
                  fillColor: style.surface,
                  contentPadding: const EdgeInsets.all(16),
                  errorText: _hasError
                      ? l10n.translate('auth_refresh_answer_error')
                      : null,
                  errorMaxLines: 2,
                  errorStyle: style.text(
                    size: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: style.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: style.accent, width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  if (_hasError) setState(() => _hasError = false);
                },
              ),
              const SizedBox(height: 20),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 12,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: style.muted,
                      minimumSize: const Size(72, 50),
                      textStyle: style.text(size: 14, weight: FontWeight.w500),
                    ),
                    child: Text(l10n.translate('auth_refresh_cancel')),
                  ),
                  FilledButton.icon(
                    onPressed: _submit,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(l10n.translate('auth_refresh_verify_action')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(160, 50),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      backgroundColor: style.button,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: style.text(size: 14, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
