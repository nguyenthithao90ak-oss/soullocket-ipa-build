import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';

/// Trạng thái lỗi tải chat, không hiển thị lỗi kỹ thuật hoặc dữ liệu riêng tư.
class ChatMessageRetryNotice extends StatelessWidget {
  const ChatMessageRetryNotice({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.translate('core_err_general'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onErrorContainer),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.translate('core_retry')),
            ),
          ],
        ),
      ),
    );
  }
}
