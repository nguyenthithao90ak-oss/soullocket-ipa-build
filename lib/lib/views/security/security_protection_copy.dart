import 'package:flutter/material.dart';

import '../../utils/services/l10n_service.dart';
import '../../utils/services/security_protection_service.dart';

class SecurityProtectionFaqItem {
  final String question;
  final String answer;

  const SecurityProtectionFaqItem({
    required this.question,
    required this.answer,
  });
}

class SecurityProtectionCopy {
  final String badge;
  final String title;
  final String subtitle;
  final List<String> steps;
  final List<SecurityProtectionFaqItem> faqs;
  final String primaryActionLabel;
  final String secondaryActionLabel;
  final String dismissLabel;
  final String supportDraft;

  const SecurityProtectionCopy({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.faqs,
    required this.primaryActionLabel,
    required this.secondaryActionLabel,
    required this.dismissLabel,
    required this.supportDraft,
  });
}

SecurityProtectionCopy resolveSecurityProtectionCopy(
  BuildContext context,
  SecurityProtectionVerdict verdict,
) {
  final tr = L10nService().translate;

  final riskBadge = switch (verdict.effectiveRisk) {
    SecurityProtectionRiskLevel.block => tr('sec_action_blocked'),
    SecurityProtectionRiskLevel.warn => tr('sec_extra_verify'),
    SecurityProtectionRiskLevel.allow => tr('sec_allowed'),
  };

  switch (verdict.reason) {
    case SecurityProtectionReason.screenCapture:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: tr('sec_screen_recording_title'),
        subtitle: tr('sec_screen_recording_subtitle'),
        steps: [
          tr('sec_screen_recording_step1'),
          tr('sec_screen_recording_step2'),
          tr('sec_screen_recording_step3'),
        ],
        faqs: [
          SecurityProtectionFaqItem(
            question: tr('sec_faq_record_q'),
            answer: tr('sec_faq_record_a'),
          ),
          SecurityProtectionFaqItem(
            question: tr('sec_faq_block_all_q'),
            answer: tr('sec_faq_block_all_a'),
          ),
        ],
        primaryActionLabel: tr('sec_primary_action'),
        secondaryActionLabel: tr('sec_secondary_action'),
        dismissLabel: tr('sec_dismiss'),
        supportDraft: tr('sec_support_draft'),
      );
    case SecurityProtectionReason.overlay:
    case SecurityProtectionReason.controlApp:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: tr('sec_overlay_title'),
        subtitle: tr('sec_overlay_subtitle'),
        steps: [
          tr('sec_overlay_step1'),
          tr('sec_overlay_step2'),
          tr('sec_overlay_step3'),
        ],
        faqs: [
          SecurityProtectionFaqItem(
            question: tr('sec_faq_overlay_q'),
            answer: tr('sec_faq_overlay_a'),
          ),
          SecurityProtectionFaqItem(
            question: tr('sec_faq_overlay_false_alarm_q'),
            answer: tr('sec_faq_overlay_false_alarm_a'),
          ),
        ],
        primaryActionLabel: tr('sec_overlay_primary_action'),
        secondaryActionLabel: tr('sec_secondary_action'),
        dismissLabel: tr('sec_dismiss'),
        supportDraft: tr('sec_support_draft_overlay'),
      );
    case SecurityProtectionReason.unofficialBuild:
    case SecurityProtectionReason.unlicensed:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: tr('sec_unofficial_title'),
        subtitle: tr('sec_unofficial_subtitle'),
        steps: [
          tr('sec_unofficial_step1'),
          tr('sec_unofficial_step2'),
          tr('sec_unofficial_step3'),
        ],
        faqs: [
          SecurityProtectionFaqItem(
            question: tr('sec_faq_unofficial_q'),
            answer: tr('sec_faq_unofficial_a'),
          ),
          SecurityProtectionFaqItem(
            question: tr('sec_faq_block_all_q'),
            answer: tr('sec_faq_block_all_a'),
          ),
        ],
        primaryActionLabel: tr('sec_unofficial_primary_action'),
        secondaryActionLabel: tr('sec_secondary_action'),
        dismissLabel: tr('sec_dismiss'),
        supportDraft: tr('sec_unofficial_support_draft'),
      );
    case SecurityProtectionReason.malware:
    case SecurityProtectionReason.playProtect:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: tr('sec_malware_title'),
        subtitle: tr('sec_malware_subtitle'),
        steps: [
          tr('sec_malware_step1'),
          tr('sec_malware_step2'),
          tr('sec_malware_step3'),
        ],
        faqs: [
          SecurityProtectionFaqItem(
            question: tr('sec_faq_malware_q'),
            answer: tr('sec_faq_malware_a'),
          ),
          SecurityProtectionFaqItem(
            question: tr('sec_faq_malware_support_q'),
            answer: tr('sec_faq_malware_support_a'),
          ),
        ],
        primaryActionLabel: tr('sec_malware_primary_action'),
        secondaryActionLabel: tr('sec_secondary_action'),
        dismissLabel: tr('sec_dismiss'),
        supportDraft: tr('sec_malware_support_draft'),
      );
    case SecurityProtectionReason.rootIntegrity:
    case SecurityProtectionReason.unknown:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: tr('sec_root_title'),
        subtitle: tr('sec_root_subtitle'),
        steps: [
          tr('sec_root_step1'),
          tr('sec_root_step2'),
          tr('sec_root_step3'),
        ],
        faqs: [
          SecurityProtectionFaqItem(
            question: tr('sec_faq_root_q'),
            answer: tr('sec_faq_root_a'),
          ),
          SecurityProtectionFaqItem(
            question: tr('sec_faq_root_support_q'),
            answer: tr('sec_faq_root_support_a'),
          ),
        ],
        primaryActionLabel: tr('sec_root_primary_action'),
        secondaryActionLabel: tr('sec_secondary_action'),
        dismissLabel: tr('sec_dismiss'),
        supportDraft: tr('sec_root_support_draft'),
      );
  }
}
