import 'package:flutter/painting.dart';

import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/dense_font_size.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

class DenseTextScaler extends TextScaler {
  const DenseTextScaler({required this.platformTextScaler});

  final TextScaler platformTextScaler;

  @override
  double scale(double fontSize) {
    final double denseFontSize = denseFontSizeFor(fontSize);
    return platformTextScaler.scale(denseFontSize);
  }

  @override
  double get textScaleFactor {
    return scale(AppFontSizes.body) / AppFontSizes.body;
  }

  @override
  bool operator ==(Object other) {
    return other is DenseTextScaler &&
        other.platformTextScaler == platformTextScaler;
  }

  @override
  int get hashCode => platformTextScaler.hashCode;
}

TextScaler textScalerFor({
  required LayoutDensity layoutDensity,
  required TextScaler platformTextScaler,
}) {
  if (layoutDensity.isTouch) {
    return platformTextScaler;
  }
  return DenseTextScaler(platformTextScaler: platformTextScaler);
}
