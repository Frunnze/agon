import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/run_page_retry_harness.dart';

const int _longestMoveSequence = 6;
const String _askTheAgentLabel = 'Ask the agent';
const String _chatWithAgentLabel = 'Chat with agent';
const List<RunId> _stoppableRunIds = <RunId>[
  GalleryRunIds.release41,
  GalleryRunIds.release42,
];
const List<RunId> _doneRunIds = <RunId>[
  GalleryRunIds.writeApiDocs1,
  GalleryRunIds.renameBillingModule1,
];

enum _RunMove { startTask, cancelActiveRun, tapRetry }

Future<RunId> _stopRandomRun(Random random, TaskRepository tasks) async {
  final RunId shownRunId = pickOne(random, _stoppableRunIds);
  if (isRunActive(tasks.findRun(shownRunId))) {
    await tasks.cancelRun(shownRunId);
  }
  return shownRunId;
}

Future<void> _cancelActiveRuns(TaskRepository tasks, TaskId taskId) async {
  for (final Run run in tasks.listRuns(taskId)) {
    if (isRunActive(run)) {
      await tasks.cancelRun(run.id);
    }
  }
}

Future<void> _makeMove(
  WidgetTester tester, {
  required _RunMove move,
  required TaskRepository tasks,
  required TaskId taskId,
}) async {
  switch (move) {
    case _RunMove.startTask:
      if (!hasActiveRun(tasks, taskId)) {
        await tasks.startTask(taskId);
      }
    case _RunMove.cancelActiveRun:
      await _cancelActiveRuns(tasks, taskId);
    case _RunMove.tapRetry:
      if (findAppButton(retryButtonLabel).evaluate().isNotEmpty) {
        await tapAppButton(tester, retryButtonLabel);
      }
  }
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_build_actions_property_retry_is_off_exactly_while_the_'
      'task_runs', (WidgetTester tester) async {
    final Random random = seededRandom(78101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final RunId shownRunId = await _stopRandomRun(random, tasks);
      final TaskId taskId = tasks.findRun(shownRunId).taskId;
      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: shownRunId,
      );
      final int moveCount = 1 + random.nextInt(_longestMoveSequence);

      for (int move = 0; move < moveCount; move += 1) {
        await _makeMove(
          tester,
          move: pickOne(random, _RunMove.values),
          tasks: tasks,
          taskId: taskId,
        );

        expect(tester.takeException(), isNull);
        expectRetryFollowsTheTask(
          tester,
          taskRepository: tasks,
          shownRunId: shownRunId,
        );
      }
    }
  });

  testWidgets('test_build_actions_property_done_runs_never_offer_retry', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(78102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final RunId shownRunId = pickOne(random, _doneRunIds);
      final TaskId taskId = tasks.findRun(shownRunId).taskId;
      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: shownRunId,
      );
      final int moveCount = random.nextInt(_longestMoveSequence);

      for (int move = 0; move < moveCount; move += 1) {
        await _makeMove(
          tester,
          move: pickOne(random, _RunMove.values),
          tasks: tasks,
          taskId: taskId,
        );

        expect(tester.takeException(), isNull);
        expect(findAppButton(retryButtonLabel), findsNothing);
        expect(findAppButton(_askTheAgentLabel), findsOneWidget);
      }
      expect(tasks.findRun(shownRunId).status, RunStatus.done);
    }
  });

  testWidgets('test_build_actions_property_active_runs_offer_cancel_not_'
      'retry', (WidgetTester tester) async {
    final Random random = seededRandom(78103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final RunId stoppedRunId = await _stopRandomRun(random, tasks);
      final TaskId taskId = tasks.findRun(stoppedRunId).taskId;
      final Run startedRun = await tasks.startTask(taskId);

      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: startedRun.id,
      );

      expect(tester.takeException(), isNull);
      expect(findAppButton(retryButtonLabel), findsNothing);
      expect(findAppButton(cancelRunButtonLabel), findsOneWidget);
      expect(findAppButton(_chatWithAgentLabel), findsOneWidget);
    }
  });

  testWidgets('test_offer_retry_property_tapping_the_off_retry_changes_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(78104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final RunId shownRunId = await _stopRandomRun(random, tasks);
      final TaskId taskId = tasks.findRun(shownRunId).taskId;
      await tasks.startTask(taskId);
      final AppNavigation navigation = await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: shownRunId,
      );
      final RunStatusSnapshot statusesBefore = snapshotRunStatuses(
        tasks,
        taskId,
      );
      final int tapCount = 1 + random.nextInt(_longestMoveSequence);

      for (int tap = 0; tap < tapCount; tap += 1) {
        await tapAppButton(tester, retryButtonLabel);
      }

      expect(tester.takeException(), isNull);
      expect(isRetryOffered(tester), isFalse);
      expect(snapshotRunStatuses(tasks, taskId), statusesBefore);
      expect(find.text(retryRefusalTitle), findsNothing);
      expect(navigation.routes, <AppRoute>[TaskRunRoute(shownRunId)]);
    }
  });

  testWidgets('test_offer_retry_property_retry_returns_once_the_other_run_'
      'stops', (WidgetTester tester) async {
    final Random random = seededRandom(78105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final RunId shownRunId = await _stopRandomRun(random, tasks);
      final TaskId taskId = tasks.findRun(shownRunId).taskId;
      final Run otherRun = await tasks.startTask(taskId);
      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: shownRunId,
      );
      expect(isRetryOffered(tester), isFalse);

      await tasks.cancelRun(otherRun.id);
      await pumpFrames(tester);
      expect(isRetryOffered(tester), isTrue);
      await tapAppButton(tester, retryButtonLabel);

      expect(tester.takeException(), isNull);
      expect(isRunActive(tasks.findRun(shownRunId)), isTrue);
      expect(tasks.findRun(otherRun.id).status, RunStatus.cancelled);
      expect(findAppButton(cancelRunButtonLabel), findsOneWidget);
    }
  });

  testWidgets('test_offer_retry_property_only_runs_of_the_same_task_turn_'
      'it_off', (WidgetTester tester) async {
    final Random random = seededRandom(78106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final TaskRepository tasks = dependencies.taskRepository;
      final RunId shownRunId = await _stopRandomRun(random, tasks);
      final TaskId shownTaskId = tasks.findRun(shownRunId).taskId;
      final RunId otherTaskRunId = pickOne(
        random,
        _stoppableRunIds.where((RunId runId) => runId != shownRunId).toList(),
      );
      final TaskId otherTaskId = tasks.findRun(otherTaskRunId).taskId;
      await openRunPage(
        tester,
        random: random,
        dependencies: dependencies,
        runId: shownRunId,
      );
      final int moveCount = 1 + random.nextInt(_longestMoveSequence);

      for (int move = 0; move < moveCount; move += 1) {
        final _RunMove otherTaskMove = pickOne(random, <_RunMove>[
          _RunMove.startTask,
          _RunMove.cancelActiveRun,
        ]);
        await _makeMove(
          tester,
          move: otherTaskMove,
          tasks: tasks,
          taskId: otherTaskId,
        );

        expect(tester.takeException(), isNull);
        expect(hasActiveRun(tasks, shownTaskId), isFalse);
        expect(isRetryOffered(tester), isTrue);
      }
    }
  });
}
