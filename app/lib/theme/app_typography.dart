import 'package:flutter/painting.dart';

import 'package:agent_orchestration/theme/app_colors.dart';

abstract final class AppFontFamilies {
  static const String display = 'Avenir Next Condensed';
  static const List<String> displayFallback = <String>[
    'Bahnschrift',
    'Arial Narrow',
  ];
  static const String monospace = 'SF Mono';
  static const List<String> monospaceFallback = <String>[
    'Menlo',
    'Consolas',
    'DejaVu Sans Mono',
    'monospace',
  ];
}

abstract final class AppFontSizes {
  static const double caption = 12;
  static const double small = 14;
  static const double body = 16;
  static const double heading = 20;
  static const double title = 28;
  static const double hero = 40;
}

abstract final class AppLineHeights {
  static const double body = 1.5;
  static const double display = 1.1;
  static const double code = 1.6;
}

abstract final class AppTracking {
  static const double codeEm = 0.08;
}

abstract final class AppTextStyles {
  static const TextStyle body = TextStyle(
    color: AppColors.ink,
    fontSize: AppFontSizes.body,
    fontWeight: FontWeight.w400,
    height: AppLineHeights.body,
  );

  static const TextStyle bodyBold = TextStyle(
    color: AppColors.ink,
    fontSize: AppFontSizes.body,
    fontWeight: FontWeight.w700,
    height: AppLineHeights.body,
  );

  static const TextStyle bodyMuted = TextStyle(
    color: AppColors.inkMuted,
    fontSize: AppFontSizes.body,
    fontWeight: FontWeight.w400,
    height: AppLineHeights.body,
  );

  static const TextStyle small = TextStyle(
    color: AppColors.ink,
    fontSize: AppFontSizes.small,
    fontWeight: FontWeight.w400,
    height: AppLineHeights.body,
  );

  static const TextStyle smallMuted = TextStyle(
    color: AppColors.inkMuted,
    fontSize: AppFontSizes.small,
    fontWeight: FontWeight.w400,
    height: AppLineHeights.body,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.ink,
    fontSize: AppFontSizes.caption,
    fontWeight: FontWeight.w400,
    height: AppLineHeights.body,
  );

  static const TextStyle heading = TextStyle(
    color: AppColors.ink,
    fontSize: AppFontSizes.heading,
    fontWeight: FontWeight.w700,
    height: AppLineHeights.display,
  );

  static const TextStyle pageTitle = TextStyle(
    color: AppColors.ink,
    fontFamily: AppFontFamilies.display,
    fontFamilyFallback: AppFontFamilies.displayFallback,
    fontSize: AppFontSizes.title,
    fontWeight: FontWeight.w700,
    height: AppLineHeights.display,
  );

  static const TextStyle hero = TextStyle(
    color: AppColors.ink,
    fontFamily: AppFontFamilies.display,
    fontFamilyFallback: AppFontFamilies.displayFallback,
    fontSize: AppFontSizes.hero,
    fontWeight: FontWeight.w700,
    height: AppLineHeights.display,
  );

  static const TextStyle displayHeading = TextStyle(
    color: AppColors.ink,
    fontFamily: AppFontFamilies.display,
    fontFamilyFallback: AppFontFamilies.displayFallback,
    fontSize: AppFontSizes.heading,
    fontWeight: FontWeight.w700,
    height: AppLineHeights.display,
  );

  static const TextStyle monospace = TextStyle(
    fontFamily: AppFontFamilies.monospace,
    fontFamilyFallback: AppFontFamilies.monospaceFallback,
  );

  static const TextStyle code = TextStyle(
    color: AppColors.ink,
    fontFamily: AppFontFamilies.monospace,
    fontFamilyFallback: AppFontFamilies.monospaceFallback,
    fontSize: AppFontSizes.small,
    height: AppLineHeights.code,
  );
}
