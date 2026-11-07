import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import 'node_backed_harness.dart';
import 'simulated_work_node.dart';

const int _largestSeededTaskCount = 5;
const int _largestRunsPerTask = 3;
const Duration quietLivePollInterval = Duration(hours: 1);
final DateTime taskRigMoment = DateTime.utc(2026, 11, 7, 10);

typedef TaskRepositoryRig = ({
  SimulatedWorkNode node,
  WorkspaceRepository workspaces,
  NodeBackedJobRepository jobs,
  NodeBackedTaskRepository tasks,
});

TaskRepositoryRig openTaskRepositoryRig({required Duration livePollInterval}) {
  final SimulatedWorkNode simulated = SimulatedWorkNode(
    thisDeviceId: 'rig-device',
  );
  final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
  final NodeCommandChannel channel = buildSimulatedChannel(simulated.answer);
  final NodeBackedJobRepository jobs = NodeBackedJobRepository(
    channel: channel,
    workspaceRepository: workspaces,
    clock: FixedClock(taskRigMoment),
  );
  final NodeBackedTaskRepository tasks = buildRigTaskRepository(
    channel: channel,
    workspaces: workspaces,
    jobs: jobs,
    livePollInterval: livePollInterval,
  );
  return (node: simulated, workspaces: workspaces, jobs: jobs, tasks: tasks);
}

NodeBackedTaskRepository buildRigTaskRepository({
  required NodeCommandChannel channel,
  required WorkspaceRepository workspaces,
  required NodeBackedJobRepository jobs,
  required Duration livePollInterval,
}) {
  return NodeBackedTaskRepository(
    channel: channel,
    workspaceRepository: workspaces,
    livePollInterval: livePollInterval,
    jobRepository: jobs,
    clock: FixedClock(taskRigMoment),
  );
}

String addOneTimeTaskElsewhere(Random random, SimulatedWorkNode simulated) {
  final String taskId = simulated.addTaskFromElsewhere(random);
  simulated.tasks[taskId]!['schedule'] = null;
  return taskId;
}

void seedTasksWithRuns(Random random, SimulatedWorkNode simulated) {
  final int taskCount = random.nextInt(_largestSeededTaskCount + 1);
  for (int task = 0; task < taskCount; task += 1) {
    final String taskId = random.nextInt(4) == 0
        ? simulated.addTaskFromElsewhere(random)
        : addOneTimeTaskElsewhere(random, simulated);
    final int runCount = random.nextInt(_largestRunsPerTask + 1);
    for (int run = 0; run < runCount; run += 1) {
      simulated.addRunFromElsewhere(random, taskId);
    }
  }
}

Future<TaskRepositoryRig> openSeededTaskRepositoryRig(Random random) async {
  final TaskRepositoryRig rig = openTaskRepositoryRig(
    livePollInterval: quietLivePollInterval,
  );
  seedTasksWithRuns(random, rig.node);
  await rig.jobs.load();
  await rig.tasks.load();
  return rig;
}

List<String> listSimulatedOneTimeTaskIds(SimulatedWorkNode simulated) {
  return <String>[
    for (final WireRecord task in simulated.tasks.values)
      if (!isJob(task)) task['id']! as String,
  ];
}

Set<String> listSimulatedRunIdsOf(SimulatedWorkNode simulated, TaskId taskId) {
  return <String>{
    for (final WireRecord run in simulated.runs.values)
      if (run['task_id'] == taskId.value) run['id']! as String,
  };
}

List<Run> listEveryListedRun(NodeBackedTaskRepository tasks) {
  return <Run>[
    for (final Task task in tasks.listTasks()) ...tasks.listRuns(task.id),
  ];
}

int countReceivedCommands(SimulatedWorkNode simulated, String commandName) {
  int count = 0;
  for (final String received in simulated.receivedCommands) {
    if (received == commandName) {
      count += 1;
    }
  }
  return count;
}

void closeTaskRepositoryRig(TaskRepositoryRig rig) {
  rig.tasks.dispose();
  rig.jobs.dispose();
}
