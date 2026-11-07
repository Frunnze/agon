import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/task_reply_race.dart';

const int _raceIterations = 40;
const int _longestRace = 14;

enum _RaceStep {
  createTask,
  updateTask,
  startTask,
  cancelRun,
  retryRun,
  deleteTask,
  refreshRun,
  load,
  addElsewhere,
  deleteElsewhere,
  changeRunElsewhere,
  switchWorkspace,
  releaseOneReply,
  deliverAnnouncement,
}

const List<_RaceStep> _backgroundSteps = <_RaceStep>[
  _RaceStep.addElsewhere,
  _RaceStep.deleteElsewhere,
  _RaceStep.changeRunElsewhere,
  _RaceStep.releaseOneReply,
  _RaceStep.releaseOneReply,
  _RaceStep.deliverAnnouncement,
];

void _startOnTask(
  TaskReplyRace race,
  TaskId? taskId,
  Future<Object?> Function(TaskId taskId) work,
) {
  if (taskId != null) {
    race.pendingWork.start(work(taskId));
  }
}

void _startOnRun(
  TaskReplyRace race,
  RunId? runId,
  Future<Object?> Function(RunId runId) work,
) {
  if (runId != null) {
    race.pendingWork.start(work(runId));
  }
}

void _takeStep(Random random, TaskReplyRace race, _RaceStep step) {
  final TaskId? taskId = pickListedTaskId(random, race);
  final RunId? runId = pickListedRunId(random, race);
  final TaskDraft draft = randomWorkDraft(random, race.projects);
  switch (step) {
    case _RaceStep.createTask:
      race.pendingWork.start(race.tasks.createTask(draft));
    case _RaceStep.updateTask:
      _startOnTask(
        race,
        taskId,
        (TaskId listedId) => race.tasks.updateTask(listedId, draft),
      );
    case _RaceStep.startTask:
      _startOnTask(race, taskId, race.tasks.startTask);
    case _RaceStep.cancelRun:
      _startOnRun(race, runId, race.tasks.cancelRun);
    case _RaceStep.retryRun:
      _startOnRun(race, runId, race.tasks.retryRun);
    case _RaceStep.deleteTask:
      _startOnTask(race, taskId, race.tasks.deleteTask);
    case _RaceStep.refreshRun:
      _startOnRun(race, runId, race.tasks.refreshRun);
    case _RaceStep.load:
      race.pendingWork.start(race.tasks.load());
    case _RaceStep.addElsewhere:
      addTaskElsewhere(random, race);
    case _RaceStep.deleteElsewhere:
      deleteTaskElsewhere(random, race);
    case _RaceStep.changeRunElsewhere:
      changeRunElsewhere(random, race);
    case _RaceStep.switchWorkspace:
      switchRaceWorkspace(random, race);
    case _RaceStep.releaseOneReply:
      race.transport.releaseRandomReply();
    case _RaceStep.deliverAnnouncement:
      deliverWaitingTaskAnnouncement(race);
  }
}

Future<void> _expectRaceEndsLikeAReload(
  int seed,
  List<_RaceStep> focusSteps,
) async {
  final Random random = seededRandom(seed);
  final List<_RaceStep> steps = <_RaceStep>[
    ...focusSteps,
    ...focusSteps,
    ..._backgroundSteps,
  ];
  for (int i = 0; i < _raceIterations; i += 1) {
    final TaskReplyRace race = await openTaskReplyRace(random);
    final int stepCount = 1 + random.nextInt(_longestRace);

    for (int step = 0; step < stepCount; step += 1) {
      _takeStep(random, race, pickOne(random, steps));
      await pumpEventQueue();
    }

    final List<String> shown = await finishTaskReplyRace(race);
    expect(shown, await reloadTaskListing(race), reason: 'race $i');
    closeTaskReplyRace(race);
  }
}

void main() {
  test('test_node_backed_task_repository_create_task_property_late_replies_'
      'end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(51201, const <_RaceStep>[
      _RaceStep.createTask,
    ]);
  });

  test('test_node_backed_task_repository_update_task_property_late_replies_'
      'end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(51202, const <_RaceStep>[
      _RaceStep.updateTask,
      _RaceStep.createTask,
    ]);
  });

  test('test_node_backed_task_repository_start_task_property_late_replies_'
      'end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(51203, const <_RaceStep>[
      _RaceStep.startTask,
    ]);
  });

  test('test_node_backed_task_repository_cancel_run_property_late_replies_'
      'end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(51204, const <_RaceStep>[
      _RaceStep.cancelRun,
      _RaceStep.startTask,
    ]);
  });

  test('test_node_backed_task_repository_retry_run_property_late_replies_'
      'end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(51205, const <_RaceStep>[
      _RaceStep.retryRun,
      _RaceStep.cancelRun,
      _RaceStep.startTask,
    ]);
  });

  test('test_node_backed_task_repository_delete_task_property_late_replies_'
      'end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(51206, const <_RaceStep>[
      _RaceStep.deleteTask,
      _RaceStep.startTask,
      _RaceStep.cancelRun,
    ]);
  });

  test('test_node_backed_task_repository_refresh_run_property_late_replies_'
      'end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(51207, const <_RaceStep>[
      _RaceStep.refreshRun,
      _RaceStep.startTask,
    ]);
  });

  test('test_node_backed_task_repository_load_after_workspace_change_'
      'property_switches_mid_edit_end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(51208, const <_RaceStep>[
      _RaceStep.switchWorkspace,
      _RaceStep.createTask,
      _RaceStep.startTask,
    ]);
  });

  test('test_node_backed_task_repository_load_property_any_interleaving_'
      'ends_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(51209, _RaceStep.values);
  });
}
