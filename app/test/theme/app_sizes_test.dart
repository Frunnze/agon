import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/dense_font_size.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

import '../support/random_inputs.dart';

const double _touchControlHeight = 44;
const double _denseControlHeight = 32;
const double _touchIconExtent = 20;
const double _denseIconExtent = 16;
const double _smallIconExtent = 16;

LayoutDensity _randomDensity(Random random) {
  return pickOne(random, LayoutDensity.values);
}

void main() {
  test('test_control_height_for_property_32_dense_44_touch', () {
    final Random random = seededRandom(9301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LayoutDensity density = _randomDensity(random);
      final double expectedHeight = density.isTouch
          ? _touchControlHeight
          : _denseControlHeight;

      expect(
        AppSizes.controlHeightFor(density),
        expectedHeight,
        reason: '$density',
      );
    }
  });

  test('test_icon_for_property_16_dense_20_touch', () {
    final Random random = seededRandom(9302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LayoutDensity density = _randomDensity(random);
      final double expectedExtent = density.isTouch
          ? _touchIconExtent
          : _denseIconExtent;

      expect(AppSizes.iconFor(density), expectedExtent, reason: '$density');
    }
  });

  test('test_extent_for_property_regular_follows_density_small_stays', () {
    final Random random = seededRandom(9303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LayoutDensity density = _randomDensity(random);

      expect(
        AppIconSize.regular.extentFor(density),
        AppSizes.iconFor(density),
      );
      expect(AppIconSize.small.extentFor(density), _smallIconExtent);
    }
  });

  test('test_single_line_field_padding_for_property_fills_the_control', () {
    final Random random = seededRandom(9304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LayoutDensity density = _randomDensity(random);
      final EdgeInsets padding = singleLineFieldPaddingFor(density);
      final double bodyFontSize = fontSizeForDensity(
        regularFontSize: AppFontSizes.body,
        layoutDensity: density,
      );
      final double bodyLineHeight = bodyFontSize * AppLineHeights.body;

      expect(padding.top, padding.bottom, reason: '$density');
      expect(
        padding.vertical + bodyLineHeight,
        AppSizes.controlHeightFor(density),
        reason: '$density',
      );
      expect(padding.left, AppSpacing.space3, reason: '$density');
    }
  });
}
