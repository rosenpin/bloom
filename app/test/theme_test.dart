import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womens_gym/core/theme/app_colors.dart';
import 'package:womens_gym/core/theme/app_theme.dart';

void main() {
  test('light theme exposes the locked colors and font families', () {
    final theme = AppTheme.light;

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.cream);
    expect(theme.colorScheme.primary, AppColors.rose);
    expect(theme.colorScheme.surface, AppColors.paper);
    expect(theme.colorScheme.onSurface, AppColors.ink);
    expect(
      theme.textTheme.displayLarge?.fontFamily,
      AppTheme.displayFontFamily,
    );
    expect(theme.textTheme.bodyLarge?.fontFamily, AppTheme.bodyFontFamily);
    expect(theme.textTheme.labelLarge?.fontFamily, AppTheme.bodyFontFamily);
  });

  test('OKLCH conversions remain pinned to their sRGB constants', () {
    expect(AppColors.blush, const Color(0xFFF4CCCB));
    expect(AppColors.roseDeep, const Color(0xFFA24854));
    expect(AppColors.coral, const Color(0xFFE98667));
    expect(AppColors.sage, const Color(0xFF5B8E6D));
    expect(AppColors.lavender, const Color(0xFF826FA5));
  });
}
