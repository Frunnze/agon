import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import '../../support/random_inputs.dart';
import 'support/catalog_twin_checks.dart';
import 'support/catalog_twin_steps.dart';
import 'support/catalog_twin_world.dart';

const String _typePrefix = 'test_fake_project_repository';
const int _sequenceIterations = 25;
const int _longestSequence = 6;

List<ProjectId> _scopedProjects(Scope scope) {
  final ProjectScope projects = scope.projects;
  if (projects is OnlyProjects) {
    return projects.projects;
  }
  return const <ProjectId>[];
}

Set<ProjectId> _projectsNamedInLibrary(CatalogTwinWorld world) {
  return <ProjectId>{
    for (final Skill skill in world.fakeSkills.listSkills())
      ..._scopedProjects(skill.scope),
    for (final Rule rule in world.fakeRules.listRules())
      ..._scopedProjects(rule.scope),
  };
}

Future<int> _runDeletionSequence(Random random) async {
  final CatalogTwinWorld world = await buildCatalogTwinWorld(random);
  final int stepCount = 1 + random.nextInt(_longestSequence);
  int refusedCount = 0;

  for (int step = 0; step < stepCount; step += 1) {
    if (random.nextInt(3) == 0) {
      await stopRandomRunInBoth(random, world);
    } else {
      final bool isRefused = await deleteProjectInBoth(
        world,
        pickTwinProjectId(random, world),
      );
      refusedCount += isRefused ? 1 : 0;
    }
    await expectCatalogTwinsAgree(world);
  }
  closeCatalogTwinWorld(world);
  return refusedCount;
}

void main() {
  test('${_typePrefix}_delete_project_property_sequences_end_like_the_'
      'node', () async {
    final Random random = seededRandom(92101);
    int refusedCount = 0;

    for (int i = 0; i < _sequenceIterations; i += 1) {
      refusedCount += await _runDeletionSequence(random);
    }

    expect(refusedCount, greaterThan(0));
  });

  test('${_typePrefix}_delete_project_property_refuses_a_running_project_'
      'and_changes_nothing', () async {
    final Random random = seededRandom(92102);
    int runningCount = 0;

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final CatalogTwinWorld world = await buildCatalogTwinWorld(random);
      for (final Project project in world.seeds.projects) {
        final List<String> before = <String>[
          for (final Skill skill in world.fakeSkills.listSkills())
            skill.id.value,
        ];
        final bool isRefused = await deleteProjectInBoth(world, project.id);
        if (!isRefused) {
          continue;
        }
        runningCount += 1;
        expect(world.fakeProjects.findProject(project.id).name, project.name);
        expect(<String>[
          for (final Skill skill in world.fakeSkills.listSkills())
            skill.id.value,
        ], before);
      }
      await expectCatalogTwinsAgree(world);
      closeCatalogTwinWorld(world);
    }

    expect(runningCount, greaterThan(0));
  });

  test('${_typePrefix}_link_library_property_deleted_projects_leave_no_'
      'trace_in_skill_or_rule_scopes', () async {
    final Random random = seededRandom(92103);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final CatalogTwinWorld world = await buildCatalogTwinWorld(random);
      final Set<ProjectId> deleted = <ProjectId>{};

      for (final Project project in world.seeds.projects) {
        await stopEveryRunInBoth(random, world);
        final bool isRefused = await deleteProjectInBoth(world, project.id);
        expect(isRefused, isFalse);
        deleted.add(project.id);
        for (final WorkspaceId workspaceId in world.seeds.workspaceIds) {
          await world.fakeWorkspaces.switchWorkspace(workspaceId);
          await world.nodeWorkspaces.switchWorkspace(workspaceId);
          expect(
            _projectsNamedInLibrary(world).intersection(deleted),
            isEmpty,
          );
        }
      }
      await expectCatalogTwinsAgree(world);
      closeCatalogTwinWorld(world);
    }
  });
}
