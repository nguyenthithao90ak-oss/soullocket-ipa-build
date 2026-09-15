import 'package:flutter/material.dart';

/// Trạng thái mạng tách khỏi tin nhắn AI để không bị lưu/báo cáo như lời model.
class AiTaskStatusBanner extends StatelessWidget {
  const AiTaskStatusBanner({
    super.key,
    required this.message,
    required this.checkLabel,
    required this.dismissLabel,
    required this.busy,
    this.onDismiss,
    this.onCheck,
  });
  final String message;
  final String checkLabel;
  final String dismissLabel;
  final bool busy;
  final VoidCallback? onCheck;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6CC9B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Color(0xFF584729))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              if (onCheck != null)
                TextButton.icon(
                  onPressed: busy ? null : onCheck,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(checkLabel),
                ),
              if (onDismiss != null)
                TextButton(
                  onPressed: busy ? null : onDismiss,
                  child: Text(dismissLabel),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
