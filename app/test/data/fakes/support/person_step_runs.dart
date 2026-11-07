import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../../support/random_inputs.dart';
import '../../../support/workflow_repositories.dart';
import '../../node_backed/support/node_backed_harness.dart';
import 'task_inputs.dart';

const String _runningStatus = 'running';

Task _buildAskingTask(Random random, TaskId taskId) {
  return Task.fromDraft(
    id: taskId,
    draft: randomTaskDraft(random),
    schedule: null,
    status: TaskStatus.running,
    createdAt: randomUtcMoment(random),
  );
}

FakeTaskRepository buildRunsAskingSteps(
  Random random,
  List<OpenPersonStep> openSteps,
) {
  final Map<TaskId, Task> tasks = <TaskId, Task>{};
  final Map<RunId, Run> runs = <RunId, Run>{};
  for (final OpenPersonStep openStep in openSteps) {
    tasks[openStep.taskId] ??= _buildAskingTask(random, openStep.taskId);
    runs[openStep.runId] ??= buildSeededRun(
      random,
      runId: openStep.runId.value,
      taskId: openStep.taskId,
      number: runs.length + 1,
      status: _runningStatus,
    );
  }

  return buildTaskRepository(
    tasks: tasks.values.toList(),
    runs: runs.values.toList(),
    workflows: buildGalleryWorkflowRepository(),
  );
}
