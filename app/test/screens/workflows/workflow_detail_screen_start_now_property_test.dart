import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../data/fakes/support/task_inputs.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/random_signature_workflows.dart';
import '../../support/widget_harness.dart';

typedef _SignatureStateApp = ({
  AppDependencies dependencies,
  FakeWorkflowRepository flows,
  WorkflowInSignatureState choice,
});

_SignatureStateApp _buildSignatureStateApp(Random random) {
  final List<WorkflowInSignatureState> choices =
      randomWorkflowsInSignatureStates(random);
  final FakeWorkflowRepository flows = buildSignatureStateRepository(choices);
  final FakeTaskRepository tasks = buildTaskRepository(
    tasks: const <Task>[],
    runs: const <Run>[],
    workflows: flows,
  );
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    workflowRepository: flows,
    taskRepository: tasks,
  );
  return (
    dependencies: dependencies,
    flows: flows,
    choice: pickOne(random, choices),
  );
}

Size _randomWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, desktopHeight);
}

Future<AppNavigation> _openWorkflowPage(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
  required Workflow workflow,
}) {
  return pumpApp(
    tester,
    size: _randomWindowSize(random),
    route: WorkflowDetailRoute(workflow.id),
    dependencies: dependencies,
  );
}

Finder _findStartNow() => find.widgetWithText(AppButton, startNowLabel);

bool _isStartNowEnabled(WidgetTester tester) {
  final AppButton button = tester.widget<AppButton>(_findStartNow());
  return button.onPressed != null;
}

void main() {
  testWidgets('test_workflow_detail_screen_build_property_start_now_needs_'
      'a_signed_unchanged_workflow', (WidgetTester tester) async {
    final Random random = seededRandom(68701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _SignatureStateApp app = _buildSignatureStateApp(random);
      final AppNavigation navigation = await _openWorkflowPage(
        tester,
        random: random,
        dependencies: app.dependencies,
        workflow: app.choice.workflow,
      );

      expect(tester.takeException(), isNull);
      expect(_isStartNowEnabled(tester), app.choice.isSigned);
      await tester.ensureVisible(_findStartNow());
      await tester.tap(_findStartNow(), warnIfMissed: false);
      await pumpFrames(tester);

      final List<Task> tasks = app.dependencies.taskRepository.listTasks();
      expect(tasks.length, app.choice.isSigned ? 1 : 0);
      expect(navigation.currentRoute is TaskRunRoute, app.choice.isSigned);
    }
  });

  testWidgets('test_workflow_detail_screen_build_property_signing_the_'
      'change_enables_start_now', (WidgetTester tester) async {
    final Random random = seededRandom(68702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _SignatureStateApp app = _buildSignatureStateApp(random);
      if (app.choice.state != SignatureState.changedNotSigned) {
        continue;
      }
      await _openWorkflowPage(
        tester,
        random: random,
        dependencies: app.dependencies,
        workflow: app.choice.workflow,
      );
      expect(_isStartNowEnabled(tester), isFalse);

      await app.flows.signWorkflow(app.choice.workflow.id);
      await pumpFrames(tester);

      expect(_isStartNowEnabled(tester), isTrue);
    }
  });

  testWidgets('test_workflow_detail_screen_build_property_an_unsigned_'
      'edit_disables_start_now', (WidgetTester tester) async {
    final Random random = seededRandom(68703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _SignatureStateApp app = _buildSignatureStateApp(random);
      if (!app.choice.isSigned) {
        continue;
      }
      await _openWorkflowPage(
        tester,
        random: random,
        dependencies: app.dependencies,
        workflow: app.choice.workflow,
      );
      expect(_isStartNowEnabled(tester), isTrue);
      final Workflow stored = app.flows.findWorkflow(app.choice.workflow.id);

      await app.flows.saveWorkflow(
        stored.withGraph(
          agents: stored.agents.sublist(0, 1),
          connections: const <AgentConnection>[],
        ),
      );
      await pumpFrames(tester);

      expect(app.flows.findPendingChange(stored.id), isNotNull);
      expect(_isStartNowEnabled(tester), isFalse);
    }
  });
}
