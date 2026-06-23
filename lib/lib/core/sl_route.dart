import 'package:flutter/material.dart';

/// Custom page route với slide từ phải + fade nhẹ.
/// Thay thế MaterialPageRoute để transition mượt hơn trên cả Android & iOS.
///
/// Dùng:
///   Navigator.of(context).push(SLRoute(builder: (_) => TargetScreen()));
class SLRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  SLRoute({
    required this.builder,
    super.settings,
    Duration duration = const Duration(milliseconds: 280),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide từ phải sang trái
            final slide = Tween<Offset>(
              begin: const Offset(1.0, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );

            // Fade nhẹ
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
              ),
            );

            // Màn hình cũ mờ dần + dịch nhẹ sang trái
            final secondarySlide = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.08, 0),
            ).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeInOut,
              ),
            );

            return SlideTransition(
              position: secondarySlide,
              child: FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: slide,
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Shorthand push helper — thay Navigator.of(context).push(MaterialPageRoute(...))
Future<T?> slPush<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    SLRoute<T>(builder: (_) => screen),
  );
}
