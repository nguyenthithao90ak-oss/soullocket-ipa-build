import 'package:flutter/material.dart';

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
  final isEnglish = Localizations.localeOf(context)
      .languageCode
      .toLowerCase()
      .startsWith('en');

  final riskBadge = switch (verdict.effectiveRisk) {
    SecurityProtectionRiskLevel.block =>
      isEnglish ? 'Sensitive action blocked' : 'Đã chặn thao tác nhạy cảm',
    SecurityProtectionRiskLevel.warn =>
      isEnglish ? 'Extra verification needed' : 'Cảnh báo bảo mật',
    SecurityProtectionRiskLevel.allow => isEnglish ? 'Allowed' : 'Cho phép',
  };

  switch (verdict.reason) {
    case SecurityProtectionReason.screenCapture:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: isEnglish
            ? 'Turn off screen recording or screen sharing and try again'
            : 'Tắt quay hoặc chia sẻ màn hình rồi thử lại',
        subtitle: isEnglish
            ? 'OTP, PIN, QR login, and payment flows are hidden on devices that are recording or sharing the screen.'
            : 'OTP, PIN, QR login và thanh toán sẽ bị khóa khi thiết bị đang quay hoặc chia sẻ màn hình.',
        steps: isEnglish
            ? const [
                'Stop any screen recorder, live stream, or screen sharing session.',
                'Return to the sensitive step and request a fresh OTP or retry the action.',
                'If you still see this warning, restart the app and re-open the flow.',
              ]
            : const [
                'Tắt ứng dụng quay màn hình, live stream hoặc chia sẻ màn hình.',
                'Quay lại bước nhạy cảm, lấy OTP mới hoặc thử lại thao tác.',
                'Nếu vẫn bị chặn, tắt app mở lại rồi vào lại luồng này.',
              ],
        faqs: isEnglish
            ? const [
                SecurityProtectionFaqItem(
                  question: 'Why does the app care about recording?',
                  answer:
                      'Sensitive codes can be leaked when the screen is being recorded or mirrored.',
                ),
                SecurityProtectionFaqItem(
                  question: 'Will normal screens still work?',
                  answer:
                      'Yes. Only sensitive actions should be restricted. The rest of the app should remain normal.',
                ),
              ]
            : const [
                SecurityProtectionFaqItem(
                  question: 'Vì sao app chặn quay màn hình?',
                  answer:
                      'OTP, PIN và mã đăng nhập có thể bị lộ khi màn hình đang được quay hoặc chia sẻ.',
                ),
                SecurityProtectionFaqItem(
                  question: 'Có chặn toàn bộ app không?',
                  answer:
                      'Không. Chỉ các luồng nhạy cảm mới bị cảnh báo hoặc chặn.',
                ),
              ],
        primaryActionLabel:
            isEnglish ? 'Fix and retry' : 'Tôi sẽ tắt và thử lại',
        secondaryActionLabel:
            isEnglish ? 'Open support help' : 'Mở hướng dẫn khắc phục',
        dismissLabel: isEnglish ? 'Close' : 'Đóng',
        supportDraft: isEnglish
            ? 'Security protection blocked a sensitive action because screen recording or sharing seems active.'
            : 'Bảo vệ an toàn đang chặn thao tác nhạy cảm vì thiết bị có dấu hiệu quay hoặc chia sẻ màn hình.',
      );
    case SecurityProtectionReason.overlay:
    case SecurityProtectionReason.controlApp:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: isEnglish
            ? 'Turn off overlay, auto clicker, or remote control apps'
            : 'Tắt app nổi, auto click hoặc app điều khiển màn hình',
        subtitle: isEnglish
            ? 'Sensitive confirmation buttons are protected from overlay and tapjacking attempts.'
            : 'Nút xác nhận nhạy cảm được bảo vệ để tránh overlay, tapjacking và app điều khiển.',
        steps: isEnglish
            ? const [
                'Close floating windows, auto clickers, remote control apps, or suspicious accessibility tools.',
                'Return to the login, OTP, PIN, or payment step and try again.',
                'If you intentionally use an accessibility tool, contact support so the team can verify the case.',
              ]
            : const [
                'Tắt bong bóng chat, app nổi, auto click, remote control hoặc công cụ accessibility đáng ngờ.',
                'Quay lại bước login, OTP, PIN hoặc thanh toán và thử lại.',
                'Nếu bạn đang dùng công cụ hỗ trợ hợp lệ, liên hệ support để đội ngũ kiểm tra thêm.',
              ],
        faqs: isEnglish
            ? const [
                SecurityProtectionFaqItem(
                  question: 'Why is overlay risky?',
                  answer:
                      'Overlay apps can hide, replace, or capture sensitive confirmation buttons.',
                ),
                SecurityProtectionFaqItem(
                  question: 'What if this is a false alarm?',
                  answer:
                      'Use support and describe which app was running in the background.',
                ),
              ]
            : const [
                SecurityProtectionFaqItem(
                  question: 'Vì sao app nổi lại nguy hiểm?',
                  answer:
                      'App nổi có thể che, đổi vị trí hoặc đánh cắp thao tác trên các nút xác nhận quan trọng.',
                ),
                SecurityProtectionFaqItem(
                  question: 'Nếu đây là báo nhầm thì sao?',
                  answer:
                      'Bấm hỗ trợ và ghi rõ app nào đang chạy nền để CSKH kiểm tra.',
                ),
              ],
        primaryActionLabel:
            isEnglish ? 'I turned them off' : 'Tôi đã tắt các app đó',
        secondaryActionLabel:
            isEnglish ? 'See protected steps' : 'Xem cách khắc phục',
        dismissLabel: isEnglish ? 'Close' : 'Đóng',
        supportDraft: isEnglish
            ? 'A sensitive action was blocked because overlay, auto click, or remote control behavior was detected.'
            : 'Thao tác nhạy cảm bị chặn vì hệ thống phát hiện overlay, auto click hoặc app điều khiển màn hình.',
      );
    case SecurityProtectionReason.unofficialBuild:
    case SecurityProtectionReason.unlicensed:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: isEnglish
            ? 'Install the official app build and try again'
            : 'Hãy cài bản chính thức của ứng dụng rồi thử lại',
        subtitle: isEnglish
            ? 'This device appears to run an unofficial, sideloaded, or unlicensed build for a sensitive action.'
            : 'Thiết bị này có dấu hiệu đang chạy bản mod, sideload hoặc bản không được cấp phép cho thao tác nhạy cảm.',
        steps: isEnglish
            ? const [
                'Remove the unofficial or modified build from the device.',
                'Install the official version from the trusted release channel.',
                'Log in again and retry the protected action.',
              ]
            : const [
                'Gỡ bản mod, bản lệch hoặc bản cài tay khỏi thiết bị.',
                'Cài lại bản chính thức từ kênh phát hành tin cậy.',
                'Đăng nhập lại và thử lại thao tác được bảo vệ.',
              ],
        faqs: isEnglish
            ? const [
                SecurityProtectionFaqItem(
                  question: 'Why is sideloading restricted?',
                  answer:
                      'Unofficial builds may alter payment, login, or device trust behavior.',
                ),
                SecurityProtectionFaqItem(
                  question: 'Can I still read data in the app?',
                  answer:
                      'The rollout may only restrict sensitive actions, depending on the current protection stage.',
                ),
              ]
            : const [
                SecurityProtectionFaqItem(
                  question: 'Vì sao bản cài tay bị hạn chế?',
                  answer:
                      'Bản không chính thức có thể sửa luồng login, thanh toán hoặc xác thực thiết bị.',
                ),
                SecurityProtectionFaqItem(
                  question: 'Có chặn toàn bộ app không?',
                  answer:
                      'Tùy theo rollout hiện tại, hệ thống có thể chỉ chặn các action nhạy cảm.',
                ),
              ],
        primaryActionLabel: isEnglish
            ? 'I will install the official build'
            : 'Tôi sẽ cài bản chính thức',
        secondaryActionLabel:
            isEnglish ? 'Open support help' : 'Mở hướng dẫn và hỗ trợ',
        dismissLabel: isEnglish ? 'Close' : 'Đóng',
        supportDraft: isEnglish
            ? 'A sensitive action was blocked because the device appears to run an unofficial or unlicensed build.'
            : 'Thao tác nhạy cảm bị chặn vì thiết bị có dấu hiệu đang chạy bản mod, sideload hoặc không được cấp phép.',
      );
    case SecurityProtectionReason.malware:
    case SecurityProtectionReason.playProtect:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: isEnglish
            ? 'Scan the device with Play Protect and try again'
            : 'Quét Play Protect rồi mở lại ứng dụng',
        subtitle: isEnglish
            ? 'The device reports app-access or Play Protect risk signals. Sensitive flows need a cleaner environment first.'
            : 'Thiết bị đang báo app-access risk hoặc Play Protect risk. Các luồng nhạy cảm cần môi trường sạch hơn để tiếp tục.',
        steps: isEnglish
            ? const [
                'Open Play Protect and run a device scan.',
                'Remove suspicious apps with screen control, injection, or malware-like behavior.',
                'Restart the device and retry the sensitive step.',
              ]
            : const [
                'Mở Play Protect và quét thiết bị.',
                'Gỡ các app đáng nghi có hành vi điều khiển màn hình, chèn lệnh hoặc malware.',
                'Khởi động lại máy rồi thử lại thao tác nhạy cảm.',
              ],
        faqs: isEnglish
            ? const [
                SecurityProtectionFaqItem(
                  question: 'Does this mean my phone is infected?',
                  answer:
                      'Not always, but the device is exposing security signals that make sensitive flows less trustworthy.',
                ),
                SecurityProtectionFaqItem(
                  question: 'What should support know?',
                  answer:
                      'Tell support which security apps, cleaners, or automation tools are currently installed.',
                ),
              ]
            : const [
                SecurityProtectionFaqItem(
                  question: 'Đây có phải máy đã nhiễm độc không?',
                  answer:
                      'Chưa chắc, nhưng thiết bị đang trả về các tín hiệu không an toàn cho thao tác nhạy cảm.',
                ),
                SecurityProtectionFaqItem(
                  question: 'Cần gửi gì cho support?',
                  answer:
                      'Hãy ghi rõ các app bảo mật, dọn rác hoặc tự động hóa đang cài trên máy.',
                ),
              ],
        primaryActionLabel:
            isEnglish ? 'I will scan my device' : 'Tôi sẽ quét thiết bị',
        secondaryActionLabel:
            isEnglish ? 'Open support help' : 'Mở hướng dẫn và hỗ trợ',
        dismissLabel: isEnglish ? 'Close' : 'Đóng',
        supportDraft: isEnglish
            ? 'Sensitive protection flagged malware or Play Protect risk on this device.'
            : 'Bảo vệ an toàn đang đánh dấu malware hoặc Play Protect risk trên thiết bị này.',
      );
    case SecurityProtectionReason.rootIntegrity:
    case SecurityProtectionReason.unknown:
      return SecurityProtectionCopy(
        badge: riskBadge,
        title: isEnglish
            ? 'This device is not trusted enough for the sensitive action'
            : 'Thiết bị này chưa đủ tin cậy cho thao tác nhạy cảm',
        subtitle: isEnglish
            ? 'The app received integrity or device-state signals that require extra caution before continuing.'
            : 'Ứng dụng đang nhận được tín hiệu về integrity hoặc trạng thái thiết bị, cần thận trọng thêm trước khi tiếp tục.',
        steps: isEnglish
            ? const [
                'Disable tools that alter, automate, or inspect app behavior.',
                'Restart the app and retry the protected step.',
                'If the warning persists on a clean device, contact support with the exact step and device model.',
              ]
            : const [
                'Tắt các công cụ sửa app, tự động hóa hoặc theo dõi hành vi ứng dụng.',
                'Khởi động lại app và thử lại bước được bảo vệ.',
                'Nếu máy sạch mà vẫn bị cảnh báo, liên hệ support kèm bước đang thực hiện và tên thiết bị.',
              ],
        faqs: isEnglish
            ? const [
                SecurityProtectionFaqItem(
                  question: 'Will this affect all app usage?',
                  answer:
                      'It should mainly affect sensitive flows such as login, OTP, PIN, QR login, payment, or trusted-device changes.',
                ),
                SecurityProtectionFaqItem(
                  question: 'Can support remove the protection?',
                  answer:
                      'Support can review false positives, but they should not disable high-risk rules for unsafe environments.',
                ),
              ]
            : const [
                SecurityProtectionFaqItem(
                  question: 'Có ảnh hưởng toàn bộ app không?',
                  answer:
                      'Chủ yếu ảnh hưởng login, OTP, PIN, QR login, thanh toán và đổi thiết bị tin cậy.',
                ),
                SecurityProtectionFaqItem(
                  question: 'Support có thể bỏ chặn hoàn toàn không?',
                  answer:
                      'CSKH có thể kiểm tra báo nhầm, nhưng không nên tắt rule nguy cơ cao cho môi trường không an toàn.',
                ),
              ],
        primaryActionLabel: isEnglish
            ? 'I understand, retry later'
            : 'Tôi đã hiểu, thử lại sau',
        secondaryActionLabel:
            isEnglish ? 'Open support help' : 'Mở hướng dẫn và hỗ trợ',
        dismissLabel: isEnglish ? 'Close' : 'Đóng',
        supportDraft: isEnglish
            ? 'A sensitive action is being restricted because device integrity or trust signals look risky.'
            : 'Thao tác nhạy cảm đang bị hạn chế vì tín hiệu integrity hoặc trust của thiết bị có dấu hiệu rủi ro.',
      );
  }
}
