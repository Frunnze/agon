import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';

import '../../../support/random_inputs.dart';
import '../../node_backed/support/simulated_work_node.dart';
import 'catalog_twin_checks.dart';
import 'catalog_twin_world.dart';
import 'refusals.dart';

const ProjectId missingTwinProjectId = ProjectId('project-missing');
const String _cancelledStatus = 'cancelled';

List<Run> _listUnfinishedRuns(CatalogTwinWorld world) {
  return <Run>[
    for (final Task task in world.fakeTasks.listTasksAndJobs())
      for (final Run run in world.fakeTasks.listRuns(task.id))
        if (isRunActive(run)) run,
  ];
}

Future<bool> stopRandomRunInBoth(Random random, CatalogTwinWorld world) async {
  final List<Run> unfinished = _listUnfinishedRuns(world);
  if (unfinished.isEmpty) {
    return false;
  }
  final Run stopped = pickOne(random, unfinished);

  await world.fakeTasks.cancelRun(stopped.id);
  final WireRecord simulatedRun = world.simulated.work.runs[stopped.id.value]!;
  simulatedRun['status'] = _cancelledStatus;
  return true;
}

Future<void> stopEveryRunInBoth(Random random, CatalogTwinWorld world) async {
  bool hasStoppedOne = await stopRandomRunInBoth(random, world);
  while (hasStoppedOne) {
    hasStoppedOne = await stopRandomRunInBoth(random, world);
  }
}

ProjectId pickTwinProjectId(Random random, CatalogTwinWorld world) {
  if (random.nextInt(5) == 0) {
    return missingTwinProjectId;
  }
  final Project project = pickOne(random, world.seeds.projects);
  return project.id;
}

Future<bool> deleteProjectInBoth(
  CatalogTwinWorld world,
  ProjectId projectId,
) async {
  final bool isFakeRefused = await isRefused(
    () => world.fakeProjects.deleteProject(projectId),
    isRefusal: isCatalogRefusal,
  );
  final bool isNodeRefused = await isRefused(
    () => world.nodeProjects.deleteProject(projectId),
    isRefusal: isCatalogRefusal,
  );

  expect(isFakeRefused, isNodeRefused, reason: projectId.value);
  return isFakeRefused;
}

Future<bool> deleteWorkspaceInBoth(
  CatalogTwinWorld world,
  WorkspaceId workspaceId,
) async {
  final bool isFakeRefused = await isRefused(
    () => world.fakeWorkspaces.deleteWorkspace(workspaceId),
    isRefusal: isCatalogRefusal,
  );
  final bool isNodeRefused = await isRefused(
    () => world.nodeWorkspaces.deleteWorkspace(workspaceId),
    isRefusal: isCatalogRefusal,
  );

  expect(isFakeRefused, isNodeRefused, reason: workspaceId.value);
  return isFakeRefused;
}
