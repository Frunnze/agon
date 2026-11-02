import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

List<ChoiceOption<int>> buildNumberedOptions(int count) {
  return <ChoiceOption<int>>[
    for (int index = 0; index < count; index += 1)
      ChoiceOption<int>(
        value: index,
        title: 'Choice $index',
        detail: 'Detail for choice $index',
      ),
  ];
}

void main() {
  testWidgets('test_choice_list_field_property_tap_reports_that_value', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int count = 1 + random.nextInt(4);
      final int selected = random.nextInt(count);
      final int tapped = random.nextInt(count);
      final List<int> reported = <int>[];

      await pumpScrollableAtWidth(
        tester,
        width: desktopWidth,
        child: ChoiceListField<int>(
          options: buildNumberedOptions(count),
          selected: selected,
          onChanged: reported.add,
        ),
      );
      await tester.tap(find.text('Choice $tapped'));

      expect(reported, <int>[tapped]);
      expect(find.text('Detail for choice $tapped'), findsOneWidget);
    }
  });

  testWidgets('test_choice_list_field_property_only_selected_is_checked', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int count = 1 + random.nextInt(4);
      final int selected = random.nextInt(count);

      await pumpScrollableAtWidth(
        tester,
        width: desktopWidth,
        child: ChoiceListField<int>(
          options: buildNumberedOptions(count),
          selected: selected,
          onChanged: (int _) {},
        ),
      );

      for (int index = 0; index < count; index += 1) {
        expect(
          tester.getSemantics(find.text('Choice $index')),
          isSemantics(isChecked: index == selected),
        );
      }
    }
  });

  testWidgets('test_choice_list_field_property_tiles_are_as_tall_as_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9304);
    const double textHeight =
        AppFontSizes.body * AppLineHeights.body +
        AppSpacing.space1 +
        AppFontSizes.small * AppLineHeights.body;
    const double tileHeight =
        textHeight + 2 * (AppSpacing.space4 + AppBorders.thin);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int count = 1 + random.nextInt(4);

      await pumpScrollableAtWidth(
        tester,
        width: desktopWidth,
        child: ChoiceListField<int>(
          options: buildNumberedOptions(count),
          selected: random.nextInt(count),
          onChanged: (int _) {},
        ),
      );

      expect(
        tester.getSize(find.byType(ChoiceListField<int>)).height,
        count * tileHeight + (count - 1) * AppSpacing.space2,
      );
    }
  });

  testWidgets('test_choice_list_field_fuzz_property_renders_at_any_width', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 9303,
      buildChild: (Random random) => ChoiceListField<String>(
        options: <ChoiceOption<String>>[
          ChoiceOption<String>(
            value: 'first',
            title: randomText(random),
            detail: randomText(random),
          ),
          ChoiceOption<String>(
            value: 'second',
            title: randomWordPhrase(random),
            detail: randomWordPhrase(random),
          ),
        ],
        selected: random.nextBool() ? 'first' : 'second',
        onChanged: (String _) {},
      ),
    );
  });
}
