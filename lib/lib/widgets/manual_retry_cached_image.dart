import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'cute_loading_indicator.dart';
import '../core/sl_theme.dart';
import '../utils/services/l10n_service.dart';

class ManualRetryCachedImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color backgroundColor;
  final String retryLabel;

  const ManualRetryCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.backgroundColor = const Color(0xFF111827),
    this.retryLabel = 'core_retry',
  });

  @override
  State<ManualRetryCachedImage> createState() => _ManualRetryCachedImageState();
}

class _ManualRetryCachedImageState extends State<ManualRetryCachedImage> {
  bool _hasError = false;
  int _retryToken = 0;

  @override
  void didUpdateWidget(covariant ManualRetryCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasError = false;
      _retryToken = 0;
    }
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _retryToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();
    if (widget.imageUrl.isEmpty) return const SizedBox.shrink();

    if (_hasError) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: widget.backgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white70),
              SLSpacing.h8,
              Text(
                l10n.translate('core_image_load_failed'),
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              SLSpacing.h8,
              OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.translate(widget.retryLabel)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(
                    borderRadius: SLRadius.pillAll,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CachedNetworkImage(
      key: ValueKey('${widget.imageUrl}#$_retryToken'),
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      filterQuality: FilterQuality.medium,
      placeholder: (context, url) => Container(
        width: widget.width,
        height: widget.height,
        color: widget.backgroundColor,
        child: const Center(
          child: CuteLoadingIndicator(color: Color(0xFFFFB300)),
        ),
      ),
      errorWidget: (context, url, error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_hasError) return;
          setState(() => _hasError = true);
        });
        return Container(
          width: widget.width,
          height: widget.height,
          color: widget.backgroundColor,
        );
      },
    );
  }
}
