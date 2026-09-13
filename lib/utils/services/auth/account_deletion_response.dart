import 'dart:convert';
import '../../app_error_mapper.dart';
import '../l10n_service.dart';

Uri accountDeletionSiblingUri(String configuredUrl, String endpoint) {
  final uri = Uri.tryParse(configuredUrl.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.pathSegments.isEmpty ||
      uri.pathSegments.last != 'deleteUserDataHttp' ||
      !const {
        'getOwnAccountDeletionStatusHttp',
        'undoAccountDeletionHttp',
      }.contains(endpoint)) {
    throw const FormatException('invalid_deletion_endpoint');
  }
  return uri.replace(
    pathSegments: [
      ...uri.pathSegments.take(uri.pathSegments.length - 1),
      endpoint,
    ],
  );
}

AppErrorInfo? accountDeletionError(String body) {
  final key = accountDeletionErrorKey(body);
  return key == null
      ? null
      : AppErrorInfo(
          kind: AppErrorKind.user,
          message: L10nService().translate(key),
        );
}

/// Chỉ ánh xạ mã lỗi được biết; không đưa body HTML/chuỗi lạ từ server lên UI.
String? accountDeletionErrorKey(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    return switch (decoded['error']) {
      'app_check_required' => 'account_deletion_app_check_required',
      'deletion_not_cancellable' => 'account_deletion_not_cancellable',
      'deletion_state_conflict' => 'account_deletion_state_conflict',
      'house_state_conflict' => 'account_deletion_state_conflict',
      'house_deletion_already_requested' => 'account_deletion_house_conflict',
      'no_pending_deletion' => 'account_deletion_no_pending',
      'deletion_status_unavailable' => 'account_deletion_status_unavailable',
      _ => null,
    };
  } on FormatException {
    return null;
  }
}
