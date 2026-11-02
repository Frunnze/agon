import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/widgets/forms/check_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';
import 'package:agent_orchestration/widgets/forms/tag_suggestions.dart';

import '../support/random_inputs.dart';
import '../support/widget_harness.dart';

const List<String> _skillNames = <String>[
  'ios-release',
  'code-review',
  'git-cleanup',
  'write-tests',
];

Widget buildRandomForm(Random random) {
  return FormColumn(
    children: <Widget>[
      FormFieldBlock(
        label: randomText(random),
        hint: randomText(random),
        children: <Widget>[
          SelectField<int>(
            value: 1,
            entries: <SelectEntry<int>>[
              const SelectGroupHeading<int>('One agent'),
              SelectOption<int>(value: 1, label: randomText(random)),
              const SelectOption<int>.disabled(value: 2, label: 'not signed'),
            ],
            onChanged: (int _) {},
          ),
          TagInputField(
            tags: <String>[pickOne(random, _skillNames)],
            suggestions: _skillNames,
            placeholder: 'Add a skill',
            onTagAdded: (String _) {},
            onTagRemoved: (String _) {},
          ),
          CheckField(
            label: randomText(random),
            value: random.nextBool(),
            onChanged: (bool _) {},
          ),
          SwitchField(
            label: randomText(random),
            value: random.nextBool(),
            onChanged: (bool _) {},
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('test_form_fields_property_render_at_any_width', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 2301,
      buildChild: buildRandomForm,
    );
  });

  testWidgets('test_switch_field_property_tap_reports_the_opposite', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool value = random.nextBool();
      bool? reported;
      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: SwitchField(
          label: 'Ask for approval',
          value: value,
          onChanged: (bool next) => reported = next,
        ),
      );
      await tester.tap(find.text('Ask for approval'));
      expect(reported, !value);
    }
  });

  testWidgets('test_check_field_property_tap_reports_the_opposite', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(2303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool value = random.nextBool();
      bool? reported;
      await pumpScrollableAtWidth(
        tester,
        width: phoneWidth,
        child: CheckField(
          label: 'Also pick automatic skills',
          value: value,
          onChanged: (bool next) => reported = next,
        ),
      );
      await tester.tap(find.text('Also pick automatic skills'));
      expect(reported, !value);
    }
  });

  testWidgets('select field reports the picked option', (
    WidgetTester tester,
  ) async {
    int picked = 1;
    await pumpScrollableAtWidth(
      tester,
      width: phoneWidth,
      child: SelectField<int>(
        value: 1,
        entries: const <SelectEntry<int>>[
          SelectOption<int>(value: 1, label: 'Claude Code'),
          SelectOption<int>(value: 2, label: 'Codex'),
        ],
        onChanged: (int next) => picked = next,
      ),
    );

    await tester.tap(find.text('Claude Code'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Codex').last);
    await tester.pump(const Duration(seconds: 1));
    expect(picked, 2);
  });

  testWidgets('tag input adds a typed suggestion and removes a tag', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<String> added = <String>[];
    final List<String> removed = <String>[];
    await pumpScrollableAtWidth(
      tester,
      width: phoneWidth,
      child: TagInputField(
        tags: const <String>['git-cleanup'],
        suggestions: _skillNames,
        placeholder: 'Add a skill',
        onTagAdded: added.add,
        onTagRemoved: removed.add,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Code-Review');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.bySemanticsLabel('Remove git-cleanup'));
    expect(added, <String>['code-review']);
    expect(removed, <String>['git-cleanup']);
    semantics.dispose();
  });

  test('test_find_tag_suggestions_property_never_offers_chosen_tags', () {
    final Random random = seededRandom(2304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> chosen = <String>[
        for (final String name in _skillNames)
          if (random.nextBool()) name,
      ];
      final String typed = random.nextBool()
          ? randomText(random)
          : pickOne(random, _skillNames).substring(0, 3);
      final List<String> offered = findTagSuggestions(
        suggestions: _skillNames,
        chosenTags: chosen,
        typedText: typed,
      );

      for (final String suggestion in offered) {
        expect(chosen.contains(suggestion), isFalse);
        expect(
          suggestion.toLowerCase().contains(typed.trim().toLowerCase()),
          isTrue,
        );
      }
    }
  });

  test('test_match_tag_suggestion_property_exact_unchosen_match_only', () {
    final Random random = seededRandom(2305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = pickOne(random, _skillNames);
      final bool isChosen = random.nextBool();
      final String? match = matchTagSuggestion(
        suggestions: _skillNames,
        chosenTags: isChosen ? <String>[name] : const <String>[],
        typedText: random.nextBool() ? name.toUpperCase() : ' $name ',
      );

      expect(match, isChosen ? isNull : name);
      expect(
        matchTagSuggestion(
          suggestions: _skillNames,
          chosenTags: const <String>[],
          typedText: '${randomText(random)}#',
        ),
        isNull,
      );
    }
  });
}
