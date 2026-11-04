import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const String _taskQuestion = 'What should be done?';
const List<String> _blankTexts = <String>['', '   '];
final String _tooLongName = 'a' * 41;

final class _CheckedForm {
  const _CheckedForm({
    required this.route,
    required this.openingTaps,
    required this.saveButton,
    required this.wrongTextsByField,
  });

  final AppRoute route;
  final List<Finder> openingTaps;
  final Finder saveButton;
  final Map<String, List<String>> wrongTextsByField;
}

final List<_CheckedForm> _checkedForms = <_CheckedForm>[
  _CheckedForm(
    route: const NewProjectRoute(),
    openingTaps: const <Finder>[],
    saveButton: find.text('Create project'),
    wrongTextsByField: <String, List<String>>{
      'Name': <String>['', 'Bad Name', _tooLongName],
      'Repos': <String>['', 'not an address'],
    },
  ),
  _CheckedForm(
    route: NewItemFormRoute(DraftKind.task),
    openingTaps: const <Finder>[],
    saveButton: find.text('Save for later'),
    wrongTextsByField: <String, List<String>>{_taskQuestion: _blankTexts},
  ),
  _CheckedForm(
    route: NewItemFormRoute(DraftKind.job),
    openingTaps: const <Finder>[],
    saveButton: find.text('Create job'),
    wrongTextsByField: <String, List<String>>{
      _taskQuestion: _blankTexts,
      'At': <String>['', '9 am', '24:61', 'noon'],
    },
  ),
  _CheckedForm(
    route: NewItemFormRoute(DraftKind.skill),
    openingTaps: const <Finder>[],
    saveButton: find.text('Save skill'),
    wrongTextsByField: <String, List<String>>{
      'Name': <String>['', 'Release Notes', 'code-review', _tooLongName],
      'What it does': _blankTexts,
      'Instructions': _blankTexts,
    },
  ),
  _CheckedForm(
    route: NewItemFormRoute(DraftKind.rule),
    openingTaps: const <Finder>[],
    saveButton: find.text('Add rule'),
    wrongTextsByField: <String, List<String>>{'Rule': _blankTexts},
  ),
  _CheckedForm(
    route: const ManualWorkflowRoute(),
    openingTaps: const <Finder>[],
    saveButton: find.text('Sign and save'),
    wrongTextsByField: <String, List<String>>{
      workflowNameLabel: <String>['', 'Hand Made', _tooLongName],
    },
  ),
  _CheckedForm(
    route: const NewWorkflowRoute(),
    openingTaps: const <Finder>[],
    saveButton: find.text(draftWorkflowLabel),
    wrongTextsByField: <String, List<String>>{workflowQuestion: _blankTexts},
  ),
  _CheckedForm(
    route: const NewTaskRoute(),
    openingTaps: const <Finder>[],
    saveButton: find.text('Draft task'),
    wrongTextsByField: <String, List<String>>{_taskQuestion: _blankTexts},
  ),
  _CheckedForm(
    route: const WorkspaceSwitcherRoute(),
    openingTaps: <Finder>[find.text('Create workspace')],
    saveButton: find.text('Create workspace').last,
    wrongTextsByField: <String, List<String>>{
      'Name': <String>['', 'Bad Name', _tooLongName],
    },
  ),
  _CheckedForm(
    route: const ProjectRoute(GalleryProjectIds.mlRanker),
    openingTaps: <Finder>[find.text('Add repo').first],
    saveButton: find.text('Add repo').last,
    wrongTextsByField: <String, List<String>>{
      'Address': <String>['', 'not an address'],
    },
  ),
  _CheckedForm(
    route: const PairingCodeEntryRoute(DeviceRole.client),
    openingTaps: const <Finder>[],
    saveButton: find.textContaining('Pair this'),
    wrongTextsByField: <String, List<String>>{
      'Pairing code': <String>['', '4F7-K2', 'ABCDEFG'],
    },
  ),
];

Future<void> _openForm(WidgetTester tester, _CheckedForm form) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: form.route,
    dependencies: buildGalleryDependencies(),
  );

  for (final Finder openingTap in form.openingTaps) {
    await tapVisible(tester, openingTap);
    await pumpFrames(tester);
  }
}

Future<void> _saveWrongTexts(
  WidgetTester tester, {
  required _CheckedForm form,
  required Random random,
}) async {
  for (final MapEntry<String, List<String>> field
      in form.wrongTextsByField.entries) {
    final String wrongText = pickOne(random, field.value);
    await enterFieldText(tester, label: field.key, text: wrongText);
  }

  await tapVisible(tester, form.saveButton);
  await pumpFrames(tester);
}

TextField _findField(WidgetTester tester, String label) {
  return tester.widget<TextField>(findFieldInput(label));
}

String? _readProblem(WidgetTester tester, String label) {
  return _findField(tester, label).decoration?.errorText;
}

String _pickDifferentText(Random random, String currentText) {
  final String candidate = randomText(random);
  if (candidate == currentText) {
    return '$candidate-';
  }
  return candidate;
}

void main() {
  testWidgets('test_form_fields_property_an_edit_clears_only_its_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9811);

    for (final _CheckedForm form in _checkedForms) {
      await _openForm(tester, form);
      final List<String> labels = form.wrongTextsByField.keys.toList();

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        await _saveWrongTexts(tester, form: form, random: random);
        final Map<String, String?> savedProblems = <String, String?>{
          for (final String label in labels)
            label: _readProblem(tester, label),
        };
        expect(
          savedProblems.values,
          everyElement(isNotNull),
          reason: '${form.route.runtimeType} $savedProblems',
        );

        final String editedLabel = pickOne(random, labels);
        final String currentText = _findField(
          tester,
          editedLabel,
        ).controller!.text;
        await enterFieldText(
          tester,
          label: editedLabel,
          text: _pickDifferentText(random, currentText),
        );

        for (final String label in labels) {
          final String? expectedProblem = label == editedLabel
              ? null
              : savedProblems[label];
          expect(
            _readProblem(tester, label),
            expectedProblem,
            reason: '${form.route.runtimeType} $label',
          );
        }
      }
    }
  });
}
