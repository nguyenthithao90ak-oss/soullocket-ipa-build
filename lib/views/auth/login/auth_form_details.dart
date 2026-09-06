import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'auth_visual_style.dart';

class AuthRememberRow extends StatelessWidget {
  final bool selected;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onForgotPassword;
  const AuthRememberRow({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    final remember = InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: selected,
            onChanged: onChanged,
            activeColor: style.button,
            checkColor: Colors.white,
            side: BorderSide(color: style.muted, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Flexible(
            child: Text(
              context.tr('remember_me'),
              style: style.text(size: 12, color: style.muted),
            ),
          ),
        ],
      ),
    );
    final forgot = TextButton(
      onPressed: onForgotPassword,
      style: TextButton.styleFrom(
        foregroundColor: style.accent,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        textStyle: style.text(size: 12, weight: FontWeight.w500),
      ),
      child: Text(context.tr('forgot_password')),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 290 ||
            MediaQuery.textScalerOf(context).scale(12) > 16) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [remember, forgot],
          );
        }
        return Row(
          children: [
            Expanded(child: remember),
            const SizedBox(width: 8),
            forgot,
          ],
        );
      },
    );
  }
}

class AuthTermsConsent extends StatefulWidget {
  final bool accepted;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  const AuthTermsConsent({
    super.key,
    required this.accepted,
    required this.onChanged,
    required this.onTerms,
    required this.onPrivacy,
  });

  @override
  State<AuthTermsConsent> createState() => _AuthTermsConsentState();
}

class _AuthTermsConsentState extends State<AuthTermsConsent> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => widget.onTerms();
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => widget.onPrivacy();
  late final TapGestureRecognizer _consent = TapGestureRecognizer()
    ..onTap = () => widget.onChanged(!widget.accepted);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    _consent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    final linkStyle = style
        .text(size: 12, weight: FontWeight.w500, color: style.accent)
        .copyWith(
          decoration: TextDecoration.underline,
          decorationColor: style.accent,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: widget.accepted,
          onChanged: widget.onChanged,
          semanticLabel: context.tr('auth_refresh_consent_label'),
          activeColor: style.button,
          checkColor: Colors.white,
          side: BorderSide(color: style.muted, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text.rich(
              TextSpan(
                style: style.text(size: 12, color: style.muted, height: 1.6),
                children: [
                  TextSpan(
                    text: context.tr('auth_terms_confirm_prefix'),
                    recognizer: _consent,
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: context.tr('terms_of_use'),
                    style: linkStyle,
                    recognizer: _terms,
                  ),
                  const TextSpan(text: ' & '),
                  TextSpan(
                    text: context.tr('privacy_policy'),
                    style: linkStyle,
                    recognizer: _privacy,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthPrivacyNote extends StatelessWidget {
  final String text;
  const AuthPrivacyNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final style = AuthVisualStyle.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: style.text(size: 11, color: style.muted, height: 1.5),
    );
  }
}
