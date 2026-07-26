import 'package:flutter/material.dart';

import 'app_colors.dart';

ThemeData buildReviewTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.rose,
      brightness: Brightness.light,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: AppColors.cream,
    fontFamily: 'WixMadeforText',
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.roseDeep,
      secondary: AppColors.coral,
      surface: AppColors.paper,
      outline: AppColors.line,
      onSurface: AppColors.ink,
    ),
    dividerColor: AppColors.line,
    cardTheme: const CardThemeData(
      color: AppColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.line),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.roseDeep,
      unselectedLabelColor: AppColors.inkSoft,
      indicatorColor: AppColors.rose,
      dividerColor: AppColors.line,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontFamily: 'YoungSerif',
            color: AppColors.ink,
            fontWeight: FontWeight.w400,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: 'YoungSerif',
            color: AppColors.ink,
            fontWeight: FontWeight.w400,
          ),
        ),
  );
}
