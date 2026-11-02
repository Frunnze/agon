import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/dot_grid_background.dart';

import '../support/random_inputs.dart';

const double _largestSide = 3000;

void main() {
  test('test_list_dot_grid_centers_property_tiles_cover_the_area', () {
    final Random random = seededRandom(7601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Size area = Size(
        random.nextDouble() * _largestSide,
        random.nextDouble() * _largestSide,
      );
      final List<Offset> centers = listDotGridCenters(area);

      final int columns = (area.width / AppSpacing.space5).ceil();
      final int rows = (area.height / AppSpacing.space5).ceil();
      expect(centers.length, columns * rows, reason: '$area');

      for (final Offset center in centers) {
        final double column =
            (center.dx - AppSpacing.space5 / 2) / AppSpacing.space5;
        final double row =
            (center.dy - AppSpacing.space5 / 2) / AppSpacing.space5;
        expect(column, column.roundToDouble(), reason: '$center');
        expect(row, row.roundToDouble(), reason: '$center');
        expect(column, inInclusiveRange(0, columns - 1));
        expect(row, inInclusiveRange(0, rows - 1));
      }
    }
  });
}
