import 'dart:math';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../../support/random_inputs.dart';
import 'workspace_work_checks.dart';
import 'workspace_work_rig.dart';

typedef WorkRigStep = Future<void> Function(
  Random random,
  WorkspaceWorkRig rig,
);

const int _longestSequence = 8;

Future<void> createJobInBoth(Random random, WorkspaceWorkRig rig) async {
  final JobDraft draft = randomWorkJobDraft(random, rig.projects);
  Task? fakeCreated;
  Task? nodeCreated;

  final bool isRefused = await expectSameRefusal(
    fakeStep: () async => fakeCreated = await rig.fakeJobs.createJob(draft),
    nodeStep: () async => nodeCreated = await rig.nodeJobs.createJob(draft),
    reason: 'create job in ${draft.task.projectId.value}',
  );
  if (!isRefused) {
    rig.nodeIdOfFakeId[fakeCreated!.id] = nodeCreated!.id;
  }
}

Future<void> updateJobInBoth(Random random, WorkspaceWorkRig rig) async {
  final TaskId fakeId = pickWorkTaskId(random, rig);
  final JobDraft draft = randomWorkJobDraft(random, rig.projects);

  await expectSameRefusal(
    fakeStep: () => rig.fakeJobs.updateJob(fakeId, draft),
    nodeStep: () => rig.nodeJobs.updateJob(findNodeIdOf(rig, fakeId), draft),
    reason: 'update job ${fakeId.value} in ${draft.task.projectId.value}',
  );
}

Future<void> deleteJobInBoth(Random random, WorkspaceWorkRig rig) async {
  final TaskId fakeId = pickWorkTaskId(random, rig);

  await expectSameRefusal(
    fakeStep: () => rig.fakeJobs.deleteJob(fakeId),
    nodeStep: () => rig.nodeJobs.deleteJob(findNodeIdOf(rig, fakeId)),
    reason: 'delete job ${fakeId.value}',
  );
}

Future<void> createTaskInBoth(Random random, WorkspaceWorkRig rig) async {
  final TaskDraft draft = randomWorkDraft(random, rig.projects);
  Task? fakeCreated;
  Task? nodeCreated;

  final bool isRefused = await expectSameRefusal(
    fakeStep: () async => fakeCreated = await rig.fakeTasks.createTask(draft),
    nodeStep: () async => nodeCreated = await rig.nodeTasks.createTask(draft),
    reason: 'create task in ${draft.projectId.value}',
  );
  if (!isRefused) {
    rig.nodeIdOfFakeId[fakeCreated!.id] = nodeCreated!.id;
  }
}

Future<void> updateTaskInBoth(Random random, WorkspaceWorkRig rig) async {
  final TaskId fakeId = pickWorkTaskId(random, rig);
  final TaskDraft draft = randomWorkDraft(random, rig.projects);

  await expectSameRefusal(
    fakeStep: () => rig.fakeTasks.updateTask(fakeId, draft),
    nodeStep: () => rig.nodeTasks.updateTask(findNodeIdOf(rig, fakeId), draft),
    reason: 'update task ${fakeId.value} in ${draft.projectId.value}',
  );
}

Future<void> startTaskInBoth(Random random, WorkspaceWorkRig rig) async {
  final TaskId fakeId = pickWorkTaskId(random, rig);
  Run? fakeRun;
  Run? nodeRun;

  final bool isRefused = await expectSameRefusal(
    fakeStep: () async => fakeRun = await rig.fakeTasks.startTask(fakeId),
    nodeStep: () async =>
        nodeRun = await rig.nodeTasks.startTask(findNodeIdOf(rig, fakeId)),
    reason: 'start ${fakeId.value}',
  );
  if (!isRefused) {
    expectSameRunTask(rig, fakeRun!, nodeRun!);
  }
}

Future<void> deleteTaskInBoth(Random random, WorkspaceWorkRig rig) async {
  final TaskId fakeId = pickWorkTaskId(random, rig);

  await expectSameRefusal(
    fakeStep: () => rig.fakeTasks.deleteTask(fakeId),
    nodeStep: () => rig.nodeTasks.deleteTask(findNodeIdOf(rig, fakeId)),
    reason: 'delete task ${fakeId.value}',
  );
}

WorkRigStep pickWorkStep(
  Random random, {
  required WorkRigStep focus,
  required List<WorkRigStep> others,
}) {
  if (random.nextInt(3) == 0) {
    return pickOne(random, <WorkRigStep>[switchWorkRigWorkspace, ...others]);
  }
  return focus;
}

Future<void> runWorkTwinSequences({
  required int seed,
  required int iterations,
  required WorkRigStep focus,
  required List<WorkRigStep> others,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < iterations; i += 1) {
    final WorkspaceWorkRig rig = await buildWorkspaceWorkRig(random);
    expectWorkTwinsAgree(rig);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int step = 0; step < stepCount; step += 1) {
      final WorkRigStep chosen = pickWorkStep(
        random,
        focus: focus,
        others: others,
      );
      await chosen(random, rig);
      await rig.nodeJobs.load();
      await rig.nodeTasks.load();
      expectWorkTwinsAgree(rig);
    }
    await closeWorkspaceWorkRig(rig);
  }
}
