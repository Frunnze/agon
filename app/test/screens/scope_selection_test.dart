import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/shared/scope_catalog_lookup.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';

import '../support/random_inputs.dart';
import '../support/sample_records.dart';
import '../support/sample_scopes.dart';

ProjectId pickAllowedProject(Random random, ScopeSelection selection) {
  final List<Project> allowed = galleryCatalog.listProjectsIn(
    selection.workspaceIds,
  );

  return pickOne(random, allowed).id;
}

ScopeSelection applyRandomChange(Random random, ScopeSelection selection) {
  final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
  final ProjectId projectId = pickAllowedProject(random, selection);

  switch (random.nextInt(4)) {
    case 0:
      return selection.withWorkspace(workspaceId, galleryCatalog);
    case 1:
      return selection.withoutWorkspace(workspaceId, galleryCatalog);
    case 2:
      return selection.withProject(projectId, galleryCatalog);
    default:
      return selection.withoutProject(projectId);
  }
}

ScopeSelection randomSelection(Random random) {
  ScopeSelection selection = ScopeSelection.everywhere();
  for (int index = 0; index < random.nextInt(8); index += 1) {
    selection = applyRandomChange(random, selection);
  }
  return selection;
}

void main() {
  test('test_from_scope_property_round_trips_through_to_scope', () {
    final Random random = seededRandom(9611);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection selection = randomSelection(random);
      final ScopeSelection restored = ScopeSelection.fromScope(
        selection.toScope(),
      );

      expect(restored.workspaceIds, selection.workspaceIds);
      expect(restored.projectIds, selection.projectIds);
    }
  });

  test('test_to_scope_property_empty_choice_means_all', () {
    final Random random = seededRandom(9601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection selection = randomSelection(random);
      final Scope scope = selection.toScope();
      final WorkspaceScope workspaces = scope.workspaces;
      final ProjectScope projects = scope.projects;

      if (selection.workspaceIds.isEmpty) {
        expect(workspaces, isA<AllWorkspaces>());
      } else {
        expect(
          (workspaces as OnlyWorkspaces).workspaces,
          selection.workspaceIds,
        );
      }
      if (selection.projectIds.isEmpty) {
        expect(projects, isA<AllProjects>());
      } else {
        expect((projects as OnlyProjects).projects, selection.projectIds);
      }
    }
  });

  test('test_with_workspace_property_adds_once_and_keeps_projects_inside', () {
    final Random random = seededRandom(9602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection before = randomSelection(random);
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
      final ScopeSelection after = before.withWorkspace(
        workspaceId,
        galleryCatalog,
      );
      final List<Project> allowed = galleryCatalog.listProjectsIn(
        after.workspaceIds,
      );

      expect(after.workspaceIds.where((WorkspaceId id) => id == workspaceId), [
        workspaceId,
      ]);
      for (final ProjectId projectId in after.projectIds) {
        expect(
          allowed.any((Project project) => project.id == projectId),
          isTrue,
        );
      }
    }
  });

  test(
    'test_without_workspace_property_removes_and_keeps_projects_inside',
    () {
      final Random random = seededRandom(9603);

      for (int i = 0; i < propertyIterations; i += 1) {
        final ScopeSelection before = randomSelection(random);
        final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
        final ScopeSelection after = before.withoutWorkspace(
          workspaceId,
          galleryCatalog,
        );
        final List<Project> allowed = galleryCatalog.listProjectsIn(
          after.workspaceIds,
        );

        expect(after.workspaceIds.contains(workspaceId), isFalse);
        for (final ProjectId projectId in after.projectIds) {
          expect(
            allowed.any((Project project) => project.id == projectId),
            isTrue,
          );
        }
      }
    },
  );

  test('test_with_project_property_adds_once', () {
    final Random random = seededRandom(9604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection before = randomSelection(random);
      final ProjectId projectId = pickAllowedProject(random, before);
      final ScopeSelection after = before
          .withProject(projectId, galleryCatalog)
          .withProject(projectId, galleryCatalog);

      expect(
        after.projectIds.where((ProjectId id) => id == projectId).length,
        1,
      );
      expect(after.workspaceIds, before.workspaceIds);
    }
  });

  test('test_without_project_property_removes_only_that_project', () {
    final Random random = seededRandom(9605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection before = randomSelection(random);
      final ProjectId projectId = pickOne(random, sampleProjectIds);
      final ScopeSelection after = before.withoutProject(projectId);

      expect(after.projectIds.contains(projectId), isFalse);
      expect(
        after.projectIds,
        before.projectIds.where((ProjectId id) => id != projectId).toList(),
      );
    }
  });

  test('test_with_project_fuzz_property_outside_projects_fail', () {
    final Random random = seededRandom(9607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection onlyPersonal = ScopeSelection.everywhere()
          .withWorkspace(GalleryWorkspaceIds.personal, galleryCatalog);
      final ProjectId acmeProject = pickOne(random, sampleProjectIds);

      expect(
        () => onlyPersonal.withProject(acmeProject, galleryCatalog),
        throwsArgumentError,
      );
      expect(
        () => onlyPersonal.withProject(
          ProjectId(randomText(random)),
          galleryCatalog,
        ),
        throwsArgumentError,
      );
    }
  });

  test('test_scope_selection_fuzz_property_never_duplicates_ids', () {
    final Random random = seededRandom(9606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeSelection selection = randomSelection(random);

      expect(
        selection.workspaceIds.toSet().length,
        selection.workspaceIds.length,
      );
      expect(selection.projectIds.toSet().length, selection.projectIds.length);
    }
  });

  test('test_collect_scope_catalog_property_every_workspace_project', () {
    final ScopeCatalog catalog = collectScopeCatalog(
      workspaceRepository: buildGalleryDependencies().workspaceRepository,
      projectRepository: buildGalleryDependencies().projectRepository,
    );

    expect(catalog.workspaces, galleryWorkspaces);
    expect(
      catalog.projects.map((Project project) => project.id).toSet(),
      galleryProjects.map((Project project) => project.id).toSet(),
    );
  });
}
