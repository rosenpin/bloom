import 'dart:math' as math;

import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Space under a screen's bottom-most control. The home indicator's inset
  /// already keeps it clear of the edge, so no margin is stacked on top of
  /// it; a screen without an inset gets a small one. Use it with
  /// `SafeArea(bottom: false)`, so a pinned zone's background can run to the
  /// edge while its controls stay above the inset.
  static double bottomEdge(BuildContext context) =>
      math.max(MediaQuery.paddingOf(context).bottom, sm);
}
