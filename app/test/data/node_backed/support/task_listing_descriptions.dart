import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../support/random_inputs.dart';
import 'node_backed_harness.dart';
import 'simulated_work_node.dart';
import 'task_repository_rig.dart';

List<String> describeRigListing(TaskRepositoryRig rig) {
  final List<String> described = <String>[];
  for (final Task task in rig.tasks.listTasks()) {
    described.add('${task.id.value} ${task.status.name} ${task.title}');
    for (final Run run in rig.tasks.listRuns(task.id)) {
      described.add('${task.id.value} ${run.id.value} ${run.status.name}');
    }
  }
  return described;
}

TaskStatus findSimulatedTaskStatus(
  SimulatedWorkNode simulated,
  String taskId,
) {
  final node.TaskStatus status = node.TaskStatus.decode(
    simulated.tasks[taskId]!['status'],
  );
  return mapTaskStatusFromNode(status);
}

List<String> describeSimulatedStatuses(SimulatedWorkNode simulated) {
  return <String>[
    for (final String taskId in listSimulatedOneTimeTaskIds(simulated))
      '$taskId ${findSimulatedTaskStatus(simulated, taskId).name}',
  ];
}

List<String> describeListedStatuses(TaskRepositoryRig rig) {
  return <String>[
    for (final Task task in rig.tasks.listTasks())
      '${task.id.value} ${task.status.name}',
  ];
}

Future<void> takeRandomTaskEdit(Random random, TaskRepositoryRig rig) async {
  final List<Task> listed = rig.tasks.listTasks();
  final int choice = listed.isEmpty ? 0 : random.nextInt(4);
  switch (choice) {
    case 0:
      await rig.tasks.createTask(randomTaskDraft(random));
    case 1:
      final TaskDraft draft = randomTaskDraft(random);
      await rig.tasks.updateTask(pickOne(random, listed).id, draft);
    case 2:
      await rig.tasks.startTask(pickOne(random, listed).id);
    default:
      final Task doomed = pickOne(random, listed);
      for (final WireRecord run in rig.node.runs.values) {
        if (run['task_id'] == doomed.id.value) {
          run['status'] = 'failed';
        }
      }
      await rig.tasks.deleteTask(doomed.id);
  }
}
