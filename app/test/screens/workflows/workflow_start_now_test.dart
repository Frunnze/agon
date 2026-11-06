import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';

List<Workflow> _listSignedWorkflows(AppDependencies dependencies) {
  final List<Workflow> signed = <Workflow>[];
  for (final Workflow workflow
      in dependencies.workflowRepository.listWorkflows()) {
    if (workflow.signature != null) {
      signed.add(workflow);
    }
  }
  return signed;
}

List<Workflow> _listUnsignedWorkflows(AppDependencies dependencies) {
  final List<Workflow> unsigned = <Workflow>[];
  for (final Workflow workflow
      in dependencies.workflowRepository.listWorkflows()) {
    if (workflow.signature == null) {
      unsigned.add(workflow);
    }
  }
  return unsigned;
}

Future<AppNavigation> _openWorkflowPage(
  WidgetTester tester, {
  required AppDependencies dependencies,
  required WorkflowId workflowId,
}) {
  return pumpApp(
    tester,
    size: desktopSize,
    route: WorkflowDetailRoute(workflowId),
    dependencies: dependencies,
  );
}

Future<void> _tapStartNow(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(AppButton, startNowLabel));
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_start_now_property_opens_the_run_of_a_new_task', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Workflow workflow = pickOne(
        random,
        _listSignedWorkflows(dependencies),
      );
      final int taskCountBefore = dependencies.taskRepository
          .listTasks()
          .length;
      final AppNavigation navigation = await _openWorkflowPage(
        tester,
        dependencies: dependencies,
        workflowId: workflow.id,
      );

      await _tapStartNow(tester);

      final List<Task> tasks = dependencies.taskRepository.listTasks();
      expect(tasks.length, taskCountBefore + 1);
      final AppRoute openedRoute = navigation.routes.last;
      expect(openedRoute, isA<TaskRunRoute>());
      final RunId runId = (openedRoute as TaskRunRoute).runId;
      final TaskId taskId = dependencies.taskRepository.findRun(runId).taskId;
      final Task started = dependencies.taskRepository.findTask(taskId);
      expect(started.doer, WorkflowDoer(workflow.id));
      expect(started.title, '$quickStartTitleStart${workflow.name}');
    }
  });

  testWidgets('test_start_now_property_unsigned_workflows_cannot_start', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Workflow> unsigned = _listUnsignedWorkflows(dependencies);
      final Workflow workflow = pickOne(random, unsigned);
      await _openWorkflowPage(
        tester,
        dependencies: dependencies,
        workflowId: workflow.id,
      );

      final AppButton startButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, startNowLabel),
      );

      expect(startButton.onPressed, isNull);
    }
  });

  testWidgets('test_start_now_property_without_projects_adds_one_first', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(7703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = replaceRepositories(
        buildGalleryDependencies(),
        projectRepository: FakeProjectRepository(projects: const <Project>[]),
      );
      final Workflow workflow = pickOne(
        random,
        _listSignedWorkflows(dependencies),
      );
      final int taskCountBefore = dependencies.taskRepository
          .listTasks()
          .length;
      final AppNavigation navigation = await _openWorkflowPage(
        tester,
        dependencies: dependencies,
        workflowId: workflow.id,
      );

      await _tapStartNow(tester);

      expect(navigation.routes.last, isA<NewProjectRoute>());
      expect(dependencies.taskRepository.listTasks().length, taskCountBefore);
    }
  });
}
