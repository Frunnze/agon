import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_theme.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';

import '../support/random_inputs.dart';

void main() {
  test('test_for_width_property_breakpoints_at_768_and_1024', () {
    final Random random = seededRandom(2701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double width = random.nextDouble() * 2000;
      final LayoutSize size = LayoutSize.forWidth(width);

      expect(size.isCompact, width < 768);
      expect(size.isLarge, width >= 1024);
    }
  });

  test('test_page_padding_for_property_grows_with_layout_size', () {
    double previousHorizontal = 0;
    double previousGap = 0;

    for (final LayoutSize size in LayoutSize.values) {
      final EdgeInsets padding = pagePaddingFor(size);
      final double gap = pageGapFor(size);
      expect(padding.left >= previousHorizontal, isTrue);
      expect(gap >= previousGap, isTrue);
      previousHorizontal = padding.left;
      previousGap = gap;
    }
  });

  test('test_build_app_theme_property_dark_paper_background', () {
    final ThemeData theme = buildAppTheme();

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.paper);
    expect(theme.colorScheme.primary, AppColors.action);
  });
}
