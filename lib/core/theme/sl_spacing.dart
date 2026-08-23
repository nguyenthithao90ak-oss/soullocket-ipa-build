import 'package:flutter/material.dart';

class SLSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const all4 = EdgeInsets.all(xxs);
  static const all8 = EdgeInsets.all(xs);
  static const all12 = EdgeInsets.all(sm);
  static const all16 = EdgeInsets.all(md);
  static const all20 = EdgeInsets.all(lg);
  static const all24 = EdgeInsets.all(xl);
  static const all32 = EdgeInsets.all(xxl);

  static const h4 = SizedBox(height: xxs);
  static const h6 = SizedBox(height: 6);
  static const h8 = SizedBox(height: xs);
  static const h10 = SizedBox(height: 10);
  static const h12 = SizedBox(height: sm);
  static const h16 = SizedBox(height: md);
  static const h20 = SizedBox(height: lg);
  static const h24 = SizedBox(height: xl);
  static const h32 = SizedBox(height: xxl);

  static const w4 = SizedBox(width: xxs);
  static const w8 = SizedBox(width: xs);
  static const w10 = SizedBox(width: 10);
  static const w12 = SizedBox(width: sm);
  static const w16 = SizedBox(width: md);
  static const w20 = SizedBox(width: lg);
  static const w24 = SizedBox(width: xl);
  static const w32 = SizedBox(width: xxl);

  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  static EdgeInsets symmetric({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  static EdgeInsets fromLTRB(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  static SizedBox gapH(double value) => SizedBox(height: value);
  static SizedBox gapW(double value) => SizedBox(width: value);
}


