import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/node_backed/task_node_reads.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/workspace_work_rig.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_work_node.dart';
import 'support/task_repository_rig.dart';

const int _readIterations = 25;

List<String> _expectedWorkspaceTaskIds(WorkspaceWorkRig rig) {
  final WorkspaceId current = rig.workspaces.currentWorkspace().id;
  return <String>[
    for (final WireRecord task in rig.simulated.work.tasks.values)
      if (!isJob(task) &&
          rig.simulated.projectWorkspaces[task['project_id']] == current.value)
        task['id']! as String,
  ];
}

String _describeTask(Task task) {
  return '${task.id.value} ${task.projectId.value} ${task.status.name} '
      '${task.title} ${task.details}';
}

String _describeRun(Run run) {
  return '${run.id.value} ${run.taskId.value} ${run.number} '
      '${run.status.name} ${run.chat.length}';
}

void main() {
  test('test_fetch_current_workspace_tasks_property_no_workspace_lists_'
      'nothing_and_asks_nothing', () async {
    final Random random = seededRandom(52001);
    for (int i = 0; i < _readIterations; i += 1) {
      final SimulatedWorkNode simulated = SimulatedWorkNode(
        thisDeviceId: 'reads-device',
      );
      seedTasksWithRuns(random, simulated);
      final NodeCommandChannel channel = buildSimulatedChannel(
        simulated.answer,
      );
      final NodeBackedWorkspaceRepository noWorkspaces =
          NodeBackedWorkspaceRepository(
            channel: channel,
            clock: FixedClock(taskRigMoment),
            retryInterval: const Duration(seconds: 30),
            choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
          );

      final List<Task> tasks = await fetchCurrentWorkspaceTasks(
        channel: channel,
        workspaceRepository: noWorkspaces,
      );

      expect(tasks, isEmpty);
      expect(simulated.receivedCommands, isEmpty);
      noWorkspaces.dispose();
    }
  });

  test('test_fetch_current_workspace_tasks_property_lists_the_current_'
      'workspace_one_time_tasks_in_node_order', () async {
    final Random random = seededRandom(52002);
    for (int i = 0; i < _readIterations; i += 1) {
      final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));

      final List<Task> tasks = await fetchCurrentWorkspaceTasks(
        channel: buildSimulatedChannel(rig.simulated.answer),
        workspaceRepository: rig.workspaces,
      );

      final List<String> listedIds = <String>[
        for (final Task task in tasks) task.id.value,
      ];
      expect(listedIds, _expectedWorkspaceTaskIds(rig));
      expect(tasks.removeLast, throwsUnsupportedError);
      await closeWorkspaceWorkRig(rig);
    }
  });

  test('test_fetch_current_workspace_tasks_property_maps_each_wire_task_'
      'faithfully', () async {
    final Random random = seededRandom(52003);
    for (int i = 0; i < _readIterations; i += 1) {
      final TaskRepositoryRig rig = openTaskRepositoryRig(
        livePollInterval: quietLivePollInterval,
      );
      seedTasksWithRuns(random, rig.node);

      final List<Task> tasks = await fetchCurrentWorkspaceTasks(
        channel: buildSimulatedChannel(rig.node.answer),
        workspaceRepository: rig.workspaces,
      );

      for (final Task task in tasks) {
        final WireRecord wire = rig.node.tasks[task.id.value]!;
        final Task expected = mapTaskFromNode(node.Task.fromJson(wire));
        expect(_describeTask(task), _describeTask(expected));
      }
      closeTaskRepositoryRig(rig);
    }
  });

  test(
    'test_fetch_task_runs_property_returns_exactly_that_tasks_runs',
    () async {
      final Random random = seededRandom(52004);
      for (int i = 0; i < _readIterations; i += 1) {
        final TaskRepositoryRig rig = openTaskRepositoryRig(
          livePollInterval: quietLivePollInterval,
        );
        seedTasksWithRuns(random, rig.node);

        for (final String taskId in rig.node.tasks.keys) {
          final List<Run> runs = await fetchTaskRuns(
            channel: buildSimulatedChannel(rig.node.answer),
            taskId: TaskId(taskId),
          );
          expect(<String>{
            for (final Run run in runs) run.id.value,
          }, listSimulatedRunIdsOf(rig.node, TaskId(taskId)));
          expect(
            runs.map((Run run) => run.taskId.value),
            everyElement(taskId),
          );
        }
        closeTaskRepositoryRig(rig);
      }
    },
  );

  test('test_fetch_task_runs_property_unknown_task_has_no_runs', () async {
    final Random random = seededRandom(52005);
    final TaskRepositoryRig rig = openTaskRepositoryRig(
      livePollInterval: quietLivePollInterval,
    );
    seedTasksWithRuns(random, rig.node);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Run> runs = await fetchTaskRuns(
        channel: buildSimulatedChannel(rig.node.answer),
        taskId: TaskId('unknown ${randomText(random)}'),
      );
      expect(runs, isEmpty);
    }
    closeTaskRepositoryRig(rig);
  });

  test(
    'test_fetch_task_runs_property_maps_each_wire_run_faithfully',
    () async {
      final Random random = seededRandom(52006);
      for (int i = 0; i < _readIterations; i += 1) {
        final TaskRepositoryRig rig = openTaskRepositoryRig(
          livePollInterval: quietLivePollInterval,
        );
        seedTasksWithRuns(random, rig.node);

        for (final String taskId in rig.node.tasks.keys) {
          final List<Run> runs = await fetchTaskRuns(
            channel: buildSimulatedChannel(rig.node.answer),
            taskId: TaskId(taskId),
          );
          for (final Run run in runs) {
            final WireRecord wire = rig.node.runs[run.id.value]!;
            final Run expected = mapRunFromNode(node.Run.fromJson(wire));
            expect(_describeRun(run), _describeRun(expected));
          }
        }
        closeTaskRepositoryRig(rig);
      }
    },
  );
}
