import 'package:flutter/painting.dart';

import 'package:agent_orchestration/theme/app_typography.dart';

double codeLetterSpacingFor({
  required TextScaler textScaler,
  required double fontSize,
}) {
  final double shownFontSize = textScaler.scale(fontSize);
  return shownFontSize * AppTracking.codeEm;
}
