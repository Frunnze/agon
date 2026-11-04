import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/dense_font_size.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

import '../support/random_inputs.dart';

const double _largestSampledFontSize = 120;
const List<({double regular, double dense})> _designSizes =
    <({double regular, double dense})>[
      (regular: 12, dense: 12),
      (regular: 14, dense: 13),
      (regular: 16, dense: 14),
      (regular: 20, dense: 17),
      (regular: 28, dense: 22),
      (regular: 40, dense: 40),
    ];

void main() {
  test('test_dense_font_size_for_property_matches_the_design_sizes', () {
    for (final ({double regular, double dense}) designSize in _designSizes) {
      expect(
        denseFontSizeFor(designSize.regular),
        designSize.dense,
        reason: '${designSize.regular}',
      );
    }
  });

  test('test_dense_font_size_for_property_keeps_the_size_order', () {
    final Random random = seededRandom(9101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double smallerSize = random.nextDouble() * _largestSampledFontSize;
      final double largerSize =
          smallerSize + random.nextDouble() * _largestSampledFontSize;

      expect(
        denseFontSizeFor(smallerSize),
        lessThanOrEqualTo(denseFontSizeFor(largerSize)),
        reason: '$smallerSize and $largerSize',
      );
    }
  });

  test('test_dense_font_size_for_property_never_grows_a_size', () {
    final Random random = seededRandom(9102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double fontSize = random.nextDouble() * _largestSampledFontSize;

      expect(
        denseFontSizeFor(fontSize),
        lessThanOrEqualTo(fontSize),
        reason: '$fontSize',
      );
    }
  });

  test('test_dense_font_size_for_property_rejects_negative_sizes', () {
    final Random random = seededRandom(9103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double negativeSize =
          -(1 + random.nextDouble() * _largestSampledFontSize);

      expect(() => denseFontSizeFor(negativeSize), throwsArgumentError);
    }
  });

  test('test_font_size_for_density_property_only_touch_keeps_the_size', () {
    final Random random = seededRandom(9104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LayoutDensity density = pickOne(random, LayoutDensity.values);
      final double regularFontSize = pickOne(random, <double>[
        AppFontSizes.caption,
        AppFontSizes.small,
        AppFontSizes.body,
        AppFontSizes.heading,
        AppFontSizes.title,
      ]);
      final double expectedFontSize = density.isTouch
          ? regularFontSize
          : denseFontSizeFor(regularFontSize);

      expect(
        fontSizeForDensity(
          regularFontSize: regularFontSize,
          layoutDensity: density,
        ),
        expectedFontSize,
        reason: '$density',
      );
    }
  });
}
