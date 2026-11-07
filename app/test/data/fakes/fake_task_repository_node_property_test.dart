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
import 'support/refusals.dart';
import 'support/task_inputs.dart';

const int _sequenceIterations = 30;
const int _longestSequence = 14;

typedef _Pair = ({
  FakeTaskRepository fake,
  NodeBackedTaskRepository nodeBacked,
});

typedef _Twin = ({TaskId fake, TaskId node});

typedef _TaskView = ({String title, String details, String status, bool busy});

bool _refusesWithAnyError(Object error) => true;

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

TaskDraft _randomOneAgentDraft(Random random) {
  final TaskDraft draft = randomTaskDraft(random);
  return TaskDraft(
    title: draft.title,
    details: draft.details,
    projectId: draft.projectId,
    doer: OneAgentDoer(pickOne(random, AgentKind.values)),
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
  );
}

_TaskView _describe(TaskRepository repository, TaskId taskId) {
  final Task task = repository.findTask(taskId);
  return (
    title: task.title,
    details: task.details,
    status: task.status.name,
    busy: repository.listRuns(taskId).any(isRunActive),
  );
}

bool _isBusy(TaskRepository repository, TaskId taskId) {
  return repository.listRuns(taskId).any(isRunActive);
}

bool _canRetry(TaskRepository repository, TaskId taskId) {
  final List<Run> runs = repository.listRuns(taskId);
  if (runs.isEmpty || runs.any(isRunActive)) {
    return false;
  }
  final RunStatus status = runs.first.status;
  return status == RunStatus.failed || status == RunStatus.cancelled;
}

Future<List<_Twin>> _takeStep(
  Random random,
  _Pair pair,
  List<_Twin> twins,
) async {
  if (twins.isEmpty || random.nextInt(4) == 0) {
    final TaskDraft draft = _randomOneAgentDraft(random);
    final Task fromFake = await pair.fake.createTask(draft);
    final Task fromNode = await pair.nodeBacked.createTask(draft);
    return <_Twin>[...twins, (fake: fromFake.id, node: fromNode.id)];
  }

  final _Twin twin = pickOne(random, twins);
  switch (random.nextInt(4)) {
    case 0:
      final TaskDraft draft = _randomOneAgentDraft(random);
      await pair.fake.updateTask(twin.fake, draft);
      await pair.nodeBacked.updateTask(twin.node, draft);
    case 1:
      if (_isBusy(pair.fake, twin.fake)) {
        await pair.fake.cancelRun(pair.fake.listRuns(twin.fake).first.id);
        await pair.nodeBacked.cancelRun(
          pair.nodeBacked.listRuns(twin.node).first.id,
        );
      } else {
        await pair.fake.startTask(twin.fake);
        await pair.nodeBacked.startTask(twin.node);
      }
    case 2:
      if (_canRetry(pair.fake, twin.fake)) {
        await pair.fake.retryRun(pair.fake.listRuns(twin.fake).first.id);
        await pair.nodeBacked.retryRun(
          pair.nodeBacked.listRuns(twin.node).first.id,
        );
      }
    default:
      final bool isFakeRefused = await isRefused(
        () => pair.fake.deleteTask(twin.fake),
        isRefusal: _refusesWithAnyError,
      );
      final bool isNodeRefused = await isRefused(
        () => pair.nodeBacked.deleteTask(twin.node),
        isRefusal: _refusesWithAnyError,
      );
      expect(isFakeRefused, isNodeRefused);
      if (!isFakeRefused) {
        return <_Twin>[
          for (final _Twin kept in twins)
            if (kept != twin) kept,
        ];
      }
  }
  return twins;
}

void main() {
  test('test_fake_task_repository_property_work_agrees_with_the_node_'
      'backed_repository', () async {
    final Random random = seededRandom(67301);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = _buildPair();
      List<_Twin> twins = <_Twin>[];
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        twins = await _takeStep(random, pair, twins);

        expect(pair.fake.listTasks().length, twins.length);
        expect(pair.nodeBacked.listTasks().length, twins.length);
        for (final _Twin twin in twins) {
          expect(
            _describe(pair.fake, twin.fake),
            _describe(pair.nodeBacked, twin.node),
          );
        }
      }
      pair.nodeBacked.dispose();
    }
  });
}
