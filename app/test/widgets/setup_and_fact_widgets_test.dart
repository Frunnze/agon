import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/numbered_list.dart';
import 'package:agent_orchestration/widgets/setup_panel.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

void main() {
  testWidgets('test_switch_toggle_property_tap_reports_the_opposite', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isOn = random.nextBool();
      final List<bool> reported = <bool>[];

      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: Align(
          alignment: Alignment.topLeft,
          child: SwitchToggle(
            semanticLabel: 'Use the rule',
            value: isOn,
            onChanged: reported.add,
          ),
        ),
      );
      await tester.tap(find.byType(SwitchToggle));

      expect(reported, <bool>[!isOn]);
      expect(
        tester.getSemantics(find.byType(SwitchToggle)),
        isSemantics(label: 'Use the rule', isToggled: isOn),
      );
    }
  });

  testWidgets('test_switch_toggle_property_without_handler_stays_put', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isOn = random.nextBool();

      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: Align(
          alignment: Alignment.topLeft,
          child: SwitchToggle(
            semanticLabel: 'Keep a backup',
            value: isOn,
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.byType(SwitchToggle), warnIfMissed: false);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.byType(SwitchToggle)),
        isSemantics(
          label: 'Keep a backup',
          isToggled: isOn,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    }
  });

  testWidgets('test_fact_list_property_chip_facts_show_every_chip', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> chips = <String>[
        for (int index = 0; index < 1 + random.nextInt(4); index += 1)
          'chip-$index',
      ];

      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: FactList(
          facts: <Fact>[
            Fact.chips(term: 'Labels', chips: chips),
            const Fact(
              term: 'Name',
              description: <TextSegment>[TextSegment('mac-mini')],
            ),
          ],
        ),
      );

      expect(find.byType(LabelChip), findsNWidgets(chips.length));
      for (final String chip in chips) {
        expect(find.text(chip), findsOneWidget);
      }
      expect(find.text('mac-mini'), findsOneWidget);
    }
  });

  testWidgets('test_numbered_list_property_numbers_every_entry_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> entries = <String>[
        for (int index = 0; index < 1 + random.nextInt(5); index += 1)
          'Step text $index',
      ];

      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: NumberedList(entries: entries),
      );

      for (int index = 0; index < entries.length; index += 1) {
        final Offset number = tester.getTopLeft(find.text('${index + 1}.'));
        final Offset entry = tester.getTopLeft(find.text(entries[index]));
        expect(number.dx < entry.dx, isTrue);
        if (index > 0) {
          final Offset previous = tester.getTopLeft(
            find.text(entries[index - 1]),
          );
          expect(previous.dy < entry.dy, isTrue);
        }
      }
    }
  });

  testWidgets('test_setup_panel_fuzz_property_renders_at_any_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      useViewSize(tester, Size(width, desktopHeight));
      await tester.pumpWidget(
        wrapInApp(
          SetupPanel(
            step: randomWordPhrase(random),
            title: randomText(random),
            children: <Widget>[Text(randomText(random))],
          ),
          platform: platformMeantByWidth(width),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('setup panel shows its step and title', (
    WidgetTester tester,
  ) async {
    useViewSize(tester, const Size(phoneWidth, phoneHeight));
    await tester.pumpWidget(
      wrapInApp(
        const SetupPanel(
          step: 'Step 1 of 2',
          title: 'How will this Mac be used?',
          children: <Widget>[Text('Body')],
        ),
        platform: phonePlatform,
      ),
    );

    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('How will this Mac be used?'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });
}
