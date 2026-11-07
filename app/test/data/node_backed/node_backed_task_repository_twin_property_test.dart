import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/workspace_work_checks.dart';
import '../fakes/support/workspace_work_rig.dart';

const int _twinIterations = 20;
const int _stepsPerTwin = 10;
const String _activeLabel = 'active';

enum _RunAction { start, cancel, retry }

String _describeRun(Run run) {
  final String state = isRunActive(run) ? _activeLabel : run.status.name;
  return '${run.number} $state';
}

List<String> _describeRunsOf(TaskRepository repository, TaskId taskId) {
  return <String>[
    for (final Run run in repository.listRuns(taskId)) _describeRun(run),
  ];
}

Future<void> _act(
  WorkspaceWorkRig rig,
  TaskId fakeId,
  _RunAction action,
) async {
  final TaskId nodeId = findNodeIdOf(rig, fakeId);
  switch (action) {
    case _RunAction.start:
      await expectSameRefusal(
        fakeStep: () => rig.fakeTasks.startTask(fakeId),
        nodeStep: () => rig.nodeTasks.startTask(nodeId),
        reason: 'start ${fakeId.value}',
      );
    case _RunAction.cancel:
      await expectSameRefusal(
        fakeStep: () =>
            rig.fakeTasks.cancelRun(rig.fakeTasks.listRuns(fakeId).first.id),
        nodeStep: () =>
            rig.nodeTasks.cancelRun(rig.nodeTasks.listRuns(nodeId).first.id),
        reason: 'cancel the latest run of ${fakeId.value}',
      );
    case _RunAction.retry:
      await expectSameRefusal(
        fakeStep: () =>
            rig.fakeTasks.retryRun(rig.fakeTasks.listRuns(fakeId).first.id),
        nodeStep: () =>
            rig.nodeTasks.retryRun(rig.nodeTasks.listRuns(nodeId).first.id),
        reason: 'retry the latest run of ${fakeId.value}',
      );
  }
}

_RunAction _pickAction(Random random, WorkspaceWorkRig rig, TaskId fakeId) {
  final List<Run> runs = rig.fakeTasks.listRuns(fakeId);
  if (runs.isEmpty) {
    return _RunAction.start;
  }
  if (isRunActive(runs.first)) {
    return random.nextInt(4) == 0 ? _RunAction.start : _RunAction.cancel;
  }
  return random.nextBool() ? _RunAction.retry : _RunAction.start;
}

void _expectRunTwinsAgree(WorkspaceWorkRig rig, TaskId fakeId) {
  final TaskId nodeId = findNodeIdOf(rig, fakeId);
  expect(
    _describeRunsOf(rig.nodeTasks, nodeId),
    _describeRunsOf(rig.fakeTasks, fakeId),
  );
  expect(
    rig.nodeTasks.findTask(nodeId).status,
    rig.fakeTasks.findTask(fakeId).status,
  );
}

Future<void> _runTwinSequences(
  int seed, {
  required Set<_RunAction> checkedActions,
}) async {
  final Random random = seededRandom(seed);
  int checkedCount = 0;
  for (int i = 0; i < _twinIterations; i += 1) {
    final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
    final List<Task> listed = rig.fakeTasks.listTasks();
    for (int step = 0; step < _stepsPerTwin && listed.isNotEmpty; step += 1) {
      final TaskId fakeId = pickOne(random, listed).id;
      final _RunAction action = _pickAction(random, rig, fakeId);

      await _act(rig, fakeId, action);

      _expectRunTwinsAgree(rig, fakeId);
      expectWorkTwinsAgree(rig);
      if (checkedActions.contains(action)) {
        checkedCount += 1;
      }
    }
    await closeWorkspaceWorkRig(rig);
  }
  expect(checkedCount, greaterThan(0));
}

void main() {
  test('test_node_backed_task_repository_cancel_run_property_agrees_with_'
      'the_fake', () async {
    await _runTwinSequences(
      51601,
      checkedActions: const <_RunAction>{_RunAction.cancel},
    );
  });

  test('test_node_backed_task_repository_retry_run_property_agrees_with_'
      'the_fake', () async {
    await _runTwinSequences(
      51602,
      checkedActions: const <_RunAction>{_RunAction.retry},
    );
  });

  test('test_node_backed_task_repository_start_task_property_agrees_with_'
      'the_fake', () async {
    await _runTwinSequences(
      51603,
      checkedActions: const <_RunAction>{_RunAction.start},
    );
  });
}
