import 'package:flutter/material.dart';

/// Không dựng danh sách với vai/avatar mặc định rồi chèn hàng khi tải xong.
class SettingsInitialContent extends StatelessWidget {
  const SettingsInitialContent({
    super.key,
    required this.ready,
    required this.failed,
    required this.loadingLabel,
    required this.errorLabel,
    required this.retryLabel,
    required this.onRetry,
    required this.builder,
  });

  final bool ready;
  final bool failed;
  final String loadingLabel;
  final String errorLabel;
  final String retryLabel;
  final VoidCallback onRetry;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (ready) return builder(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!failed)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.cloud_off_rounded),
          const SizedBox(height: 16),
          Text(failed ? errorLabel : loadingLabel, textAlign: TextAlign.center),
          if (failed) TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

/// Giữ ảnh qua các lần rebuild/đổi URL, không dùng fade của CircleAvatar.
/// Caller đổi key khi đổi tài khoản/vai để không giữ nhầm ảnh của người trước.
class SettingsAccountAvatar extends StatelessWidget {
  const SettingsAccountAvatar({
    super.key,
    required this.image,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final ImageProvider? image;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.favorite_rounded,
      color: foregroundColor,
      size: 27,
    );
    return ClipOval(
      child: ColoredBox(
        color: backgroundColor,
        child: image == null
            ? Center(child: fallback)
            : Image(
                image: image!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, error, stackTrace) => Center(child: fallback),
              ),
      ),
    );
  }
}
