import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/dense_font_size.dart';
import 'package:agent_orchestration/theme/dense_text_scaler.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

import '../support/random_inputs.dart';

const double _largestSampledFontSize = 60;
const double _largestPlatformScale = 3;

TextScaler _randomPlatformTextScaler(Random random) {
  return TextScaler.linear(0.5 + random.nextDouble() * _largestPlatformScale);
}

void main() {
  test('test_scale_property_applies_the_platform_scale_after_density', () {
    final Random random = seededRandom(9201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TextScaler platformTextScaler = _randomPlatformTextScaler(random);
      final double fontSize = random.nextDouble() * _largestSampledFontSize;
      final DenseTextScaler denseTextScaler = DenseTextScaler(
        platformTextScaler: platformTextScaler,
      );
      final double expectedSize = platformTextScaler.scale(
        denseFontSizeFor(fontSize),
      );

      expect(denseTextScaler.scale(fontSize), expectedSize, reason: '$i');
    }
  });

  test('test_dense_text_scaler_property_equal_for_equal_platforms', () {
    final Random random = seededRandom(9202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double platformScale = 0.5 + random.nextDouble();
      final DenseTextScaler first = DenseTextScaler(
        platformTextScaler: TextScaler.linear(platformScale),
      );
      final DenseTextScaler second = DenseTextScaler(
        platformTextScaler: TextScaler.linear(platformScale),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    }
  });

  test('test_text_scaler_for_property_only_touch_keeps_the_platform', () {
    final Random random = seededRandom(9203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LayoutDensity density = pickOne(random, LayoutDensity.values);
      final TextScaler platformTextScaler = _randomPlatformTextScaler(random);
      final TextScaler expectedTextScaler = density.isTouch
          ? platformTextScaler
          : DenseTextScaler(platformTextScaler: platformTextScaler);

      expect(
        textScalerFor(
          layoutDensity: density,
          platformTextScaler: platformTextScaler,
        ),
        expectedTextScaler,
        reason: '$density',
      );
    }
  });
}
