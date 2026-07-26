import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';

abstract final class AppTheme {
  static const String displayFontFamily = 'YoungSerif';
  static const String bodyFontFamily = 'WixMadeforText';

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.rose,
    onPrimary: AppColors.paper,
    primaryContainer: AppColors.blushSoft,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.coral,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.blush,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.sage,
    onTertiary: AppColors.paper,
    tertiaryContainer: AppColors.sageSoft,
    onTertiaryContainer: AppColors.ink,
    error: AppColors.roseDeep,
    onError: AppColors.paper,
    errorContainer: AppColors.blushSoft,
    onErrorContainer: AppColors.ink,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    surfaceDim: AppColors.cream,
    surfaceBright: AppColors.paper,
    surfaceContainerLowest: AppColors.paper,
    surfaceContainerLow: AppColors.cream,
    surfaceContainer: AppColors.blushSoft,
    surfaceContainerHigh: AppColors.blush,
    surfaceContainerHighest: AppColors.line,
    onSurfaceVariant: AppColors.inkSoft,
    outline: AppColors.inkFaint,
    outlineVariant: AppColors.line,
    shadow: AppColors.ink,
    scrim: AppColors.ink,
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.paper,
    inversePrimary: AppColors.blush,
    surfaceTint: AppColors.rose,
  );

  static ThemeData get light {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: bodyFontFamily,
    );
    final bodyTheme = base.textTheme.apply(
      fontFamily: bodyFontFamily,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    final textTheme = bodyTheme.copyWith(
      displayLarge: bodyTheme.displayLarge?.copyWith(
        fontFamily: displayFontFamily,
      ),
      displayMedium: bodyTheme.displayMedium?.copyWith(
        fontFamily: displayFontFamily,
      ),
      displaySmall: bodyTheme.displaySmall?.copyWith(
        fontFamily: displayFontFamily,
      ),
      headlineLarge: bodyTheme.headlineLarge?.copyWith(
        fontFamily: displayFontFamily,
      ),
      headlineMedium: bodyTheme.headlineMedium?.copyWith(
        fontFamily: displayFontFamily,
      ),
      headlineSmall: bodyTheme.headlineSmall?.copyWith(
        fontFamily: displayFontFamily,
      ),
      titleLarge: bodyTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: bodyTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: bodyTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: bodyTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: bodyTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: bodyTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      canvasColor: AppColors.cream,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mediumBorder),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.paper,
        elevation: 0,
        height: 76,
        indicatorColor: AppColors.blushSoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.roseDeep
                : AppColors.inkFaint,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.roseDeep
                : AppColors.inkSoft,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: AppColors.paper,
          disabledBackgroundColor: AppColors.blushSoft,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.mediumBorder,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkSoft,
          side: const BorderSide(color: AppColors.line),
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.mediumBorder,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      dividerColor: AppColors.line,
    );
  }
}
