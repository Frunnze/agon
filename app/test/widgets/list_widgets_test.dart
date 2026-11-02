import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/list_table.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/lists/stacked_list_row.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

ListRowData buildRandomRow(Random random, VoidCallback onTap) {
  return ListRowData(
    main: ListRowMain(
      title: randomText(random),
      subtitle: <TextSegment>[
        TextSegment(randomWordPhrase(random)),
        TextSegment.monospace(randomText(random)),
      ],
    ),
    meta: <Widget>[Text(randomText(random)), Text(randomWordPhrase(random))],
    end: StatusLabel(
      text: randomText(random),
      tone: pickOne(random, StatusTone.values),
      icon: AppIconKind.spinner,
    ),
    onTap: onTap,
    emphasis: pickOne(random, RowEmphasis.values),
  );
}

Widget buildRandomLists(Random random) {
  final int rowCount = random.nextInt(5);

  return Column(
    children: <Widget>[
      ResponsiveList(
        columns: buildStandardColumns(const <String>[
          'Task',
          'Runs on',
          'Started',
          'Status',
        ]),
        rows: <ListRowData>[
          for (int i = 0; i < rowCount; i += 1) buildRandomRow(random, () {}),
        ],
      ),
      ResponsiveList.plain(
        rows: <ListRowData>[
          ListRowData(
            main: ListRowMain.monospace(title: randomText(random)),
            end: RowAction(label: random.nextBool() ? 'Review' : null),
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('test_responsive_list_property_renders_at_any_width', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 2101,
      buildChild: buildRandomLists,
    );
  });

  testWidgets('test_responsive_list_property_table_only_from_768', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(random, least: 320, most: 1600);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: buildRandomLists(random),
      );
      final bool isWide = !LayoutSize.forWidth(width).isCompact;

      expect(find.byType(ListTable).evaluate().isNotEmpty, isWide);
      expect(find.text('Runs on').evaluate().isNotEmpty, isWide);
      expect(find.byType(StackedListRow).evaluate().isNotEmpty, !isWide);
    }
  });

  testWidgets('test_responsive_list_property_row_taps_reach_callback', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      int tapCount = 0;
      final String title = 'Row ${random.nextInt(1000)}';
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: 320, most: 1600),
        child: ResponsiveList(
          columns: buildStandardColumns(const <String>['A', 'B', 'C', 'D']),
          rows: <ListRowData>[
            ListRowData(
              main: ListRowMain(title: title),
              meta: const <Widget>[Text('b'), Text('c')],
              onTap: () => tapCount += 1,
            ),
          ],
        ),
      );
      await tester.tap(find.text(title));
      expect(tapCount, 1);
    }
  });

  test('test_build_standard_columns_property_exactly_four_labels', () {
    final Random random = seededRandom(2104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = <String>[
        for (int index = 0; index < random.nextInt(7); index += 1) 'x',
      ];
      if (labels.length == 4) {
        expect(buildStandardColumns(labels).length, 4);
      } else {
        expect(() => buildStandardColumns(labels), throwsArgumentError);
      }
    }
  });

  test('test_build_columns_with_action_property_exactly_five_labels', () {
    final Random random = seededRandom(2105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = <String>[
        for (int index = 0; index < random.nextInt(8); index += 1) 'x',
      ];
      if (labels.length == 5) {
        expect(buildColumnsWithAction(labels).length, 5);
      } else {
        expect(() => buildColumnsWithAction(labels), throwsArgumentError);
      }
    }
  });

  test('test_build_row_decoration_property_only_current_rows_tinted', () {
    for (final RowEmphasis emphasis in RowEmphasis.values) {
      final BoxDecoration decoration = buildRowDecoration(emphasis);
      expect(decoration.color != null, emphasis == RowEmphasis.current);
    }
  });
}
