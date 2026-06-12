import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../services/l10n_service.dart';
import '../../../utils/flexible_date_input.dart';
import '../login/social_auth_buttons.dart';

class RegisterForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final bool acceptTerms;
  final bool showSecurityQuestion;
  final String selectedSecurityQuestion;
  final List<String> securityQuestions;
  final TextEditingController securityAnswerController;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onAcceptTermsChanged;
  final VoidCallback onToggleSecurityQuestion;
  final ValueChanged<String?> onSecurityQuestionChanged;
  final VoidCallback onRegister;
  final Function(String) onSocialLogin;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final Color accentRose;
  final Color accentBlush;
  final Color accentLavender;

  const RegisterForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.acceptTerms,
    required this.showSecurityQuestion,
    required this.selectedSecurityQuestion,
    required this.securityQuestions,
    required this.securityAnswerController,
    required this.onToggleObscure,
    required this.onAcceptTermsChanged,
    required this.onToggleSecurityQuestion,
    required this.onSecurityQuestionChanged,
    required this.onRegister,
    required this.onSocialLogin,
    required this.onTermsTap,
    required this.onPrivacyTap,
    required this.accentRose,
    required this.accentBlush,
    required this.accentLavender,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final isBirthQuestion =
        DateInputUtils.looksLikeBirthQuestion(selectedSecurityQuestion);
    final passwordLabel = l10n.translate('password');
    final passwordHint = l10n.translate('auth_password_hint_short');
    final securityQuestionLabel =
        l10n.translate('auth_security_question_optional');
    final securityQuestionTapLabel =
        l10n.translate('auth_security_question_tap');
    final securityNote = l10n.translate('auth_security_note');
    final securityAnswerHint = l10n.translate('auth_security_answer_hint');
    final signupLabel = l10n.translate('signup').toUpperCase();

    return AutofillGroup(
      child: Column(
        key: const ValueKey('register'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SLTheme.sectionHeader(
            title: l10n.translate('auth_login_email_label'),
            trailing: l10n.translate('auth_required_badge').toUpperCase(),
            trailingColor: accentRose,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [
              AutofillHints.newUsername,
              AutofillHints.email,
            ],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 16),
            decoration: SLTheme.authInputDecoration(
              hintText: l10n.translate('auth_email_example'),
              focusColor: accentRose,
              prefixIcon: Icon(
                Icons.mail_outline_rounded,
                color: accentRose.withValues(alpha: 0.65),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SLTheme.sectionHeader(title: passwordLabel),
          const SizedBox(height: 8),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            enableSuggestions: false,
            autocorrect: false,
            onSubmitted: (_) {
              if (!isLoading) onRegister();
            },
            style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 16),
            decoration: SLTheme.authInputDecoration(
              hintText: passwordHint,
              focusColor: accentRose,
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: accentRose.withValues(alpha: 0.65),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: SLTheme.authMutedTextColor,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onToggleSecurityQuestion,
            child: SLTheme.authToggleCard(
              selected: showSecurityQuestion,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        showSecurityQuestion
                            ? securityQuestionLabel
                            : securityQuestionTapLabel,
                        style: SLTheme.quicksand(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: showSecurityQuestion
                              ? SLColors.textSecond
                              : SLTheme.authMutedTextColor,
                          fontStyle: showSecurityQuestion
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 240),
                      turns: showSecurityQuestion ? 0.5 : 0,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: SLColors.primary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: showSecurityQuestion
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 4),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SLTheme.authHintCard(
                    child: Text(
                      securityNote,
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        color: SLColors.primary,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: SLTheme.authFieldDecoration(
                    fillColor: SLTheme.authFieldFill,
                    borderColor: SLTheme.authFieldBorder,
                    focusColor: accentRose,
                    radius: 16,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSecurityQuestion,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: SLColors.primary,
                      ),
                      style: SLTheme.quicksand(
                        color: SLColors.textSecond,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      onChanged: onSecurityQuestionChanged,
                      items: securityQuestions
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: securityAnswerController,
                  keyboardType: isBirthQuestion
                      ? TextInputType.datetime
                      : TextInputType.text,
                  inputFormatters: isBirthQuestion
                      ? const [FlexibleDateInputFormatter()]
                      : null,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: isBirthQuestion
                      ? () {
                          final normalized = DateInputUtils.normalizeForDisplay(
                            securityAnswerController.text,
                            firstYear: 1900,
                            lastYear: DateTime.now().year,
                            allowMissingYear: true,
                          );
                          securityAnswerController.text = normalized;
                          securityAnswerController.selection =
                              TextSelection.collapsed(
                            offset: normalized.length,
                          );
                        }
                      : null,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  decoration: SLTheme.authInputDecoration(
                    hintText: isBirthQuestion
                        ? l10n.translate('auth_birthdate_hint')
                        : securityAnswerHint,
                    helperText: isBirthQuestion
                        ? l10n.translate('auth_birthdate_helper')
                        : null,
                    focusColor: accentRose,
                    prefixIcon: Icon(
                      Icons.question_answer_outlined,
                      color: accentRose.withValues(alpha: 0.65),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SLTheme.authToggleCard(
            selected: acceptTerms,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: acceptTerms,
                      activeColor: SLColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: onAcceptTermsChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          color: const Color(0xFF58455B),
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${l10n.translate('auth_terms_confirm_prefix')} ',
                            recognizer: TapGestureRecognizer()
                              ..onTap =
                                  () => onAcceptTermsChanged(!acceptTerms),
                          ),
                          TextSpan(
                            text: l10n.translate('terms_of_use'),
                            style: const TextStyle(
                              color: SLColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = onTermsTap,
                          ),
                          TextSpan(
                            text: ' & ',
                            recognizer: TapGestureRecognizer()
                              ..onTap =
                                  () => onAcceptTermsChanged(!acceptTerms),
                          ),
                          TextSpan(
                            text: l10n.translate('privacy_policy'),
                            style: const TextStyle(
                              color: SLColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = onPrivacyTap,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SLTheme.authPrimaryButton(
            label: signupLabel,
            onPressed: isLoading ? null : onRegister,
            isLoading: isLoading,
            colors: [accentRose, accentBlush, accentLavender],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                l10n.translate('auth_quick_register').toUpperCase(),
                style: SLTheme.quicksand(
                  color: const Color(0xFF888888),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SocialAuthButtons(
            onProviderTap: onSocialLogin,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              l10n.translate('auth_social_register_notice'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                color: const Color(0xFF999999),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
