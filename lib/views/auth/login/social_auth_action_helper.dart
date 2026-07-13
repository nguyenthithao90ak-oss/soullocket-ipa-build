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
        return 'Bạn đã huỷ đăng nhập Facebook.';
      case 'Apple':
        return 'Bạn đã huỷ đăng nhập Apple.';
      case 'Google':
      default:
        return L10nService().translate('auth_err_google_cancelled');
    }
  }

  static String successMessage(String provider) {
    switch (provider) {
      case 'Facebook':
        return 'Đăng nhập Facebook thành công!';
      case 'Apple':
        return 'Đăng nhập Apple thành công!';
      case 'Google':
      default:
        return L10nService().translate('Đăng nhập Google thành công!');
    }
  }
}
