import 'package:flutter/material.dart';

import '../../../../../core/sl_theme.dart';
import '../../../../../utils/flexible_date_input.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../widgets/sl_detail_widgets.dart';

class SecurityRecoveryQuestion extends StatelessWidget {
  const SecurityRecoveryQuestion({
    super.key,
    required this.questions,
    required this.selectedQuestion,
    required this.locked,
    required this.birthQuestion,
    required this.answerController,
    required this.onQuestionChanged,
    required this.onNormalizeDate,
    required this.onPickDate,
    required this.onSave,
  });

  final List<String> questions;
  final String selectedQuestion;
  final bool locked;
  final bool birthQuestion;
  final TextEditingController answerController;
  final ValueChanged<String?> onQuestionChanged;
  final VoidCallback onNormalizeDate;
  final VoidCallback onPickDate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => _SecuritySection(
    icon: Icons.help_outline_rounded,
    title: context.tr('security_question'),
    subtitle: context.tr(
      locked ? 'security_q_locked' : 'home_chnntmtlnc_0791a2',
    ),
    configured: locked,
    children: locked
        ? [
            Text(
              selectedQuestion,
              style: SLTheme.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: SLDetailStyle.text(context),
              ),
            ),
          ]
        : [
            DropdownButtonFormField<String>(
              initialValue: questions.contains(selectedQuestion)
                  ? selectedQuestion
                  : questions.isEmpty
                  ? null
                  : questions.first,
              isExpanded: true,
              itemHeight: null,
              borderRadius: BorderRadius.circular(14),
              dropdownColor: SLDetailStyle.card(context),
              icon: Icon(
                Icons.expand_more_rounded,
                color: SLDetailStyle.muted(context),
              ),
              style: _inputStyle(context),
              decoration: _inputDecoration(
                context,
                hint: context.tr('home_chncuhibom_0eba13'),
              ),
              selectedItemBuilder: (context) => [
                for (final question in questions)
                  Text(
                    question,
                    style: _inputStyle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
              items: [
                for (final question in questions)
                  DropdownMenuItem(
                    value: question,
                    child: Text(question, style: _inputStyle(context)),
                  ),
              ],
              onChanged: onQuestionChanged,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: answerController,
              style: _inputStyle(context),
              keyboardType: birthQuestion
                  ? TextInputType.datetime
                  : TextInputType.text,
              inputFormatters: birthQuestion
                  ? const [FlexibleDateInputFormatter()]
                  : null,
              textInputAction: TextInputAction.done,
              onEditingComplete: birthQuestion ? onNormalizeDate : null,
              onSubmitted: birthQuestion ? (_) => onNormalizeDate() : null,
              decoration: _inputDecoration(
                context,
                hint: context.tr(
                  birthQuestion ? 'home_ngythngnm_a697d0' : 'enter_answer',
                ),
                suffix: birthQuestion
                    ? IconButton(
                        tooltip: context.tr('select_your_dob'),
                        onPressed: onPickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            _SecuritySaveButton(
              label: context.tr('save_security_question'),
              onSave: onSave,
            ),
          ],
  );
}

class SecurityDeviceLink extends StatelessWidget {
  const SecurityDeviceLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: SLDetailStyle.outline(context)),
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const SLDetailIcon(
                icon: Icons.devices_outlined,
                color: SLDetailStyle.blue,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home_thitbngnhp_d39323'),
                      style: _headingStyle(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('home_qunlthitbn_8d057f'),
                      style: _descriptionStyle(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: SLDetailStyle.muted(context),
                textDirection: Directionality.of(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SecurityBackupPin extends StatelessWidget {
  const SecurityBackupPin({
    super.key,
    required this.configured,
    required this.visible,
    required this.controller,
    required this.onToggleVisibility,
    required this.onSave,
  });

  final bool configured;
  final bool visible;
  final TextEditingController controller;
  final VoidCallback onToggleVisibility;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => _SecuritySection(
    icon: Icons.key_outlined,
    title: context.tr('backup_pin'),
    subtitle: context.tr('backup_pin_desc'),
    configured: configured,
    children: [
      TextField(
        controller: controller,
        obscureText: !visible,
        enableSuggestions: false,
        autocorrect: false,
        style: _inputStyle(context),
        textInputAction: TextInputAction.done,
        decoration: _inputDecoration(
          context,
          hint: context.tr('backup_pin'),
          helper: context.tr('backup_pin_hint'),
          suffix: IconButton(
            tooltip: context.tr(visible ? 'home_n_f7bc96' : 'home_hin_726cac'),
            onPressed: onToggleVisibility,
            icon: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _SecuritySaveButton(label: context.tr('save_backup_pin'), onSave: onSave),
    ],
  );
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.configured,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool configured;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final statusColor = configured
        ? SLDetailStyle.accent(context, SLDetailStyle.sage)
        : SLDetailStyle.muted(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SLDetailIcon(icon: icon, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _headingStyle(context)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          configured
                              ? Icons.check_circle_outline_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 13,
                          color: statusColor,
                        ),
                        Text(
                          context.tr(
                            configured
                                ? 'home_thitlp_2fdbaa'
                                : 'home_chathitlp_bf65d4',
                          ),
                          style: SLTheme.quicksand(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(subtitle, style: _descriptionStyle(context)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SecuritySaveButton extends StatelessWidget {
  const _SecuritySaveButton({required this.label, required this.onSave});

  final String label;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: FilledButton.icon(
      onPressed: onSave,
      icon: const Icon(Icons.check_rounded, size: 18),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: SLTheme.quicksand(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: SLDetailStyle.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

TextStyle _headingStyle(BuildContext context) => SLTheme.quicksand(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.4,
  color: SLDetailStyle.text(context),
);

TextStyle _descriptionStyle(BuildContext context) => SLTheme.quicksand(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  height: 1.5,
  color: SLDetailStyle.muted(context),
);

TextStyle _inputStyle(BuildContext context) => SLTheme.quicksand(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  height: 1.5,
  color: SLDetailStyle.text(context),
);

InputDecoration _inputDecoration(
  BuildContext context, {
  required String hint,
  String? helper,
  Widget? suffix,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: SLDetailStyle.outline(context)),
  );
  return InputDecoration(
    hintText: hint,
    hintMaxLines: 3,
    helperText: helper,
    helperMaxLines: 4,
    helperStyle: _descriptionStyle(context),
    hintStyle: _inputStyle(
      context,
    ).copyWith(color: SLDetailStyle.muted(context)),
    suffixIcon: suffix,
    suffixIconColor: SLDetailStyle.muted(context),
    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    filled: true,
    fillColor: SLDetailStyle.card(context),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: SLDetailStyle.accent(context, SLDetailStyle.primary),
        width: 1.5,
      ),
    ),
  );
}
