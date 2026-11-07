import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

import 'job_inputs.dart';
import 'refusals.dart';
import 'workspace_work_rig.dart';

typedef WorkStep = Future<Object?> Function();

List<String> _describeWork(
  List<Task> records,
  TaskId Function(TaskId listedId) translate,
) {
  return <String>[
    for (final Task task in records)
      '${translate(task.id).value}\n${describeJobContent(task)}',
  ];
}

TaskId _keepIdentifier(TaskId listedId) => listedId;

List<String> describeFakeJobs(WorkspaceWorkRig rig) {
  return _describeWork(
    rig.fakeJobs.listJobs(),
    (TaskId fakeId) => findNodeIdOf(rig, fakeId),
  );
}

List<String> describeNodeJobs(WorkspaceWorkRig rig) {
  return _describeWork(rig.nodeJobs.listJobs(), _keepIdentifier);
}

List<String> describeFakeTasks(WorkspaceWorkRig rig) {
  return _describeWork(
    rig.fakeTasks.listTasks(),
    (TaskId fakeId) => findNodeIdOf(rig, fakeId),
  );
}

List<String> describeNodeTasks(WorkspaceWorkRig rig) {
  return _describeWork(rig.nodeTasks.listTasks(), _keepIdentifier);
}

bool _isFound(Object? Function() lookup) {
  try {
    lookup();
    return true;
  } on Object catch (error) {
    if (!isWorkRefusal(error)) {
      rethrow;
    }
    return false;
  }
}

bool isFoundAsJob(JobRepository repository, TaskId jobId) {
  return _isFound(() => repository.findJob(jobId));
}

bool isFoundAsTask(TaskRepository repository, TaskId taskId) {
  return _isFound(() => repository.findTask(taskId));
}

void expectWorkTwinsAgree(WorkspaceWorkRig rig) {
  expect(describeFakeJobs(rig), unorderedEquals(describeNodeJobs(rig)));
  expect(describeFakeTasks(rig), unorderedEquals(describeNodeTasks(rig)));
  for (final MapEntry<TaskId, TaskId> pair in rig.nodeIdOfFakeId.entries) {
    expect(
      isFoundAsJob(rig.fakeJobs, pair.key),
      isFoundAsJob(rig.nodeJobs, pair.value),
      reason: 'job ${pair.key.value}',
    );
    expect(
      isFoundAsTask(rig.fakeTasks, pair.key),
      isFoundAsTask(rig.nodeTasks, pair.value),
      reason: 'task ${pair.key.value}',
    );
  }
}

void expectSameRunTask(WorkspaceWorkRig rig, Run fakeRun, Run nodeRun) {
  expect(findNodeIdOf(rig, fakeRun.taskId), nodeRun.taskId);
  expect(fakeRun.number, nodeRun.number);
}

Future<bool> expectSameRefusal({
  required WorkStep fakeStep,
  required WorkStep nodeStep,
  required String reason,
}) async {
  final bool isFakeRefused = await isRefused(
    fakeStep,
    isRefusal: isWorkRefusal,
  );
  final bool isNodeRefused = await isRefused(
    nodeStep,
    isRefusal: isWorkRefusal,
  );
  expect(isFakeRefused, isNodeRefused, reason: reason);
  return isFakeRefused;
}
