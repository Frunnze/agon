import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/sample_records.dart';

const Map<ApprovalPolicy?, String> _choiceTitles = <ApprovalPolicy?, String>{
  null: 'Same as the project',
  ApprovalPolicy.neverAsk: 'Auto',
  ApprovalPolicy.askBeforeRiskyActions: 'Ask me',
};
const List<String> _fieldTexts = <String>[
  'Commands and pushes',
  'Same as the project',
  "Uses the project's setting, or the workspace's.",
  'Auto',
  'Runs commands and pushes without asking you.',
  'Ask me',
  'Asks you before each command and each push.',
];

Future<AppDependencies> _openNewTask(WidgetTester tester) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.tasks),
    dependencies: dependencies,
  );
  navigation.openRoute(NewItemFormRoute(DraftKind.task));
  await pumpFrames(tester);
  return dependencies;
}

Future<Task> _saveForLater(
  WidgetTester tester,
  AppDependencies dependencies,
) async {
  await tester.enterText(find.byType(TextField).first, 'Rotate the keys');
  await pumpFrames(tester);
  await tapVisible(tester, find.text('Save for later'));
  await pumpFrames(tester);
  return dependencies.taskRepository.listTasks().first;
}

void main() {
  testWidgets('the task form offers the project, Auto and Ask me', (
    WidgetTester tester,
  ) async {
    await _openNewTask(tester);

    for (final String text in _fieldTexts) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('a new task saved untouched follows the project', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = await _openNewTask(tester);

    final Task saved = await _saveForLater(tester, dependencies);

    expect(saved.title, 'Rotate the keys');
    expect(saved.approvalPolicy, isNull);
  });

  testWidgets('test_task_form_property_saves_the_tapped_policy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(9841);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalPolicy? chosen = randomInheritableApprovalPolicy(random);
      final AppDependencies dependencies = await _openNewTask(tester);

      await tapVisible(tester, find.text(_choiceTitles[chosen]!));
      await pumpFrames(tester);
      final Task saved = await _saveForLater(tester, dependencies);

      expect(saved.approvalPolicy, chosen);
    }
  });
}
