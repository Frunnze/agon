import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';

FakeWorkspaceRepository buildGalleryWorkspaceRepository() {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: GalleryWorkspaceIds.acme,
    appServerStatus: AppServerStatus(
      address: 'relay.acme.dev',
      state: AppServerState.unreachable,
      lastConnectedAt: galleryNow,
      retryInterval: const Duration(seconds: 10),
    ),
    appServerGroup: galleryAppServerGroup,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    clock: FixedClock(galleryNow),
  );
}

Repository randomRepository(Random random) {
  return Repository(
    address: 'github.com/acme/${random.nextInt(1000000)}',
    defaultBranch: 'main',
    agentAccess: pickOne(random, AgentAccess.values),
  );
}

void main() {
  test('test_list_projects_property_only_that_workspace', () {
    final Random random = seededRandom(501);
    final FakeProjectRepository repository = FakeProjectRepository(
      projects: galleryProjects,
      taskWork: buildEmptyTaskWork(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace workspace = pickOne(random, galleryWorkspaces);
      final List<Project> projects = repository.listProjects(workspace.id);

      expect(projects, isNotEmpty);
      expect(
        projects.every((Project p) => p.workspaceId == workspace.id),
        isTrue,
      );
    }
  });

  test('test_find_project_property_finds_every_seeded_project', () {
    final Random random = seededRandom(502);
    final FakeProjectRepository repository = FakeProjectRepository(
      projects: galleryProjects,
      taskWork: buildEmptyTaskWork(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = pickOne(random, galleryProjects);
      expect(repository.findProject(project.id).name, project.name);
    }
    expect(
      () => repository.findProject(const ProjectId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_create_project_property_blank_names_rejected', () async {
    final Random random = seededRandom(503);
    final FakeProjectRepository repository = FakeProjectRepository(
      projects: galleryProjects,
      taskWork: buildEmptyTaskWork(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomWordPhrase(random);
      final ProjectDraft draft = ProjectDraft(
        workspaceId: GalleryWorkspaceIds.acme,
        name: name,
        repositories: <Repository>[randomRepository(random)],
        approvalPolicy: null,
      );

      if (describeNameProblem(name.trim()) != null) {
        await expectLater(
          repository.createProject(draft),
          throwsA(isA<ArgumentError>()),
        );
      } else {
        final Project project = await repository.createProject(draft);
        expect(repository.findProject(project.id).name, name.trim());
      }
    }
  });

  test('test_add_repository_property_addresses_stay_unique', () async {
    final Random random = seededRandom(504);
    final FakeProjectRepository repository = FakeProjectRepository(
      projects: galleryProjects,
      taskWork: buildEmptyTaskWork(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = pickOne(random, galleryProjects);
      final Repository added = randomRepository(random);
      final Project before = repository.findProject(project.id);
      final bool isDuplicate = before.repositories.any(
        (Repository existing) => existing.address == added.address,
      );

      if (isDuplicate) {
        await expectLater(
          repository.addRepository(project.id, added),
          throwsA(isA<StateError>()),
        );
      } else {
        final Project after = await repository.addRepository(
          project.id,
          added,
        );
        expect(after.repositories.length, before.repositories.length + 1);
      }
    }
  });

  test('test_remove_repository_property_drops_exactly_one', () async {
    final Random random = seededRandom(505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeProjectRepository repository = FakeProjectRepository(
        projects: galleryProjects,
        taskWork: buildEmptyTaskWork(),
      );
      final Project project = pickOne(random, galleryProjects);
      final Repository removed = pickOne(random, project.repositories);
      final Project after = await repository.removeRepository(
        project.id,
        removed.address,
      );

      expect(after.repositories.length, project.repositories.length - 1);
      await expectLater(
        repository.removeRepository(project.id, removed.address),
        throwsA(
          isA<AppServerRefusal>().having(
            (AppServerRefusal refusal) => refusal.status,
            'status',
            404,
          ),
        ),
      );
    }
  });

  test('test_list_workspaces_property_grows_with_each_creation', () async {
    final Random random = seededRandom(506);
    final FakeWorkspaceRepository repository =
        buildGalleryWorkspaceRepository();
    int expectedCount = galleryWorkspaces.length;

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomWordPhrase(random);
      if (describeNameProblem(name.trim()) == null) {
        final Workspace created = await repository.createWorkspace(name: name);
        expectedCount += 1;
        expect(
          created.appServerAddress,
          repository.findAppServerStatus().address,
        );
      } else {
        await expectLater(
          repository.createWorkspace(name: name),
          throwsArgumentError,
        );
      }
      expect(repository.listWorkspaces().length, expectedCount);
    }
  });

  test('test_current_workspace_property_follows_switches', () async {
    final Random random = seededRandom(507);
    final FakeWorkspaceRepository repository =
        buildGalleryWorkspaceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace target = pickOne(random, galleryWorkspaces);
      await repository.switchWorkspace(target.id);
      expect(repository.currentWorkspace().id, target.id);
    }
  });

  test('test_switch_workspace_property_unknown_ids_rejected', () async {
    final Random random = seededRandom(508);
    final FakeWorkspaceRepository repository =
        buildGalleryWorkspaceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId unknown = WorkspaceId('unknown-${randomText(random)}');
      await expectLater(
        repository.switchWorkspace(unknown),
        throwsA(isA<RecordNotFound>()),
      );
      expect(repository.currentWorkspace().id, GalleryWorkspaceIds.acme);
    }
  });

  test('test_create_workspace_property_blank_names_rejected', () async {
    final FakeWorkspaceRepository repository =
        buildGalleryWorkspaceRepository();
    final Random random = seededRandom(509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String blank = ' ' * random.nextInt(4);
      await expectLater(
        repository.createWorkspace(name: blank),
        throwsA(isA<ArgumentError>()),
      );
    }
  });

  test('test_find_app_server_status_property_online_after_retry', () async {
    final Random random = seededRandom(510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkspaceRepository repository =
          buildGalleryWorkspaceRepository();
      expect(
        repository.findAppServerStatus().state,
        AppServerState.unreachable,
      );
      final int retries = 1 + random.nextInt(3);
      for (int attempt = 0; attempt < retries; attempt += 1) {
        await repository.retryAppServer();
      }
      expect(repository.findAppServerStatus().state, AppServerState.online);
    }
  });

  test('test_retry_app_server_property_keeps_address', () async {
    final FakeWorkspaceRepository repository =
        buildGalleryWorkspaceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerStatus status = await repository.retryAppServer();
      expect(status.address, 'relay.acme.dev');
      expect(status.lastConnectedAt, galleryNow);
    }
  });
}
