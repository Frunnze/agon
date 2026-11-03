import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/builder_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';

const String _agentTask = 'Build the release and fix any errors.';
const String _missingAgentProblem = 'Add at least one agent';
const String _missingNameProblem = 'Give it a name';
const List<String> _validNames = <String>['hand-made', 'release-2', 'ship'];
const List<String> _invalidNames = <String>['', 'Hand Made', 'café', '  '];

Future<void> _addCompleteAgent(WidgetTester tester) async {
  await tester.tap(find.text('Add agent'));
  await pumpFrames(tester);
  await tapVisible(tester, findFieldText('Agent', 'Choose an agent'));
  await pumpFrames(tester);
  await tester.tap(find.text('Claude Code').last);
  await pumpFrames(tester);
  await enterFieldText(tester, label: 'Task', text: _agentTask);
}

Future<void> _signAndSave(WidgetTester tester) async {
  await tester.tap(find.text('Sign and save'));
  await pumpFrames(tester);
}

Workflow? _findWorkflowNamed(AppDependencies dependencies, String name) {
  for (final Workflow workflow
      in dependencies.workflowRepository.listWorkflows()) {
    if (workflow.name == name) {
      return workflow;
    }
  }
  return null;
}

void main() {
  testWidgets('add manually opens the empty workflow builder', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await openManualWorkflow(
      tester,
      buildGalleryDependencies(),
    );

    expect(navigation.currentRoute, const ManualWorkflowRoute());
    expect(findFieldInput(workflowNameLabel), findsOneWidget);
    final TextField nameField = tester.widget(
      findFieldInput(workflowNameLabel),
    );
    expect(nameField.controller!.text, isEmpty);
    expect(find.byType(AgentNodeBox), findsNothing);
    expect(find.text(emptyCanvasText), findsOneWidget);
    expect(find.text('0 agents · acme · not signed yet'), findsOneWidget);
    expect(find.text('Add agent'), findsOneWidget);
  });

  testWidgets('cancel and back return to New workflow', (
    WidgetTester tester,
  ) async {
    final AppNavigation navigation = await openManualWorkflow(
      tester,
      buildGalleryDependencies(),
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await pumpFrames(tester);
    expect(navigation.currentRoute, const NewWorkflowRoute());

    await tester.tap(find.widgetWithText(AppButton, addManuallyLabel));
    await pumpFrames(tester);
    await tester.tap(find.byType(BackLinkButton));
    await pumpFrames(tester);
    expect(navigation.currentRoute, const NewWorkflowRoute());
  });

  testWidgets('sign and save refuses without a name or an agent', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final int countBefore = dependencies.workflowRepository
        .listWorkflows()
        .length;
    final AppNavigation navigation = await openManualWorkflow(
      tester,
      dependencies,
    );

    await _signAndSave(tester);

    expect(find.text(_missingNameProblem), findsOneWidget);
    expect(find.text(_missingAgentProblem), findsOneWidget);
    expect(navigation.currentRoute, const ManualWorkflowRoute());
    expect(
      dependencies.workflowRepository.listWorkflows().length,
      countBefore,
    );
  });

  testWidgets('sign and save creates, signs and lands on Workflows', (
    WidgetTester tester,
  ) async {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = await openManualWorkflow(
      tester,
      dependencies,
    );
    expect(find.text('Fill in with agent'), findsNothing);

    await enterFieldText(tester, label: workflowNameLabel, text: 'hand-made');
    await _addCompleteAgent(tester);
    expect(find.text('Fill in with agent'), findsNothing);
    await _signAndSave(tester);

    final Workflow? created = _findWorkflowNamed(dependencies, 'hand-made');
    expect(created, isNotNull);
    expect(created!.signature, isNotNull);
    expect(created.agents.single.task, _agentTask);
    expect(navigation.routes, const <AppRoute>[workflowsSectionRoute]);
  });

  testWidgets('test_manual_workflow_screen_property_saves_only_valid_names', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7311);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isValid = random.nextBool();
      final String name = isValid
          ? pickOne(random, _validNames)
          : pickOne(random, _invalidNames);
      final AppDependencies dependencies = buildGalleryDependencies();
      final int countBefore = dependencies.workflowRepository
          .listWorkflows()
          .length;
      await openManualWorkflow(tester, dependencies);

      await enterFieldText(tester, label: workflowNameLabel, text: name);
      await _addCompleteAgent(tester);
      await _signAndSave(tester);

      final int countAfter = dependencies.workflowRepository
          .listWorkflows()
          .length;
      expect(
        countAfter,
        isValid ? countBefore + 1 : countBefore,
        reason: name,
      );
    }
  });
}
