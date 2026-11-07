import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../node_backed/support/simulated_work_node.dart';
import 'catalog_twin_world.dart';
import 'simulated_scoped_rules.dart';
import 'workspace_skill_inputs.dart';

bool isCatalogRefusal(Object error) {
  return error is StateError || error is RecordNotFound;
}

List<String> _listWorkspaceIds(WorkspaceRepository repository) {
  return <String>[
    for (final Workspace workspace in repository.listWorkspaces())
      workspace.id.value,
  ];
}

List<String> _listProjectNames(
  ProjectRepository repository,
  WorkspaceId workspaceId,
) {
  return <String>[
    for (final Project project in repository.listProjects(workspaceId))
      '${project.id.value} ${project.name}',
  ];
}

List<String> _describeFakeWork(CatalogTwinWorld world) {
  final List<String> descriptions = <String>[];
  for (final Task task in world.fakeTasks.listTasksAndJobs()) {
    final List<String> runIds = <String>[
      for (final Run run in world.fakeTasks.listRuns(task.id)) run.id.value,
    ];
    runIds.sort();
    final List<String> skillIds = <String>[
      for (final SkillId skillId in task.skills) skillId.value,
    ];
    descriptions.add('${task.id.value} $skillIds $runIds');
  }
  return descriptions;
}

List<String> _describeSimulatedWork(CatalogTwinWorld world) {
  final List<String> descriptions = <String>[];
  for (final WireRecord task in world.simulated.work.tasks.values) {
    final List<String> runIds = <String>[
      for (final WireRecord run in world.simulated.work.runs.values)
        if (run['task_id'] == task['id']) run['id']! as String,
    ];
    runIds.sort();
    final List<String> skillIds = <String>[
      for (final Object? skillId in task['skills']! as List<Object?>)
        skillId! as String,
    ];
    descriptions.add('${task['id']} $skillIds $runIds');
  }
  return descriptions;
}

Future<void> _expectSameLibraryIn(
  CatalogTwinWorld world,
  WorkspaceId workspaceId,
) async {
  await world.nodeWorkspaces.switchWorkspace(workspaceId);
  await world.fakeWorkspaces.switchWorkspace(workspaceId);
  await world.nodeSkills.load();
  await world.nodeRules.load();
  await world.nodeProjects.load();

  expect(
    describeSkillsInScope(world.fakeSkills.listSkills()),
    orderedEquals(describeSkillsInScope(world.nodeSkills.listSkills())),
    reason: 'skills in ${workspaceId.value}',
  );
  expect(
    describeRuleListing(world.fakeRules),
    orderedEquals(describeRuleListing(world.nodeRules)),
    reason: 'rules in ${workspaceId.value}',
  );
  expect(
    _listProjectNames(world.fakeProjects, workspaceId),
    orderedEquals(_listProjectNames(world.nodeProjects, workspaceId)),
    reason: 'projects in ${workspaceId.value}',
  );
}

Future<void> expectCatalogTwinsAgree(CatalogTwinWorld world) async {
  expect(
    _listWorkspaceIds(world.fakeWorkspaces),
    orderedEquals(_listWorkspaceIds(world.nodeWorkspaces)),
  );
  final WorkspaceId current = world.nodeWorkspaces.currentWorkspace().id;
  expect(world.fakeWorkspaces.currentWorkspace().id, current);

  for (final Workspace workspace in world.nodeWorkspaces.listWorkspaces()) {
    await _expectSameLibraryIn(world, workspace.id);
  }
  await _expectSameLibraryIn(world, current);
  expect(
    _describeFakeWork(world),
    orderedEquals(_describeSimulatedWork(world)),
  );
}
