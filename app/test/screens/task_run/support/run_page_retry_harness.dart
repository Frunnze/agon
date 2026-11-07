import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../../support/app_harness.dart';
import '../../../support/random_inputs.dart';
import '../../../support/widget_harness.dart';

const String retryButtonLabel = 'Retry';
const String cancelRunButtonLabel = 'Cancel run';
const String retryRefusalTitle = 'Retry did not work';
const String closeButtonLabel = 'Close';

typedef RunStatusSnapshot = Map<RunId, RunStatus>;

Size randomRunWindowSize(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, desktopHeight);
}

Future<AppNavigation> openRunPage(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
  required RunId runId,
}) {
  return pumpApp(
    tester,
    size: randomRunWindowSize(random),
    route: TaskRunRoute(runId),
    dependencies: dependencies,
  );
}

Finder findAppButton(String label) => find.widgetWithText(AppButton, label);

bool isRetryOffered(WidgetTester tester) {
  final AppButton retryButton = tester.widget<AppButton>(
    findAppButton(retryButtonLabel),
  );
  return retryButton.onPressed != null;
}

Future<void> tapAppButton(WidgetTester tester, String label) async {
  final Finder button = findAppButton(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await pumpFrames(tester);
}

bool hasActiveRun(TaskRepository taskRepository, TaskId taskId) {
  return taskRepository.listRuns(taskId).any(isRunActive);
}

RunStatusSnapshot snapshotRunStatuses(
  TaskRepository taskRepository,
  TaskId taskId,
) {
  final RunStatusSnapshot statuses = <RunId, RunStatus>{};
  for (final Run run in taskRepository.listRuns(taskId)) {
    statuses[run.id] = run.status;
  }
  return statuses;
}

void expectRetryFollowsTheTask(
  WidgetTester tester, {
  required TaskRepository taskRepository,
  required RunId shownRunId,
}) {
  final Run shownRun = taskRepository.findRun(shownRunId);
  if (isRunActive(shownRun)) {
    expect(findAppButton(retryButtonLabel), findsNothing);
    expect(findAppButton(cancelRunButtonLabel), findsOneWidget);
    return;
  }

  expect(findAppButton(retryButtonLabel), findsOneWidget);
  final bool isAnotherRunActive = hasActiveRun(
    taskRepository,
    shownRun.taskId,
  );
  expect(isRetryOffered(tester), !isAnotherRunActive);
}
