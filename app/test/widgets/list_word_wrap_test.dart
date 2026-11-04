import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const List<String> _longCellTexts = <String>[
  'Read and push',
  'Everywhere except experiments',
  'Yesterday 18:20',
  'office-server',
];

void main() {
  testWidgets('test_list_table_property_cells_never_break_a_word', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(8301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: LayoutSize.mediumMinimumWidth,
        most: widestWidth,
      );
      final String longText = pickOne(random, _longCellTexts);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: ResponsiveList(
          columns: buildColumnsWithAction(const <String>[
            'Repo',
            'Branch',
            'Last task',
            'Agents can',
            '',
          ]),
          rows: <ListRowData>[
            ListRowData(
              main: const ListRowMain(title: 'demo-app'),
              meta: <Widget>[
                const Text('main'),
                const Text('None yet'),
                Text(longText),
              ],
              end: const SizedBox(width: 92, height: 40),
            ),
          ],
        ),
      );

      final double tableRight = tester.getRect(find.byType(Table)).right;
      expect(
        tableRight,
        lessThanOrEqualTo(width + 0.5),
        reason: 'width $width',
      );

      final RenderParagraph paragraph = tester.renderObject(
        find.text(longText),
      );
      final double longestWord = paragraph.getMinIntrinsicWidth(
        double.infinity,
      );
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(longestWord - 0.5),
        reason: 'width $width, "$longText"',
      );
    }
  });
}
