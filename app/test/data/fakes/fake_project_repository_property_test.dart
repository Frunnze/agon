import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import 'support/project_inputs.dart';

const String _typePrefix = 'test_fake_project_repository';

ProjectId _randomMissingId(Random random) {
  return ProjectId('project-missing-${randomText(random)}');
}

Matcher _isProjectNotFound(ProjectId projectId) {
  return isA<RecordNotFound>()
      .having((RecordNotFound error) => error.kind, 'kind', 'project')
      .having(
        (RecordNotFound error) => error.identifier,
        'identifier',
        projectId.value,
      );
}

void main() {
  test('${_typePrefix}_constructor_property_keeps_every_project', () {
    final Random random = seededRandom(65601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Project> seeded = randomSeededProjects(random);

      final CountedProjects counted = buildCountedProjects(seeded);

      for (final Project project in seeded) {
        expect(
          identical(counted.repository.findProject(project.id), project),
          isTrue,
        );
      }
      expect(listAllProjectIds(counted.repository).length, seeded.length);
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_constructor_property_copies_the_given_list', () {
    final Random random = seededRandom(65602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Project> seeded = randomSeededProjects(random);
      final List<Project> callerList = List<Project>.of(seeded);
      final CountedProjects counted = buildCountedProjects(callerList);

      callerList.removeLast();
      callerList.shuffle(random);

      expect(listAllProjectIds(counted.repository).length, seeded.length);
    }
  });

  test('${_typePrefix}_constructor_property_refuses_repeated_ids', () {
    final Random random = seededRandom(65603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Project> seeded = randomSeededProjects(random);
      final Project repeated = randomProjectWithId(
        random,
        pickOne(random, seeded).id,
      );
      final List<Project> withRepeat = <Project>[...seeded, repeated]
        ..shuffle(random);

      expect(
        () => FakeProjectRepository(
          projects: withRepeat,
          taskWork: buildEmptyTaskWork(),
        ),
        throwsArgumentError,
      );
    }
  });

  test('${_typePrefix}_list_projects_property_only_that_workspace_in_'
      'order', () {
    final Random random = seededRandom(65604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Project> seeded = randomSeededProjects(random);
      final CountedProjects counted = buildCountedProjects(seeded);
      final WorkspaceId workspaceId = pickOne(random, projectWorkspaceIds);

      final List<Project> listed = counted.repository.listProjects(
        workspaceId,
      );

      final List<Project> expected = <Project>[
        for (final Project project in seeded)
          if (project.workspaceId == workspaceId) project,
      ];
      expect(listed, orderedEquals(expected));
    }
  });

  test('${_typePrefix}_list_projects_property_unknown_workspace_lists_'
      'nothing', () {
    final Random random = seededRandom(65605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final WorkspaceId elsewhere = WorkspaceId(
        'workspace-elsewhere-${randomText(random)}',
      );

      expect(counted.repository.listProjects(elsewhere), isEmpty);
    }
  });

  test('${_typePrefix}_list_projects_property_callers_cannot_change_'
      'it', () {
    final Random random = seededRandom(65606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Project> seeded = randomSeededProjects(random);
      final CountedProjects counted = buildCountedProjects(seeded);
      final List<Project> listed = counted.repository.listProjects(
        pickOne(random, projectWorkspaceIds),
      );

      expect(() => listed.add(seeded.first), throwsUnsupportedError);
      expect(listAllProjectIds(counted.repository).length, seeded.length);
    }
  });

  test('${_typePrefix}_find_project_property_round_trips_every_listed_'
      'project', () {
    final Random random = seededRandom(65607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final WorkspaceId workspaceId = pickOne(random, projectWorkspaceIds);

      for (final Project listed in counted.repository.listProjects(
        workspaceId,
      )) {
        final Project found = counted.repository.findProject(listed.id);
        expect(identical(found, listed), isTrue);
      }
    }
  });

  test('${_typePrefix}_find_project_property_unknown_ids_name_the_'
      'project', () {
    final Random random = seededRandom(65608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final ProjectId missing = _randomMissingId(random);

      expect(
        () => counted.repository.findProject(missing),
        throwsA(_isProjectNotFound(missing)),
      );
    }
  });

  test('${_typePrefix}_find_project_property_sees_the_latest_'
      'version', () async {
    final Random random = seededRandom(65609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project picked = pickOne(random, counted.seeded);
      final String address = randomCanonicalAddress(random);

      final Project updated = await counted.repository.addRepository(
        picked.id,
        randomRepositoryAt(random, address),
      );

      final Project found = counted.repository.findProject(picked.id);
      expect(identical(found, updated), isTrue);
      expect(listAddresses(found).last, address);
    }
  });

  test('${_typePrefix}_delete_project_property_removes_exactly_that_'
      'project', () async {
    final Random random = seededRandom(65610);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project deleted = pickOne(random, counted.seeded);

      await counted.repository.deleteProject(deleted.id);

      final List<ProjectId> expected = <ProjectId>[
        for (final ProjectId id in listAllProjectIds(
          buildCountedProjects(counted.seeded).repository,
        ))
          if (id != deleted.id) id,
      ];
      expect(listAllProjectIds(counted.repository), orderedEquals(expected));
      expect(counted.notifications.count, 1);
    }
  });

  test('${_typePrefix}_delete_project_property_unknown_ids_change_'
      'nothing', () async {
    final Random random = seededRandom(65611);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final ProjectId missing = _randomMissingId(random);

      await expectLater(
        counted.repository.deleteProject(missing),
        throwsA(_isProjectNotFound(missing)),
      );

      expect(
        listAllProjectIds(counted.repository).length,
        counted.seeded.length,
      );
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_delete_project_property_a_deleted_project_is_'
      'gone', () async {
    final Random random = seededRandom(65612);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedProjects counted = buildCountedProjects(
        randomSeededProjects(random),
      );
      final Project deleted = pickOne(random, counted.seeded);

      await counted.repository.deleteProject(deleted.id);

      expect(
        () => counted.repository.findProject(deleted.id),
        throwsA(_isProjectNotFound(deleted.id)),
      );
      expect(
        counted.repository.listProjects(deleted.workspaceId),
        isNot(contains(deleted)),
      );
      await expectLater(
        counted.repository.deleteProject(deleted.id),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
