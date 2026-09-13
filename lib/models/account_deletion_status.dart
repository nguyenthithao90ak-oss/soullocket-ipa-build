/// Bản sao chỉ để hiển thị; máy chủ vẫn quyết định quyền hủy bằng transaction.
class AccountDeletionStatus {
  const AccountDeletionStatus({
    required this.requesterUid,
    required this.scheduledAtMs,
    required this.status,
    this.cancellationAllowed,
    this.requiresReconciliation = false,
    this.pendingIssue,
  });

  final String requesterUid;
  final int scheduledAtMs;
  final String status;
  final bool? cancellationAllowed;
  final bool requiresReconciliation;
  final String? pendingIssue;

  bool get canCancel =>
      !requiresReconciliation &&
      (cancellationAllowed ??
          const {
            '', // Bản sao legacy chưa có trạng thái; endpoint sẽ xác minh lại.
            'initializing',
            'single_delete',
            'partner_wait',
            'partner_approved',
          }.contains(status));

  String messageKey({required bool isMine}) {
    if (requiresReconciliation) return 'account_deletion_review';
    if (status == 'processing') return 'account_deletion_processing';
    if (status == 'initializing') return 'account_deletion_initializing';
    if (!canCancel) return 'account_deletion_state_conflict';
    if (pendingIssue == 'data_review') {
      return isMine ? 'account_deletion_pending_review_self' : 'account_deletion_pending_review_partner';
    }
    if (pendingIssue == 'service_unavailable') {
      return isMine ? 'account_deletion_pending_service_self' : 'account_deletion_pending_service_partner';
    }
    return isMine
        ? 'account_deletion_pending_self'
        : 'account_deletion_pending_partner';
  }

  static AccountDeletionStatus? fromOwnResponse(
    Object? value, {
    required String uid,
  }) {
    if (value is! Map || value['ok'] != true || !value.containsKey('request')) {
      throw const FormatException('invalid_deletion_status_response');
    }
    final request = value['request'];
    if (request == null) return null;
    if (uid.isEmpty ||
        request is! Map ||
        request['uid'] != uid ||
        request['status'] is! String ||
        request['canCancel'] is! bool ||
        request['requiresReconciliation'] is! bool ||
        request['scheduledAt'] is! num) {
      throw const FormatException('invalid_deletion_status_response');
    }
    final date = request['scheduledAt'] as num;
    final status = request['status'] as String;
    final review = request['requiresReconciliation'] as bool;
    final issue = request['pendingIssue'];
    if (issue != null && issue != 'data_review' && issue != 'service_unavailable') {
      throw const FormatException('invalid_deletion_status_response');
    }
    if (!date.isFinite ||
        date < 0 ||
        date > 8640000000000000 ||
        date != date.truncateToDouble() ||
        (date == 0 && !review)) {
      throw const FormatException('invalid_deletion_status_response');
    }
    if ((status == 'cancelled' || status == 'completed') && !review) {
      return null;
    }
    return AccountDeletionStatus(
      requesterUid: uid,
      scheduledAtMs: date.toInt(),
      status: status,
      cancellationAllowed:
          request['canCancel'] == true &&
          const {
            'initializing',
            'single_delete',
            'partner_wait',
            'partner_approved',
          }.contains(status),
      requiresReconciliation: review,
      pendingIssue: issue as String?,
    );
  }

  static AccountDeletionStatus? fromHouseFields({
    Object? mirror,
    Object? scheduledAt,
    Object? requesterUid,
  }) {
    final map = mirror is Map ? mirror : const {};
    final status = map['status'] is String ? (map['status'] as String) : '';
    if (status == 'cancelled' || status == 'completed') return null;
    // Bản sao mới chứa cả UID/ngày trong một snapshot nguyên tử.
    final rawDate = map.containsKey('scheduledAt')
        ? map['scheduledAt']
        : scheduledAt;
    final rawUid = map.containsKey('uid') ? map['uid'] : requesterUid;
    final date = rawDate is num ? rawDate : num.tryParse('$rawDate');
    if (date == null ||
        !date.isFinite ||
        date <= 0 ||
        date > 8640000000000000 ||
        date != date.truncateToDouble() ||
        rawUid is! String ||
        rawUid.trim().isEmpty) {
      return null;
    }
    // Không tự ẩn sau hạn: scheduler có thể chưa claim hoặc đang đối chiếu lỗi.
    return AccountDeletionStatus(
      requesterUid: rawUid.trim(),
      scheduledAtMs: date.toInt(),
      status: status,
      pendingIssue: const {'data_review', 'service_unavailable'}.contains(map['pendingIssue'])
          ? map['pendingIssue'] as String : null,
    );
  }
}
