import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/rules/rule_form.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';

const String _titleLabel = 'Rule';
const String _detailsLabel = 'Details';
const String _submitLabel = 'Save rule';
const String _emptyTitleProblem = 'Write the rule';
const RuleDraft _emptyDraft = RuleDraft(
  title: '',
  details: '',
  scope: Scope.everywhere(),
);

final class _RuleFormProbe {
  final List<RuleDraft> submitted = <RuleDraft>[];
  final List<RuleDraft> reported = <RuleDraft>[];

  Widget build() {
    return RuleForm(
      key: UniqueKey(),
      initialRule: _emptyDraft,
      catalog: galleryCatalog,
      onChanged: reported.add,
      actions: <FormAction<RuleDraft>>[
        SubmitFormAction<RuleDraft>(
          label: _submitLabel,
          tone: ButtonTone.primary,
          onSubmitted: (RuleDraft draft) async => submitted.add(draft),
        ),
      ],
    );
  }
}

Future<_RuleFormProbe> _pumpForm(WidgetTester tester, Random random) async {
  final _RuleFormProbe probe = _RuleFormProbe();
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: probe.build());
  return probe;
}

String _readField(WidgetTester tester, String label) {
  final TextField field = tester.widget<TextField>(findFieldInput(label));
  return field.controller?.text ?? '';
}

Future<void> _submit(WidgetTester tester) async {
  await tapVisible(tester, find.text(_submitLabel));
  await tester.pump();
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  testWidgets('test_rule_form_read_rule_property_submits_rust_trimmed_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(60861);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RuleFormProbe probe = await _pumpForm(tester, random);
      final String title = 'Rule${table.randomExoticTitle(random)}';
      final String leading = table.randomWhiteSpaceRun(random);
      final String details = table.randomExoticTitle(random);

      await enterFieldText(tester, label: _titleLabel, text: '$leading$title');
      await enterFieldText(tester, label: _detailsLabel, text: details);
      await _submit(tester);

      final String shownTitle = _readField(tester, _titleLabel);
      final String shownDetails = _readField(tester, _detailsLabel);
      expect(probe.submitted, hasLength(1));
      expect(probe.submitted.single.title, table.trimByModel(shownTitle));
      expect(probe.submitted.single.details, table.trimByModel(shownDetails));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_rule_form_read_rule_property_refuses_only_rust_blanks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(60862);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RuleFormProbe probe = await _pumpForm(tester, random);
      final RuleTitleWhiteSpaceCase sharedCase = pickOne(random, table.cases);

      await enterFieldText(tester, label: _titleLabel, text: sharedCase.title);
      await _submit(tester);

      final String shownTitle = _readField(tester, _titleLabel);
      final bool isBlank = table.trimByModel(shownTitle).isEmpty;
      final Finder problem = find.text(_emptyTitleProblem);
      expect(probe.submitted, hasLength(isBlank ? 0 : 1));
      expect(problem, isBlank ? findsOneWidget : findsNothing);
    }
  });

  testWidgets(
    'test_rule_form_read_rule_property_reports_rust_trimmed_drafts',
    (WidgetTester tester) async {
      final Random random = seededRandom(60863);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _RuleFormProbe probe = await _pumpForm(tester, random);
        final String title = table.randomExoticTitle(random);
        if (title.isEmpty) {
          continue;
        }

        await enterFieldText(tester, label: _titleLabel, text: title);

        final String shownTitle = _readField(tester, _titleLabel);
        expect(probe.reported, isNotEmpty);
        expect(probe.reported.last.title, table.trimByModel(shownTitle));
        expect(probe.reported.last.details, '');
      }
    },
  );
}
