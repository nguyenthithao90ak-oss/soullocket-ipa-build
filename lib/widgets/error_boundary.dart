import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(FlutterErrorDetails details)? fallbackBuilder;
  final void Function(FlutterErrorDetails details)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (details) {
      if (mounted) {
        setState(() => _errorDetails = details);
      }
      widget.onError?.call(details);
      unawaited(ErrorLoggerService.instance.logError(
        details.exception,
        details.stack,
        reason: 'ErrorBoundary',
        fatal: false,
      ));
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      if (widget.fallbackBuilder != null) {
        return widget.fallbackBuilder!(_errorDetails!);
      }
      return _DefaultErrorFallback(details: _errorDetails!);
    }
    return widget.child;
  }
}

class _DefaultErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;
  const _DefaultErrorFallback({required this.details});

  @override
  Widget build(BuildContext context) {
    final l10n = L10nService();

    return Material(
      color: SLColors.darkBgMain,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: SLColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  color: SLColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.translate('core_err_widget_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SLColors.darkTextPrimary,
                  decoration: TextDecoration.none,
                  fontFamily: 'Quicksand',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.translate('core_err_widget_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: SLColors.darkTextSecond,
                  decoration: TextDecoration.none,
                  fontFamily: 'Quicksand',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  try {
                    SystemNavigator.pop();
                  } catch (_) {}
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(l10n.translate('core_err_widget_close')),
                style: FilledButton.styleFrom(
                  backgroundColor: SLColors.primary,
                  foregroundColor: SLColors.textInverse,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SLRadius.sm),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SLColors.darkBgCard,
                    borderRadius: BorderRadius.circular(SLRadius.sm),
                    border: Border.all(color: SLColors.darkBorder),
                  ),
                  child: Text(
                    details.exception.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: SLColors.darkTextSecond,
                      decoration: TextDecoration.none,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
