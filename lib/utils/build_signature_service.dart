import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart';

import 'package:soullocket_app/utils/services/l10n_service.dart';

const MethodChannel _bootstrapChannel = MethodChannel('soul_locket/bootstrap');
const String _signatureMethod = 'getAppSignatureStatus';
const String _signatureMismatchReasonCode = 'UNOFFICIAL_BUILD';

class UnofficialBuildDetected implements Exception {
  const UnofficialBuildDetected({
    required this.reasonCode,
    required this.status,
  });

  final String reasonCode;
  final String status;
}

class AppSignatureStatus {
  const AppSignatureStatus({
    required this.status,
    required this.reasonCode,
    required this.isTrusted,
  });

  final String status;
  final String reasonCode;
  final bool isTrusted;

  bool get shouldBlock => !isTrusted;
}

class BuildSignatureService {
  static Future<AppSignatureStatus> loadSignatureStatus() async {
    if (kIsWeb) {
      return const AppSignatureStatus(
        status: 'ok',
        reasonCode: 'web',
        isTrusted: true,
      );
    }

    try {
      return await _readNativeStatus().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Thiếu bridge, lỗi native và timeout đều không chứng minh được chữ ký.
      return const AppSignatureStatus(
        status: 'package_info_unavailable',
        reasonCode: _signatureMismatchReasonCode,
        isTrusted: false,
      );
    }
  }

  static Future<AppSignatureStatus> _readNativeStatus() async {
    final raw = await _bootstrapChannel.invokeMapMethod<String, dynamic>(
      _signatureMethod,
    );
    final status = (raw?['status'] as String? ?? 'package_info_unavailable')
        .trim();
    final reasonCode =
        (raw?['reasonCode'] as String? ?? _signatureMismatchReasonCode).trim();
    final isTrusted = raw?['isTrusted'] == true;
    return AppSignatureStatus(
      status: status,
      reasonCode: reasonCode.isEmpty
          ? _signatureMismatchReasonCode
          : reasonCode,
      isTrusted: isTrusted,
    );
  }

  static Future<void> verifyOfficialBuildSignature() async {
    if (kDebugMode || kIsWeb) {
      return;
    }
    requireTrustedStatus(await loadSignatureStatus());
  }

  static void requireTrustedStatus(AppSignatureStatus signatureStatus) {
    if (signatureStatus.shouldBlock) {
      throw UnofficialBuildDetected(
        reasonCode: signatureStatus.reasonCode,
        status: signatureStatus.status,
      );
    }
  }

  static String messageForStatus(String status) {
    switch (status) {
      case 'signature_mismatch':
        return L10nService().translate('core_err_signature_mismatch');
      case 'package_info_unavailable':
        return L10nService().translate('core_err_signature_verify_failed');
      default:
        return L10nService().translate('core_err_install_untrusted');
    }
  }

  static List<String> detailsForError(UnofficialBuildDetected error) {
    return [
      messageForStatus(error.status),
      L10nService().translate('core_err_reinstall_official'),
      if (kDebugMode) 'reasonCode=${error.reasonCode}; status=${error.status}',
    ];
  }
}
