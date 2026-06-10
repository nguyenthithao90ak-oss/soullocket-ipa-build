import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'pending_upload_service.dart';

typedef PendingUploadRetryHandler = Future<bool> Function(
  PendingUploadSummary pending,
);

class PendingUploadRetryCoordinator {
  PendingUploadRetryCoordinator._();

  static final PendingUploadRetryCoordinator instance =
      PendingUploadRetryCoordinator._();

  final Map<String, PendingUploadRetryHandler> _handlers = {};
  bool _isRetrying = false;

  void registerHandler(String category, PendingUploadRetryHandler handler) {
    final normalized = category.trim();
    if (normalized.isEmpty) return;
    _handlers[normalized] = handler;
  }

  void unregisterHandler(String category) {
    final normalized = category.trim();
    if (normalized.isEmpty) return;
    _handlers.remove(normalized);
  }

  Future<void> retryPendingUploads({
    int maxRetryPerItem = 3,
  }) async {
    if (_isRetrying) return;
    _isRetrying = true;
    try {
      final pendingUploads =
          await PendingUploadService.instance.listSummaries();
      for (final pending in pendingUploads) {
        if (pending.retryCount >= maxRetryPerItem) continue;
        final handler = _handlers[pending.category];
        if (handler == null) continue;
        try {
          final handled = await handler(pending);
          if (!handled) {
            await PendingUploadService.instance.markFailed(
              pending.key,
              'Pending upload retry was not handled.',
            );
          }
        } catch (error) {
          debugPrint(
            '[PendingUploadRetryCoordinator] retry failed: ${AppErrorMapper.resolve(
              error,
              fallbackMessage: 'Không thể thử lại upload đang chờ.',
            ).message}',
          );
          await PendingUploadService.instance.markFailed(pending.key, error);
        }
      }
    } finally {
      _isRetrying = false;
    }
  }
}
