import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_page.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/empty_state.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/log_block.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/page_section.dart';
import 'package:agent_orchestration/widgets/split_layout.dart';
import 'package:agent_orchestration/widgets/tab_strip.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

Widget buildRandomPage(Random random) {
  return Column(
    children: <Widget>[
      PageHeader(
        title: randomText(random),
        summary: <TextSegment>[TextSegment(randomText(random))],
        backLink: BackLink(label: randomWordPhrase(random), onPressed: () {}),
        actions: <Widget>[
          AppButton.secondary(label: randomText(random), onPressed: () {}),
        ],
      ),
      TabStrip(
        labels: const <String>['General', 'Runners', 'Audit log'],
        selectedIndex: random.nextInt(3),
        onSelected: (int _) {},
      ),
      SplitLayout(
        proportion: pickOne(random, SplitProportion.values),
        start: PageSection(
          title: randomText(random),
          actions: <Widget>[
            AppButton.secondary(label: 'Add rule', onPressed: () {}),
          ],
          children: <Widget>[
            FactList(
              facts: <Fact>[
                Fact(
                  term: randomText(random),
                  description: <TextSegment>[
                    TextSegment.monospace(randomText(random)),
                  ],
                ),
              ],
            ),
          ],
        ),
        end: Column(
          children: <Widget>[
            CodeBlock(
              lines: <CodeBlockLine>[
                CodeBlockLine(randomText(random)),
                CodeBlockLine.added(randomText(random)),
                CodeBlockLine.removed(randomText(random)),
              ],
            ),
            LogBlock(
              cursor: pickOne(random, CursorVisibility.values),
              lines: <LogBlockLine>[
                LogBlockLine(
                  time: '14:02:11',
                  text: randomText(random),
                  tone: pickOne(random, LineTone.values),
                ),
              ],
            ),
          ],
        ),
      ),
      EmptyState(
        title: randomText(random),
        message: randomText(random),
        action: AppButton.primary(label: 'New task', onPressed: () {}),
      ),
    ],
  );
}

void main() {
  testWidgets('test_page_widgets_property_render_at_any_width', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 2401,
      buildChild: buildRandomPage,
    );
  });

  testWidgets('test_app_page_property_scrolls_any_number_of_children', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      useViewSize(
        tester,
        Size(randomWidth(random, least: 320, most: 1600), 600),
      );
      await tester.pumpWidget(
        wrapInApp(
          AppPage(
            children: <Widget>[
              for (int index = 0; index < random.nextInt(40); index += 1)
                Text('Line $index'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_tab_strip_property_reports_tapped_index', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2403);
    const List<String> labels = <String>['General', 'Runners', 'Audit log'];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      int? selected;
      final int target = random.nextInt(labels.length);
      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: TabStrip(
          labels: labels,
          selectedIndex: 0,
          onSelected: (int index) => selected = index,
        ),
      );
      await tester.tap(find.text(labels[target]));
      expect(selected, target);
    }
  });

  testWidgets('test_tab_strip_property_underline_overlaps_the_bottom_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2406);
    const List<String> labels = <String>['General', 'Runners', 'Audit log'];

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: TabStrip(
          labels: labels,
          selectedIndex: random.nextInt(labels.length),
          onSelected: (int _) {},
        ),
      );

      final Size strip = tester.getSize(find.byType(TabStrip));
      expect(strip.height, AppSizes.controlHeight);
    }
  });

  testWidgets('test_split_layout_property_side_by_side_only_from_1024', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(random, least: 320, most: 1600);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: const SplitLayout(start: Text('start'), end: Text('end')),
      );
      final double startTop = tester.getTopLeft(find.text('start')).dy;
      final double endTop = tester.getTopLeft(find.text('end')).dy;

      expect(startTop == endTop, LayoutSize.forWidth(width).isLarge);
    }
  });

  test('test_space_vertically_property_one_gap_between_each_pair', () {
    final Random random = seededRandom(2405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(8);
      final List<Widget> children = <Widget>[
        for (int index = 0; index < count; index += 1) Text('$index'),
      ];
      final List<Widget> spaced = spaceVertically(children, 8);
      final List<Widget> horizontal = spaceHorizontally(children, 8);

      expect(spaced.length, count == 0 ? 0 : count * 2 - 1);
      expect(horizontal.length, spaced.length);
    }
  });
}
