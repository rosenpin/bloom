import 'package:flutter/material.dart';

/// Brand colors converted from the locked OKLCH palette to clipped sRGB.
///
/// The source values stay beside each constant so future design changes start
/// from the perceptual color rather than round-tripping the sRGB approximation.
abstract final class AppColors {
  /// Source: `oklch(97.5% .010 45)`.
  static const cream = Color(0xFFFDF5F1);

  /// Source: `oklch(99% .006 45)`.
  static const paper = Color(0xFFFFFBF8);

  /// Source: `oklch(88% .045 20)`.
  static const blush = Color(0xFFF4CCCB);

  /// Source: `oklch(94% .025 22)`.
  static const blushSoft = Color(0xFFFCE5E4);

  /// Source: `oklch(63% .120 16)`.
  static const rose = Color(0xFFC76870);

  /// Source: `oklch(52% .120 14)`.
  static const roseDeep = Color(0xFFA24854);

  /// Source: `oklch(72% .130 38)`.
  static const coral = Color(0xFFE98667);

  /// Source: `oklch(31% .028 22)`.
  static const ink = Color(0xFF3D2B2A);

  /// Source: `oklch(50% .030 24)`.
  static const inkSoft = Color(0xFF745D5B);

  /// Source: `oklch(64% .022 26)`.
  static const inkFaint = Color(0xFF998785);

  /// Source: `oklch(90% .015 35)`.
  static const line = Color(0xFFE8DBD7);

  /// Source: `oklch(60% .075 155)`.
  static const sage = Color(0xFF5B8E6D);

  /// Source: `oklch(93% .028 155)`.
  static const sageSoft = Color(0xFFDAEEE0);

  /// Source: `oklch(58% .085 300)`.
  static const lavender = Color(0xFF826FA5);

  /// Source: `oklch(94% .025 300)`.
  static const lavenderSoft = Color(0xFFEDE8FA);
}
