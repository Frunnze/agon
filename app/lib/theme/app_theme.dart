import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const double _fieldVerticalPadding =
    (AppSizes.controlHeight - AppFontSizes.body * AppLineHeights.body) / 2;

ThemeData buildAppTheme() {
  const ColorScheme colorScheme = ColorScheme.dark(
    primary: AppColors.action,
    onPrimary: AppColors.paper,
    secondary: AppColors.action,
    error: AppColors.danger,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
  );

  const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(AppRadii.control),
  );

  const InputDecorationThemeData inputDecorationTheme =
      InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.raised,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: _fieldVerticalPadding,
        ),
        hintStyle: TextStyle(color: AppColors.inkMuted),
        border: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: AppColors.lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: AppColors.lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(
            color: AppColors.action,
            width: AppBorders.selected,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: AppColors.danger),
        ),
      );

  return ThemeData(
    brightness: Brightness.dark,
    visualDensity: VisualDensity.standard,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.paper,
    canvasColor: AppColors.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: AppColors.transparent,
    hoverColor: AppColors.sunken,
    focusColor: AppColors.actionTint,
    dividerColor: AppColors.line,
    textTheme: const TextTheme(
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.small,
      titleMedium: AppTextStyles.body,
    ),
    inputDecorationTheme: inputDecorationTheme,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.action,
    ),
  );
}
