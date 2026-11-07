import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/person_step_inputs.dart';
import 'support/person_step_rigs.dart';
import 'support/person_step_runs.dart';
import 'support/task_inputs.dart';

const String _typePrefix = 'test_fake_person_step_repository';
const int _largestChangeCount = 6;

typedef _SharedRepositories = ({
  FakeTaskRepository taskRepository,
  FakePersonStepRepository first,
  FakePersonStepRepository second,
  NotificationCounter firstNotifications,
  NotificationCounter secondNotifications,
});

void _changeTasks(
  Random random,
  FakeTaskRepository taskRepository,
  int changeCount,
) {
  for (int change = 0; change < changeCount; change += 1) {
    taskRepository.storeTask(randomSeededTask(random, change));
  }
}

List<FlutterErrorDetails> _collectReportedErrors(void Function() action) {
  final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previousHandler = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    action();
  } finally {
    FlutterError.onError = previousHandler;
  }
  return reported;
}

FakePersonStepRepository _buildCounted(
  List<OpenPersonStep> openSteps,
  FakeTaskRepository taskRepository,
  NotificationCounter notifications,
) {
  final FakePersonStepRepository repository = FakePersonStepRepository(
    openSteps: openSteps,
    taskRepository: taskRepository,
  );
  repository.addListener(notifications.record);
  return repository;
}

_SharedRepositories _buildShared(Random random, List<OpenPersonStep> seeded) {
  final FakeTaskRepository taskRepository = buildRunsAskingSteps(
    random,
    seeded,
  );
  final int splitAt = random.nextInt(seeded.length + 1);
  final NotificationCounter firstNotifications = NotificationCounter();
  final NotificationCounter secondNotifications = NotificationCounter();
  return (
    taskRepository: taskRepository,
    first: _buildCounted(
      seeded.sublist(0, splitAt),
      taskRepository,
      firstNotifications,
    ),
    second: _buildCounted(
      seeded.sublist(splitAt),
      taskRepository,
      secondNotifications,
    ),
    firstNotifications: firstNotifications,
    secondNotifications: secondNotifications,
  );
}

void main() {
  test('${_typePrefix}_constructor_property_forwards_each_task_'
      'repository_change', () async {
    final Random random = seededRandom(67201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final PersonStepRig rig = buildPersonStepRig(random, seeded);
      final NotificationCounter taskNotifications = NotificationCounter();
      rig.taskRepository.addListener(taskNotifications.record);
      final int storeCount = random.nextInt(_largestChangeCount);
      final int toggleCount = seeded.isEmpty
          ? 0
          : random.nextInt(_largestChangeCount);

      _changeTasks(random, rig.taskRepository, storeCount);
      Set<RunId> cancelled = <RunId>{};
      for (int toggle = 0; toggle < toggleCount; toggle += 1) {
        cancelled = await toggleRandomRun(
          random: random,
          taskRepository: rig.taskRepository,
          runIds: listStepRunIds(seeded),
          cancelledRunIds: cancelled,
        );
      }

      expect(taskNotifications.count, storeCount + toggleCount);
      expect(rig.notifications.count, taskNotifications.count);
    }
  });

  test('${_typePrefix}_constructor_property_hides_runs_finished_before_'
      'it_was_built', () async {
    final Random random = seededRandom(67202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final FakeTaskRepository taskRepository = buildRunsAskingSteps(
        random,
        seeded,
      );
      final Set<RunId> cancelled = pickRandomRuns(
        random,
        listStepRunIds(seeded),
      );
      for (final RunId runId in cancelled) {
        await taskRepository.cancelRun(runId);
      }
      final NotificationCounter notifications = NotificationCounter();

      final FakePersonStepRepository repository = _buildCounted(
        seeded,
        taskRepository,
        notifications,
      );

      expect(
        repository.listOpenPersonSteps(),
        orderedEquals(keepStepsOutsideRuns(seeded, cancelled)),
      );
      expect(notifications.count, 0);
      for (final RunId runId in cancelled) {
        await taskRepository.retryRun(runId);
      }
      expect(repository.listOpenPersonSteps(), orderedEquals(seeded));
    }
  });

  test('${_typePrefix}_constructor_property_repositories_sharing_task_'
      'runs_each_hide_their_own_steps', () async {
    final Random random = seededRandom(67203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      if (seeded.isEmpty) {
        continue;
      }
      final _SharedRepositories shared = _buildShared(random, seeded);
      final RunId cancelledRunId = pickOne(random, listStepRunIds(seeded));
      final List<OpenPersonStep> firstBefore = shared.first
          .listOpenPersonSteps();
      final List<OpenPersonStep> secondBefore = shared.second
          .listOpenPersonSteps();

      await shared.taskRepository.cancelRun(cancelledRunId);

      final Set<RunId> hidden = <RunId>{cancelledRunId};
      expect(
        shared.first.listOpenPersonSteps(),
        orderedEquals(keepStepsOutsideRuns(firstBefore, hidden)),
      );
      expect(
        shared.second.listOpenPersonSteps(),
        orderedEquals(keepStepsOutsideRuns(secondBefore, hidden)),
      );
      expect(shared.firstNotifications.count, 1);
      expect(shared.secondNotifications.count, 1);
    }
  });

  test('${_typePrefix}_dispose_property_stops_forwarding_task_'
      'changes', () {
    final Random random = seededRandom(67204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final PersonStepRig rig = buildPersonStepRig(random, seeded);
      final int changesBefore = random.nextInt(_largestChangeCount);
      final int changesAfter = 1 + random.nextInt(_largestChangeCount);
      _changeTasks(random, rig.taskRepository, changesBefore);

      rig.repository.dispose();
      final List<FlutterErrorDetails> reported = _collectReportedErrors(
        () => _changeTasks(random, rig.taskRepository, changesAfter),
      );

      expect(reported, isEmpty);
      expect(rig.notifications.count, changesBefore);
    }
  });

  test('${_typePrefix}_dispose_property_keeps_other_task_listeners', () {
    final Random random = seededRandom(67205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final PersonStepRig rig = buildPersonStepRig(random, seeded);
      final NotificationCounter taskNotifications = NotificationCounter();
      rig.taskRepository.addListener(taskNotifications.record);
      final int changeCount = 1 + random.nextInt(_largestChangeCount);

      rig.repository.dispose();
      _changeTasks(random, rig.taskRepository, changeCount);

      expect(taskNotifications.count, changeCount);
    }
  });

  test('${_typePrefix}_dispose_property_leaves_sibling_repositories_'
      'forwarding', () {
    final Random random = seededRandom(67206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final _SharedRepositories shared = _buildShared(random, seeded);
      final int changeCount = 1 + random.nextInt(_largestChangeCount);
      final List<OpenPersonStep> secondBefore = shared.second
          .listOpenPersonSteps();

      shared.first.dispose();
      final List<FlutterErrorDetails> reported = _collectReportedErrors(
        () => _changeTasks(random, shared.taskRepository, changeCount),
      );

      expect(reported, isEmpty);
      expect(shared.secondNotifications.count, changeCount);
      expect(shared.second.listOpenPersonSteps(), orderedEquals(secondBefore));
    }
  });
}
