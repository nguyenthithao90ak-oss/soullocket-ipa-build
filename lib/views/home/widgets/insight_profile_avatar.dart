import 'package:flutter/material.dart';

import '../../../utils/home_image_policy.dart';
import '../../../utils/services/home_startup_media_cache.dart';
import '../../../utils/services/l10n_service.dart';

class InsightProfileAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final double size;
  final Color accent;

  const InsightProfileAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.size = 58,
    this.accent = const Color(0xFF99516B),
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl.trim();
    final startupFile = HomeStartupMediaCache.getFile(url);
    final background = Color.lerp(Colors.white, accent, 0.12)!;
    final loading = ColoredBox(
      key: const ValueKey('avatar-loading'),
      color: background,
      child: Center(
        child: SizedBox.square(
          dimension: size * 0.3,
          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
        ),
      ),
    );
    final missing = ColoredBox(
      key: const ValueKey('avatar-missing'),
      color: background,
      child: Icon(Icons.person_rounded, color: accent, size: size * 0.45),
    );
    final failed = Tooltip(
      message: context.tr('core_image_load_failed'),
      child: ColoredBox(
        key: const ValueKey('avatar-unavailable'),
        color: background,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: accent,
          size: size * 0.38,
        ),
      ),
    );

    Widget cachedOr(Widget fallback) {
      if (startupFile == null) return fallback;
      return Image(
        key: ValueKey('avatar-startup-$url'),
        image: HomeImagePolicy.resized(
          FileImage(startupFile),
          width: HomeImagePolicy.avatarPixels,
          height: HomeImagePolicy.avatarPixels,
        ),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    Widget buildNetworkImage() {
      return Image.network(
        url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => cachedOr(failed),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return cachedOr(loading);
        },
      );
    }

    return Semantics(
      image: true,
      label: name,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: ClipOval(
          child: ExcludeSemantics(
            child: url.isEmpty
                ? missing
                : url.startsWith('assets/')
                ? Image.asset(
                    url,
                    key: ValueKey(url),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => failed,
                  )
                : buildNetworkImage(),
          ),
        ),
      ),
    );
  }
}
