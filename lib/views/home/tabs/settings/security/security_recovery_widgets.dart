import 'package:flutter/material.dart';

import '../../../../../utils/flexible_date_input.dart';
import '../../../../../utils/services/l10n_service.dart';
import '../../../../../widgets/sl_settings_kit.dart';

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
            SLSettingsSelectField(
              icon: Icons.help_outline_rounded,
              label: context.tr('security_question'),
              value: selectedQuestion,
              trailingIcon: Icons.lock_outline_rounded,
              onTap: null,
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
              dropdownColor: SLSettingsColors.surface,
              icon: const Icon(
                Icons.expand_more_rounded,
                color: SLSettingsColors.inkTertiary,
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
                hint: birthQuestion
                    ? DateInputUtils.formatHint(allowMissingYear: true)
                    : context.tr('enter_answer'),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SLSettingsGroup(
      margin: EdgeInsets.zero,
      children: [
        SLSettingsRow(
          icon: Icons.devices_outlined,
          iconColor: SLSettingsColors.sky,
          filledIcon: false,
          title: context.tr('home_thitbngnhp_d39323'),
          subtitle: context.tr('home_qunlthitbn_8d057f'),
          onTap: onTap,
        ),
      ],
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
    return SLSettingsCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SLSettingsBlockHeading(
            icon: icon,
            iconColor: SLSettingsColors.indigo,
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SLSettingsPill(
              label: context.tr(
                configured ? 'home_thitlp_2fdbaa' : 'home_chathitlp_bf65d4',
              ),
              icon: configured
                  ? Icons.check_rounded
                  : Icons.radio_button_unchecked_rounded,
              tone: configured
                  ? SLSettingsTone.success
                  : SLSettingsTone.neutral,
              dense: true,
            ),
          ),
          const SizedBox(height: 14),
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
  Widget build(BuildContext context) => SLSettingsButton(
    label: label,
    icon: Icons.check_rounded,
    onPressed: onSave,
  );
}

TextStyle _inputStyle(BuildContext context) => slSettingsInputTextStyle();

InputDecoration _inputDecoration(
  BuildContext context, {
  required String hint,
  String? helper,
  Widget? suffix,
}) {
  return slSettingsInputDecoration(
    hint: hint,
    helperText: helper,
    suffixIcon: suffix,
  ).copyWith(
    hintMaxLines: 3,
    helperMaxLines: 4,
    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  );
}
