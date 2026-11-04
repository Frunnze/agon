import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/dense_text_scaler.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

Widget applyLayoutDensity(BuildContext context, Widget? child) {
  if (child == null) {
    throw ArgumentError.notNull('child');
  }

  final LayoutDensity layoutDensity = LayoutDensity.of(context);
  final MediaQueryData mediaQuery = MediaQuery.of(context);
  final TextScaler textScaler = textScalerFor(
    layoutDensity: layoutDensity,
    platformTextScaler: mediaQuery.textScaler,
  );

  final ThemeData appTheme = Theme.of(context);
  final InputDecorationThemeData fieldTheme = appTheme.inputDecorationTheme
      .copyWith(contentPadding: singleLineFieldPaddingFor(layoutDensity));
  final ThemeData densityTheme = appTheme.copyWith(
    inputDecorationTheme: fieldTheme,
  );

  return MediaQuery(
    data: mediaQuery.copyWith(textScaler: textScaler),
    child: Theme(data: densityTheme, child: child),
  );
}
