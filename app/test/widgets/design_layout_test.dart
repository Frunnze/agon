import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/stacked_list_row.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/route_line.dart';
import 'package:agent_orchestration/widgets/route_line_painter.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const double _factGap = AppSpacing.space3;
const int _mostFacts = 6;

int _expectedFactColumns({required double width, required int factCount}) {
  final int fittingColumns =
      ((width + _factGap) / (AppSizes.factColumnMinimumWidth + _factGap))
          .floor();
  return max(1, min(fittingColumns, factCount));
}

List<Fact> _buildFacts(int count) {
  return <Fact>[
    for (int index = 0; index < count; index += 1)
      Fact(
        term: 'Term $index',
        description: <TextSegment>[TextSegment('Value $index')],
      ),
  ];
}

void main() {
  testWidgets('test_fact_row_property_columns_follow_the_design_grid', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      final int factCount = 1 + random.nextInt(_mostFacts);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: FactRow(facts: _buildFacts(factCount)),
      );

      final double rowWidth = tester.getSize(find.byType(FactRow)).width;
      final int columns = _expectedFactColumns(
        width: rowWidth,
        factCount: factCount,
      );
      final double columnWidth =
          (rowWidth - (columns - 1) * _factGap) / columns;
      final Rect firstFact = tester.getRect(find.text('Term 0'));
      for (int index = 0; index < factCount; index += 1) {
        final Rect fact = tester.getRect(find.text('Term $index'));
        final int column = index % columns;
        final double expectedLeft =
            firstFact.left + column * (columnWidth + _factGap);
        final String reason = 'width $width, $factCount facts, fact $index';
        expect(fact.left, closeTo(expectedLeft, 0.5), reason: reason);
      }
    }
  });

  testWidgets('test_route_line_property_link_fills_the_space_between_names', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: RouteLine(
          startName: 'mac-mini',
          endName: 'air-laptop',
          path: pickOne(random, RoutePath.values),
          badgeLabel: 'Same network',
          badgeIcon: AppIconKind.lock,
        ),
      );

      final Rect line = tester.getRect(find.byType(RouteLine));
      final Rect start = tester.getRect(find.text('mac-mini'));
      final Rect end = tester.getRect(find.text('air-laptop'));
      final String reason = 'width $width';
      expect(start.left, closeTo(line.left, 0.5), reason: reason);
      expect(end.right, closeTo(line.right, 0.5), reason: reason);
    }
  });

  testWidgets('test_stacked_list_row_property_end_sits_at_the_right_edge', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: LayoutSize.mediumMinimumWidth - 1,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: const StackedListRow(
          row: ListRowData(
            main: ListRowMain(
              title: 'Workflows',
              subtitle: <TextSegment>[
                TextSegment('Reusable chains of agents'),
              ],
            ),
            end: AppIcon(AppIconKind.chevronRight),
          ),
        ),
      );

      final Rect row = tester.getRect(find.byType(StackedListRow));
      final Rect end = tester.getRect(find.byType(AppIcon));
      final Rect main = tester.getRect(find.byType(ListRowMain));
      final String reason = 'width $width';
      expect(
        end.right,
        closeTo(row.right - AppSpacing.space3, 0.5),
        reason: reason,
      );
      expect(
        main.right,
        closeTo(end.left - AppSpacing.space4, 0.5),
        reason: reason,
      );
    }
  });
}
