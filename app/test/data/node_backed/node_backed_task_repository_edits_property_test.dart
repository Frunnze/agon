import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';
import 'support/task_repository_rig.dart';

const int _rigIterations = 20;
const int _stepsPerRig = 8;
const int _conflictStatus = 409;
const node.AreaChanged _tasksChanged = node.AreaChanged(
  area: node.ChangeArea.tasks,
);

final class _IdOrderedWorkNode {
  _IdOrderedWorkNode(this.work);

  final SimulatedWorkNode work;

  String answer(String inputJson) {
    final String reply = work.answer(inputJson);
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    if (command['command'] != 'list_tasks') {
      return reply;
    }
    final WireRecord listing =
        (jsonDecode(reply) as WireRecord)['ok']! as WireRecord;
    final List<WireRecord> views = <WireRecord>[
      for (final Object? view in listing['tasks']! as List<Object?>)
        view! as WireRecord,
    ];
    views.sort(_compareTaskViewIds);
    listing['tasks'] = views;
    return encodeSuccessReply(listing);
  }
}

int _compareTaskViewIds(WireRecord first, WireRecord second) {
  final String firstId = (first['task']! as WireRecord)['id']! as String;
  final String secondId = (second['task']! as WireRecord)['id']! as String;
  return firstId.compareTo(secondId);
}

List<String> _listedIds(NodeBackedTaskRepository tasks) {
  return <String>[for (final Task task in tasks.listTasks()) task.id.value];
}

NodeBackedTaskRepository _openOrderedRepository(_IdOrderedWorkNode ordered) {
  final NodeCommandChannel channel = buildSimulatedChannel(ordered.answer);
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  return buildRigTaskRepository(
    channel: channel,
    workspaces: workspaces,
    jobs: NodeBackedJobRepository(
      channel: channel,
      workspaceRepository: workspaces,
      clock: FixedClock(taskRigMoment),
    ),
    livePollInterval: quietLivePollInterval,
  );
}

Future<List<String>> _reloadOrderedIds(_IdOrderedWorkNode ordered) async {
  final NodeBackedTaskRepository reloaded = _openOrderedRepository(ordered);
  await reloaded.load();
  final List<String> listed = _listedIds(reloaded);
  reloaded.dispose();
  return listed;
}

Future<void> _takeOrderedStep(
  Random random,
  _IdOrderedWorkNode ordered,
  NodeBackedTaskRepository tasks,
) async {
  final List<Task> listed = tasks.listTasks();
  if (listed.isNotEmpty && random.nextInt(4) == 0) {
    await tasks.deleteTask(pickOne(random, listed).id);
  } else if (random.nextInt(4) == 0) {
    addOneTimeTaskElsewhere(random, ordered.work);
    await tasks.applyChange(_tasksChanged);
  } else {
    await tasks.createTask(randomTaskDraft(random));
  }
}

Future<Task> _createAndStart(Random random, TaskRepositoryRig rig) async {
  final Task task = await rig.tasks.createTask(randomTaskDraft(random));
  await rig.tasks.startTask(task.id);
  return task;
}

