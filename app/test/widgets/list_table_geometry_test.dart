import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const double _rowStartInset = AppBorders.selected + AppSpacing.space3;
const double _rowEndInset = AppSpacing.space3;
const double _columnGap = AppSpacing.space4;
const double _endWidgetWidth = 40;
const double _tallEndHeight = 40;
const Key _endKey = ValueKey<String>('row end');
const String _rowTitle = 'mac-studio';
const String _rowMeta = 'Runner';

final class _GridCase {
  const _GridCase({
    required this.columns,
    required this.fractions,
    required this.endMinimum,
  });

  final List<ListColumn> columns;
  final List<double> fractions;
  final double endMinimum;
}

final List<_GridCase> _gridCases = <_GridCase>[
  _GridCase(
    columns: buildStandardColumns(const <String>['A0', 'A1', 'A2', '']),
    fractions: const <double>[2, 1, 1],
    endMinimum: AppSizes.listEndColumnMinimumWidth,
  ),
  _GridCase(
    columns: buildColumnsWithAction(const <String>[
      'A0',
      'A1',
      'A2',
      'A3',
      '',
    ]),
    fractions: const <double>[2, 1, 1, 1],
    endMinimum: AppSizes.listActionColumnMinimumWidth,
  ),
];

List<double> _expectedColumnStarts(_GridCase gridCase, double width) {
  final int gapCount = gridCase.fractions.length;
  double totalFraction = 0;
  for (final double fraction in gridCase.fractions) {
    totalFraction += fraction;
  }

  final double sharedWidth =
      width -
      _rowStartInset -
      _rowEndInset -
      gapCount * _columnGap -
      gridCase.endMinimum;
  final double fractionWidth = sharedWidth / totalFraction;
  final List<double> starts = <double>[];
  double start = _rowStartInset;

  for (final double fraction in gridCase.fractions) {
    starts.add(start);
    start += fraction * fractionWidth + _columnGap;
  }
  starts.add(start);
  return starts;
}

ListRowData _buildRow(int metaCount) {
  return ListRowData(
    main: const ListRowMain(title: _rowTitle),
    meta: <Widget>[
      const Text(_rowMeta),
      for (int index = 1; index < metaCount; index += 1) const Text('x'),
    ],
    end: const SizedBox(
      key: _endKey,
      width: _endWidgetWidth,
      height: _tallEndHeight,
    ),
  );
}

void main() {
  testWidgets('test_list_table_property_columns_follow_the_design_grid', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: LayoutSize.mediumMinimumWidth,
        most: widestWidth,
      );
      final _GridCase gridCase = pickOne(random, _gridCases);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: ResponsiveList(
          columns: gridCase.columns,
          rows: <ListRowData>[_buildRow(gridCase.fractions.length - 1)],
        ),
      );

      final List<double> starts = _expectedColumnStarts(gridCase, width);
      for (int index = 0; index < gridCase.fractions.length; index += 1) {
        final Rect heading = tester.getRect(find.text('A$index'));
        final String reason = 'width $width, column $index';
        expect(heading.left, closeTo(starts[index], 0.5), reason: reason);
      }
      final Rect end = tester.getRect(find.byKey(_endKey));
      expect(end.left, closeTo(starts.last, 0.5), reason: 'width $width');
    }
  });

  testWidgets('test_list_table_property_cells_centre_in_the_row', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: LayoutSize.mediumMinimumWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: ResponsiveList(
          columns: _gridCases.first.columns,
          rows: <ListRowData>[_buildRow(2)],
        ),
      );

      final Rect title = tester.getRect(find.text(_rowTitle));
      final Rect meta = tester.getRect(find.text(_rowMeta));
      final Rect end = tester.getRect(find.byKey(_endKey));
      final String reason = 'width $width';
      expect(title.center.dy, closeTo(end.center.dy, 0.5), reason: reason);
      expect(meta.center.dy, closeTo(end.center.dy, 0.5), reason: reason);
    }
  });
}
