import 'package:flutter/material.dart';

/// Optimized swipe physics for PageViews and TabBarViews across the app.
/// Provides a sensitive and fluid swiping experience.
class SLPagePhysics extends PageScrollPhysics {
  static const double _pageSwitchThreshold = 0.32;
  static const double _dragThreshold = 3.0;
  static const double _minFlingDistanceMultiplier = 0.75;
  static const double _minFlingVelocityMultiplier = 0.80;

  const SLPagePhysics({super.parent});

  @override
  SLPagePhysics applyTo(ScrollPhysics? ancestor) {
    return SLPagePhysics(parent: buildParent(ancestor));
  }

  double _getPage(ScrollMetrics position) {
    if (position is PageMetrics) {
      return position.page ?? 0.0;
    }
    final safeViewport =
        position.viewportDimension == 0 ? 1.0 : position.viewportDimension;
    return position.pixels / safeViewport;
  }

  double _getPixels(ScrollMetrics position, double page) {
    final viewportFraction =
        position is PageMetrics ? position.viewportFraction : 1.0;
    final safeViewport = (position.viewportDimension * viewportFraction) == 0
        ? 1.0
        : (position.viewportDimension * viewportFraction);
    return page * safeViewport;
  }

  double _getTargetPixels(ScrollMetrics position, double velocity) {
    final page = _getPage(position);
    final basePage = page.floorToDouble();

    double targetPage;
    if (velocity >= minFlingVelocity) {
      targetPage = basePage + 1.0;
    } else if (velocity <= -minFlingVelocity) {
      targetPage = page.ceilToDouble() - 1.0;
    } else {
      final pageFraction = page - basePage;
      targetPage =
          pageFraction >= _pageSwitchThreshold ? basePage + 1.0 : basePage;
    }

    final targetPixels = _getPixels(position, targetPage);
    if (targetPixels < position.minScrollExtent) {
      return position.minScrollExtent;
    }
    if (targetPixels > position.maxScrollExtent) {
      return position.maxScrollExtent;
    }
    return targetPixels;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final target = _getTargetPixels(position, velocity);
    if ((target - position.pixels).abs() <= tolerance.distance) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  double get minFlingDistance =>
      super.minFlingDistance * _minFlingDistanceMultiplier;

  @override
  double get minFlingVelocity =>
      super.minFlingVelocity * _minFlingVelocityMultiplier;

  @override
  double? get dragStartDistanceMotionThreshold => _dragThreshold;
}
