import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../support/random_inputs.dart';
import 'support/held_next_reply_transport.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';
import 'support/task_repository_rig.dart';

const int _heldIterations = 25;
const String _doneStatus = 'done';

typedef _HeldRig = ({
  SimulatedWorkNode node,
  HeldNextReplyTransport transport,
  NodeBackedTaskRepository tasks,
});

Future<_HeldRig> _openHeldRig(Random random) async {
  final SimulatedWorkNode simulated = SimulatedWorkNode(
    thisDeviceId: 'held-device',
  );
  seedTasksWithRuns(random, simulated);
  addOneTimeTaskElsewhere(random, simulated);
  final HeldNextReplyTransport transport = HeldNextReplyTransport(
    answer: simulated.answer,
  );
  final NodeCommandChannel channel = NodeCommandChannel(transport: transport);
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  final NodeBackedTaskRepository tasks = buildRigTaskRepository(
    channel: channel,
    workspaces: workspaces,
    jobs: NodeBackedJobRepository(
      channel: channel,
      workspaceRepository: workspaces,
      clock: FixedClock(taskRigMoment),
    ),
    livePollInterval: quietLivePollInterval,
  );
  await tasks.load();
  return (node: simulated, transport: transport, tasks: tasks);
}

void _finishRunsOf(SimulatedWorkNode simulated, TaskId taskId) {
  for (final WireRecord run in simulated.runs.values) {
    if (run['task_id'] == taskId.value) {
      run['status'] = _doneStatus;
    }
  }
}

String _describeStoredRun(Run run) {
  return '${run.id.value} ${run.number} ${run.status.name} ${run.chat.length}';
}

String _describeSimulatedRun(SimulatedWorkNode simulated, RunId runId) {
  final node.Run wireRun = node.Run.fromJson(simulated.runs[runId.value]);
  return _describeStoredRun(mapRunFromNode(wireRun));
}