void main() {
  test('test_node_backed_task_repository_create_task_property_order_matches_'
      'a_reload_from_an_id_ordered_server', () async {
    final Random random = seededRandom(51501);
    for (int i = 0; i < _rigIterations; i += 1) {
      final _IdOrderedWorkNode ordered = _IdOrderedWorkNode(
        SimulatedWorkNode(thisDeviceId: 'ordered-device'),
      );
      final NodeBackedTaskRepository tasks = _openOrderedRepository(ordered);

      for (int step = 0; step < _stepsPerRig; step += 1) {
        await _takeOrderedStep(random, ordered, tasks);

        final List<String> listed = _listedIds(tasks);
        expect(listed, await _reloadOrderedIds(ordered));
        expect(listed, List<String>.of(listed)..sort());
      }
      tasks.dispose();
    }
  });

  test('test_node_backed_task_repository_update_task_property_keeps_place_'
      'and_status', () async {
    final Random random = seededRandom(51502);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<Task> before = rig.tasks.listTasks();
      if (before.isEmpty) {
        closeTaskRepositoryRig(rig);
        continue;
      }
      final int position = random.nextInt(before.length);
      final TaskDraft draft = randomTaskDraft(random);

      final Task updated = await rig.tasks.updateTask(
        before[position].id,
        draft,
      );

      final List<Task> after = rig.tasks.listTasks();
      expect(after.length, before.length);
      expect(after[position].id, before[position].id);
      expect(after[position].status, before[position].status);
      expect(after[position].title, draft.title);
      expect(updated.status, before[position].status);
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_start_task_property_numbers_runs_'
      'per_task_and_marks_it_running', () async {
    final Random random = seededRandom(51503);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      final List<Task> created = <Task>[
        for (int task = 0; task < 3; task += 1)
          await rig.tasks.createTask(randomTaskDraft(random)),
      ];
      final Map<TaskId, int> startedCounts = <TaskId, int>{};

      for (int step = 0; step < _stepsPerRig; step += 1) {
        final Task task = pickOne(random, created);
        final Run run = await rig.tasks.startTask(task.id);
        startedCounts[task.id] = (startedCounts[task.id] ?? 0) + 1;

        expect(run.taskId, task.id);
        expect(run.number, startedCounts[task.id]);
        expect(rig.tasks.findTask(task.id).status, TaskStatus.running);
        expect(rig.tasks.listRuns(task.id).first.id, run.id);
        await rig.tasks.cancelRun(run.id);
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_cancel_run_property_cancels_that_'
      'run_and_frees_the_task', () async {
    final Random random = seededRandom(51504);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      final Task task = await _createAndStart(random, rig);
      final Run active = rig.tasks.listRuns(task.id).first;

      final Run cancelled = await rig.tasks.cancelRun(active.id);

      expect(cancelled.id, active.id);
      expect(cancelled.number, active.number);
      expect(cancelled.status, RunStatus.cancelled);
      expect(rig.tasks.findRun(active.id).status, RunStatus.cancelled);
      expect(rig.tasks.listRuns(task.id).length, 1);
      expect(rig.tasks.findTask(task.id).status, TaskStatus.toDo);
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_retry_run_property_reopens_the_'
      'same_run', () async {
    final Random random = seededRandom(51505);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      final Task task = await _createAndStart(random, rig);
      final Run first = rig.tasks.listRuns(task.id).first;
      await rig.tasks.cancelRun(first.id);

      final Run retried = await rig.tasks.retryRun(first.id);

      expect(retried.id, first.id);
      expect(retried.number, first.number);
      expect(retried.status, RunStatus.queued);
      expect(rig.tasks.listRuns(task.id).length, 1);
      expect(rig.tasks.findTask(task.id).status, TaskStatus.running);
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_delete_task_property_forgets_the_'
      'tasks_runs', () async {
    final Random random = seededRandom(51506);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = await openSeededTaskRepositoryRig(random);
      final List<Task> listed = rig.tasks.listTasks();
      if (listed.isEmpty) {
        closeTaskRepositoryRig(rig);
        continue;
      }
      final Task doomed = pickOne(random, listed);
      for (final Run run in rig.tasks.listRuns(doomed.id)) {
        rig.node.runs[run.id.value]!['status'] = 'done';
      }
      final List<Run> doomedRuns = rig.tasks.listRuns(doomed.id);
      final List<Run> keptRuns = <Run>[
        for (final Run run in listEveryListedRun(rig.tasks))
          if (run.taskId != doomed.id) run,
      ];

      await rig.tasks.deleteTask(doomed.id);

      expect(rig.tasks.listRuns(doomed.id), isEmpty);
      for (final Run run in doomedRuns) {
        expect(
          () => rig.tasks.findRun(run.id),
          throwsA(isA<RecordNotFound>()),
        );
      }
      for (final Run run in keptRuns) {
        expect(rig.tasks.findRun(run.id), same(run));
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test('test_node_backed_task_repository_start_task_property_second_start_'
      'is_a_conflict_refusal', () async {
    final Random random = seededRandom(51507);
    for (int i = 0; i < _rigIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      final Task task = await _createAndStart(random, rig);
      final String refusal =
          'the app server answered $_conflictStatus: '
          'the task is already running ${randomWordPhrase(random)}';
      rig.node.refusal = refusal;

      await expectLater(
        rig.tasks.startTask(task.id),
        throwsA(
          isA<AppServerRefusal>().having(
            (AppServerRefusal refused) => refused.status,
            'status',
            _conflictStatus,
          ),
        ),
      );
      expect(rig.tasks.listRuns(task.id).length, 1);
      expect(rig.tasks.findTask(task.id).status, TaskStatus.running);
      closeTaskRepositoryRig(rig);
    }
  });
}
