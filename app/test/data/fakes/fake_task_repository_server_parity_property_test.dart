import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../support/random_inputs.dart';
import '../../support/workflow_repositories.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_work_node.dart';
import 'support/startable_drafts.dart';
import 'support/task_inputs.dart';

const int _sequenceIterations = 40;
const int _longestSequence = 16;

typedef _Pair = ({
  FakeTaskRepository fake,
  NodeBackedTaskRepository nodeBacked,
});

typedef _Twin = ({TaskId fake, TaskId node});

typedef _RunView = ({int number, bool isActive});

_Pair _buildPair() {
  final SimulatedWorkNode simulated = SimulatedWorkNode(
    thisDeviceId: taskClockDevice.value,
  );
  final NodeBackedJobRepository jobs = NodeBackedJobRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: buildSingleWorkspaceRepository(),
    clock: FixedClock(taskClockMoment),
  );
  final NodeBackedTaskRepository nodeBacked = NodeBackedTaskRepository(
    clock: const SystemClock(),
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: buildSingleWorkspaceRepository(),
    livePollInterval: Duration.zero,
    jobRepository: jobs,
  );
  final FakeTaskRepository fake = buildTaskRepository(
    tasks: const <Task>[],
    runs: const <Run>[],
    workflows: buildGalleryWorkflowRepository(),
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

TaskDraft _randomSharedDoerDraft(Random random) {
  return replaceDraftDoer(
    randomTaskDraft(random),
    const OneAgentDoer(AgentKind.claudeCode),
  );
}

List<_RunView> _describeRuns(TaskRepository repository, TaskId taskId) {
  return <_RunView>[
    for (final Run run in repository.listRuns(taskId))
      (number: run.number, isActive: isRunActive(run)),
  ];
}

bool _canRetry(TaskRepository repository, TaskId taskId) {
  final List<Run> runs = repository.listRuns(taskId);
  if (runs.isEmpty || runs.any(isRunActive)) {
    return false;
  }
  final RunStatus status = runs.first.status;
  return status == RunStatus.failed || status == RunStatus.cancelled;
}

Future<_Twin> _createTwin(Random random, _Pair pair) async {
  final TaskDraft draft = _randomSharedDoerDraft(random);
  final Task fromFake = await pair.fake.createTask(draft);
  final Task fromNode = await pair.nodeBacked.createTask(draft);
  return (fake: fromFake.id, node: fromNode.id);
}

Future<void> _startOrCancel(_Pair pair, _Twin twin) async {
  final List<Run> fakeRuns = pair.fake.listRuns(twin.fake);
  final bool isBusy = fakeRuns.any(isRunActive);
  if (isBusy) {
    await pair.fake.cancelRun(fakeRuns.first.id);
    final RunId nodeRunId = pair.nodeBacked.listRuns(twin.node).first.id;
    await pair.nodeBacked.cancelRun(nodeRunId);
    return;
  }
  await pair.fake.startTask(twin.fake);
  await pair.nodeBacked.startTask(twin.node);
}

Future<({Run fake, Run node})> _retryLatest(_Pair pair, _Twin twin) async {
  final RunId fakeRunId = pair.fake.listRuns(twin.fake).first.id;
  final RunId nodeRunId = pair.nodeBacked.listRuns(twin.node).first.id;
  final Run fromFake = await pair.fake.retryRun(fakeRunId);
  final Run fromNode = await pair.nodeBacked.retryRun(nodeRunId);
  expect(fromFake.id, fakeRunId);
  expect(fromNode.id, nodeRunId);
  return (fake: fromFake, node: fromNode);
}

Future<List<_Twin>> _takeRandomStep(
  Random random,
  _Pair pair,
  List<_Twin> twins,
) async {
  if (twins.isEmpty || random.nextInt(4) == 0) {
    return <_Twin>[...twins, await _createTwin(random, pair)];
  }
  final _Twin twin = pickOne(random, twins);
  if (_canRetry(pair.fake, twin.fake) && random.nextBool()) {
    await _retryLatest(pair, twin);
  } else {
    await _startOrCancel(pair, twin);
  }
  return twins;
}

void _expectSameRuns(_Pair pair, List<_Twin> twins) {
  for (final _Twin twin in twins) {
    expect(
      _describeRuns(pair.fake, twin.fake),
      _describeRuns(pair.nodeBacked, twin.node),
    );
  }
}

void main() {
  test('test_next_run_number_property_numbers_runs_like_the_node', () async {
    final Random random = seededRandom(68501);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = _buildPair();
      List<_Twin> twins = <_Twin>[];
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        twins = await _takeRandomStep(random, pair, twins);
        _expectSameRuns(pair, twins);
      }
      pair.nodeBacked.dispose();
    }
  });

  test('test_retry_run_property_keeps_the_run_like_the_node', () async {
    final Random random = seededRandom(68502);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = _buildPair();
      final _Twin twin = await _createTwin(random, pair);
      await _startOrCancel(pair, twin);
      await _startOrCancel(pair, twin);
      final int runCountBefore = pair.fake.listRuns(twin.fake).length;

      final ({Run fake, Run node}) retried = await _retryLatest(pair, twin);

      expect(retried.fake.number, retried.node.number);
      expect(isRunActive(retried.fake), isRunActive(retried.node));
      expect(pair.fake.listRuns(twin.fake).length, runCountBefore);
      expect(pair.nodeBacked.listRuns(twin.node).length, runCountBefore);
      pair.nodeBacked.dispose();
    }
  });

  test('test_start_task_property_first_runs_are_number_one_like_the_'
      'node', () async {
    final Random random = seededRandom(68503);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = _buildPair();
      final int taskCount = 1 + random.nextInt(_longestSequence ~/ 4);
      final List<_Twin> twins = <_Twin>[];

      for (int index = 0; index < taskCount; index += 1) {
        final _Twin twin = await _createTwin(random, pair);
        twins.add(twin);
        await _startOrCancel(pair, twin);
      }

      for (final _Twin twin in twins) {
        expect(pair.fake.listRuns(twin.fake).single.number, 1);
      }
      _expectSameRuns(pair, twins);
      pair.nodeBacked.dispose();
    }
  });
}
