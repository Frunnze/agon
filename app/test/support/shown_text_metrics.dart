import 'package:flutter/painting.dart';

import 'package:agent_orchestration/theme/dense_font_size.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

import 'widget_harness.dart';

double shownFontSizeAtWidth({
  required TextStyle style,
  required double windowWidth,
}) {
  return fontSizeForDensity(
    regularFontSize: style.fontSize!,
    layoutDensity: densityMeantByWidth(windowWidth),
  );
}

double shownLineHeightFor({
  required TextStyle style,
  required LayoutDensity layoutDensity,
}) {
  final double shownFontSize = fontSizeForDensity(
    regularFontSize: style.fontSize!,
    layoutDensity: layoutDensity,
  );
  final double unroundedLineHeight = shownFontSize * style.height!;
  return unroundedLineHeight.roundToDouble();
}

double shownLineHeightAtWidth({
  required TextStyle style,
  required double windowWidth,
}) {
  return shownLineHeightFor(
    style: style,
    layoutDensity: densityMeantByWidth(windowWidth),
  );
}
