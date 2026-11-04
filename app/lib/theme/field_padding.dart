import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/dense_font_size.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

const EdgeInsets multiLineFieldPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.space3,
  vertical: AppSpacing.space2 + AppBorders.thin,
);

EdgeInsets singleLineFieldPaddingFor(LayoutDensity layoutDensity) {
  final double bodyFontSize = fontSizeForDensity(
    regularFontSize: AppFontSizes.body,
    layoutDensity: layoutDensity,
  );
  final double bodyLineHeight = bodyFontSize * AppLineHeights.body;
  final double controlHeight = AppSizes.controlHeightFor(layoutDensity);
  final double verticalPadding = (controlHeight - bodyLineHeight) / 2;

  return EdgeInsets.symmetric(
    horizontal: AppSpacing.space3,
    vertical: verticalPadding,
  );
}
