import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/log_block.dart';
import 'package:agent_orchestration/widgets/route_line.dart';
import 'package:agent_orchestration/widgets/route_line_painter.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const double _singleLineHeight = AppFontSizes.small * AppLineHeights.body;
const List<String> _deviceNames = <String>[
  'air-laptop',
  'mac-studio',
  'gpu-box',
  'office-server',
];
const List<String> _statusTexts = <String>['Done', 'Running', 'Next', 'Fail'];
const String _widgetSpanCharacter = '￼';

ResponsiveList _buildPlainList(List<String> statuses) {
  return ResponsiveList.plain(
    rows: <ListRowData>[
      for (final String status in statuses)
        ListRowData(
          main: ListRowMain.monospace(title: 'step $status'),
          end: StatusLabel(text: status, tone: StatusTone.muted),
        ),
    ],
  );
}

void main() {
  testWidgets('test_select_field_property_control_height_is_44', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: 320, most: 1600),
        child: SelectField<int>(
          value: 0,
          entries: <SelectEntry<int>>[
            SelectOption<int>(value: 0, label: randomWordPhrase(random)),
          ],
          onChanged: (int _) {},
        ),
      );

      final Size size = tester.getSize(find.byType(SelectField<int>));
      expect(size.height, AppSizes.controlHeight);
    }
  });

  testWidgets('test_text_field_property_control_height_is_44', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: 320, most: 1600),
        child: TextField(
          decoration: InputDecoration(hintText: randomWordPhrase(random)),
        ),
      );

      final Size size = tester.getSize(find.byType(TextField));
      expect(size.height, AppSizes.controlHeight);
    }
  });

  testWidgets('test_route_line_property_short_names_stay_on_one_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String startName = pickOne(random, _deviceNames);
      final String endName = pickOne(random, _deviceNames);
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: 320, most: 1600),
        child: RouteLine(
          startName: startName,
          endName: endName,
          path: pickOne(random, RoutePath.values),
          badgeLabel: 'Direct · encrypted',
          badgeIcon: AppIconKind.lock,
        ),
      );

      for (final String name in <String>[startName, endName]) {
        final Finder nodes = find.text(name);
        expect(nodes, findsWidgets);
        for (final Element node in nodes.evaluate()) {
          expect(node.size!.height, _singleLineHeight);
        }
      }
    }
  });

  testWidgets('test_responsive_list_property_plain_ends_hug_the_right', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(random, least: 320, most: 1600);
      final List<String> statuses = <String>[
        for (int row = 0; row < 1 + random.nextInt(3); row += 1)
          pickOne(random, _statusTexts),
      ];
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: _buildPlainList(statuses),
      );

      final Finder labels = find.byType(StatusLabel);
      for (int index = 0; index < statuses.length; index += 1) {
        final Rect rect = tester.getRect(labels.at(index));
        expect(rect.right, closeTo(width - AppSpacing.space3, 0.5));
      }
    }
  });

  testWidgets('test_log_block_property_space_follows_the_time_gap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = randomWordPhrase(random);
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: 320, most: 1600),
        child: LogBlock(
          cursor: CursorVisibility.hidden,
          lines: <LogBlockLine>[
            LogBlockLine(time: '14:02:11', text: text, tone: LineTone.normal),
          ],
        ),
      );

      expect(
        find.textContaining('14:02:11$_widgetSpanCharacter $text'),
        findsOneWidget,
      );
    }
  });
}
