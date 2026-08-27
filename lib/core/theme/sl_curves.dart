import 'package:flutter/material.dart';

extension SLCurves on Curves {
  static const Curve easeOutQuicksand = Cubic(0.23, 1, 0.32, 1);
  static const Curve easeInQuicksand = Cubic(0.755, 0.05, 0.855, 0.06);
}

/// Extended animation curves cho Aurora Soft redesign.
/// Bổ sung các curves đặc biệt cho heart reactions, spring animations.
class SLAnimationCurves {
  const SLAnimationCurves._();

  /// Overshoot nhẹ cho heart reactions, like animations
  /// Tạo cảm giác "bounce" đáng yêu cho UI interactions
  static const Curve soulSpring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Apple-style spring cho UI interactions mượt mà
  static const Curve gentleSpring = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Material 3 emphasized — entrance animations
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Material 3 emphasized decelerate — exit animations
  static const Curve decelerateEmphasized = Cubic(0.05, 0.7, 0.1, 1.0);
}
