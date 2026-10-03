import '../../../utils/services/l10n_service.dart';
import '../../../utils/services/security_flow_guard.dart';

class SocialAuthActionHelper {
  const SocialAuthActionHelper._();

  static bool isSupportedProvider(String provider) {
    return provider == 'Google' ||
        provider == 'Facebook' ||
        provider == 'Apple';
  }

  static SensitiveActionType sensitiveActionFor(String provider) {
    switch (provider) {
      case 'Facebook':
        return SensitiveActionType.loginWithFacebook;
      case 'Apple':
        return SensitiveActionType.loginWithApple;
      case 'Google':
      default:
        return SensitiveActionType.loginWithGoogle;
    }
  }

  static String cancelledMessage(String provider) {
    switch (provider) {
      case 'Facebook':
        return L10nService().translate('ui_auth_you_have_canceled_your_facebook_login_71ffe6');
      case 'Apple':
        return L10nService().translate('ui_auth_you_have_canceled_your_apple_login_7367ed');
      case 'Google':
      default:
        return L10nService().translate('Bạn đã huỷ đăng nhập Google.');
    }
  }

  static String successMessage(String provider) {
    switch (provider) {
      case 'Facebook':
        return L10nService().translate('ui_auth_login_to_facebook_successfully_f22858');
      case 'Apple':
        return L10nService().translate('ui_auth_sign_in_to_apple_successfully_bed2d7');
      case 'Google':
      default:
        return L10nService().translate('Đăng nhập Google thành công!');
    }
  }
}