void main() {
  test('test_store_run_if_newest_property_late_start_reply_keeps_the_newer_'
      'run', () async {
    final Random random = seededRandom(51701);
    for (int i = 0; i < _heldIterations; i += 1) {
      final _HeldRig rig = await _openHeldRig(random);
      final Task task = rig.tasks.listTasks().last;
      rig.transport.holdNextReply('start_task');

      final Future<Run> starting = rig.tasks.startTask(task.id);
      await rig.transport.heldReplyArrival;
      final RunId runId = RunId(rig.node.runs.keys.last);
      rig.node.changeRunFromElsewhere(random, runId.value);
      await rig.tasks.refreshRun(runId);
      rig.transport.releaseHeldReply();
      await starting;

      expect(
        _describeStoredRun(rig.tasks.findRun(runId)),
        _describeSimulatedRun(rig.node, runId),
      );
      rig.tasks.dispose();
    }
  });

  test('test_store_run_if_newest_property_late_listing_keeps_the_newer_'
      'run', () async {
    final Random random = seededRandom(51702);
    for (int i = 0; i < _heldIterations; i += 1) {
      final _HeldRig rig = await _openHeldRig(random);
      final Task task = rig.tasks.listTasks().first;
      final String runId = rig.node.addRunFromElsewhere(random, task.id.value);
      rig.transport.holdNextReply('list_runs');

      final Future<void> loading = rig.tasks.load();
      await rig.transport.heldReplyArrival;
      rig.node.changeRunFromElsewhere(random, runId);
      await rig.tasks.refreshRun(RunId(runId));
      rig.transport.releaseHeldReply();
      await loading;

      expect(
        _describeStoredRun(rig.tasks.findRun(RunId(runId))),
        _describeSimulatedRun(rig.node, RunId(runId)),
      );
      rig.tasks.dispose();
    }
  });

  test('test_store_run_if_newest_property_late_refresh_keeps_the_newer_'
      'run', () async {
    final Random random = seededRandom(51703);
    for (int i = 0; i < _heldIterations; i += 1) {
      final _HeldRig rig = await _openHeldRig(random);
      final Task task = pickOne(random, rig.tasks.listTasks());
      final String runId = rig.node.addRunFromElsewhere(random, task.id.value);
      rig.transport.holdNextReply('show_run');

      final Future<Run> olderRefresh = rig.tasks.refreshRun(RunId(runId));
      await rig.transport.heldReplyArrival;
      rig.node.changeRunFromElsewhere(random, runId);
      final Run newer = await rig.tasks.refreshRun(RunId(runId));
      rig.transport.releaseHeldReply();
      final Run returnedLate = await olderRefresh;

      expect(rig.tasks.findRun(RunId(runId)), same(newer));
      expect(returnedLate, same(newer));
      rig.tasks.dispose();
    }
  });

  test(
    'test_store_run_property_replaces_runs_by_id_without_duplicates',
    () async {
      final Random random = seededRandom(51704);
      for (int i = 0; i < _heldIterations; i += 1) {
        final _HeldRig rig = await _openHeldRig(random);
        final Task task = pickOne(random, rig.tasks.listTasks());
        final String runId = rig.node.addRunFromElsewhere(
          random,
          task.id.value,
        );
        final int refreshCount = 1 + random.nextInt(4);

        for (int refresh = 0; refresh < refreshCount; refresh += 1) {
          rig.node.changeRunFromElsewhere(random, runId);
          await rig.tasks.refreshRun(RunId(runId));
        }

        final List<String> listedIds = <String>[
          for (final Run run in rig.tasks.listRuns(task.id)) run.id.value,
        ];
        expect(listedIds.toSet().length, listedIds.length);
        expect(listedIds.toSet(), listSimulatedRunIdsOf(rig.node, task.id));
        rig.tasks.dispose();
      }
    },
  );

  test('test_store_run_property_leaves_other_runs_untouched', () async {
    final Random random = seededRandom(51705);
    for (int i = 0; i < _heldIterations; i += 1) {
      final _HeldRig rig = await _openHeldRig(random);
      final List<Run> before = listEveryListedRun(rig.tasks);
      final Task task = pickOne(random, rig.tasks.listTasks());
      final String runId = rig.node.addRunFromElsewhere(random, task.id.value);

      await rig.tasks.refreshRun(RunId(runId));

      for (final Run run in before) {
        expect(rig.tasks.findRun(run.id), same(run));
      }
      rig.tasks.dispose();
    }
  });

  test('test_store_run_property_stored_run_matches_the_node', () async {
    final Random random = seededRandom(51706);
    for (int i = 0; i < _heldIterations; i += 1) {
      final _HeldRig rig = await _openHeldRig(random);
      final Task task = pickOne(random, rig.tasks.listTasks());
      final String runId = rig.node.addRunFromElsewhere(random, task.id.value);

      final Run refreshed = await rig.tasks.refreshRun(RunId(runId));

      expect(
        _describeStoredRun(refreshed),
        _describeSimulatedRun(rig.node, RunId(runId)),
      );
      expect(rig.tasks.findRun(RunId(runId)), same(refreshed));
      rig.tasks.dispose();
    }
  });

  test('test_forget_runs_of_task_property_late_refresh_cannot_bring_a_run_'
      'back', () async {
    final Random random = seededRandom(51707);
    for (int i = 0; i < _heldIterations; i += 1) {
      final _HeldRig rig = await _openHeldRig(random);
      final Task task = pickOne(random, rig.tasks.listTasks());
      final String runId = rig.node.addRunFromElsewhere(random, task.id.value);
      await rig.tasks.refreshRun(RunId(runId));
      _finishRunsOf(rig.node, task.id);
      rig.transport.holdNextReply('show_run');

      final Future<Run> lateRefresh = rig.tasks.refreshRun(RunId(runId));
      await rig.transport.heldReplyArrival;
      await rig.tasks.deleteTask(task.id);
      rig.transport.releaseHeldReply();

      await expectLater(lateRefresh, throwsA(isA<RecordNotFound>()));
      expect(rig.tasks.listRuns(task.id), isEmpty);
      rig.tasks.dispose();
    }
  });

  test('test_forget_runs_of_task_property_late_listing_cannot_bring_runs_'
      'back', () async {
    final Random random = seededRandom(51708);
    for (int i = 0; i < _heldIterations; i += 1) {
      final _HeldRig rig = await _openHeldRig(random);
      final Task task = rig.tasks.listTasks().first;
      rig.node.addRunFromElsewhere(random, task.id.value);
      _finishRunsOf(rig.node, task.id);
      rig.transport.holdNextReply('list_runs');

      final Future<void> loading = rig.tasks.load();
      await rig.transport.heldReplyArrival;
      await rig.tasks.deleteTask(task.id);
      rig.transport.releaseHeldReply();
      await loading;

      expect(rig.tasks.listRuns(task.id), isEmpty);
      expect(
        rig.tasks.listTasks().map((Task listed) => listed.id),
        isNot(contains(task.id)),
      );
      rig.tasks.dispose();
    }
  });

  test('test_forget_runs_of_task_property_keeps_other_tasks_runs', () async {
    final Random random = seededRandom(51709);
    for (int i = 0; i < _heldIterations; i += 1) {
      final _HeldRig rig = await _openHeldRig(random);
      final Task task = pickOne(random, rig.tasks.listTasks());
      _finishRunsOf(rig.node, task.id);
      final List<Run> otherRuns = <Run>[
        for (final Run run in listEveryListedRun(rig.tasks))
          if (run.taskId != task.id) run,
      ];

      await rig.tasks.deleteTask(task.id);

      for (final Run run in otherRuns) {
        expect(rig.tasks.findRun(run.id), same(run));
      }
      rig.tasks.dispose();
    }
  });
}
