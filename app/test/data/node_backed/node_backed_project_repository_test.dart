import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/simulated_catalog_node.dart';

const int _followIterations = 15;
const int _followPumps = 200;

typedef _OpenedProjects = ({
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedProjectRepository projects,
});

Future<_OpenedProjects> _openProjects(SimulatedCatalogNode simulated) async {
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(DateTime.utc(2026, 10, 31)),
        retryInterval: const Duration(seconds: 30),
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  final NodeBackedProjectRepository projects = NodeBackedProjectRepository(
    channel: simulated.channel,
    workspaceRepository: workspaces,
  );
  await workspaces.load();
  await projects.load();
  return (workspaces: workspaces, projects: projects);
}

void _closeProjects(_OpenedProjects opened) {
  opened.projects.dispose();
  opened.workspaces.dispose();
}

Repository _randomRepository(Random random) {
  return Repository(
    address: 'github.com/example/repository-${random.nextInt(8)}',
    defaultBranch: pickOne(random, <String>['main', 'develop']),
    agentAccess: pickOne(random, AgentAccess.values),
  );
}

List<String> _listNodeProjectIds(
  SimulatedCatalogNode simulated,
  WorkspaceId workspaceId,
) {
  return <String>[
    for (final Map<String, Object?> project in simulated.projects)
      if (project['workspace_id'] == workspaceId.value)
        project['id'] as String,
  ];
}

List<String> _listProjectIds(
  NodeBackedProjectRepository projects,
  WorkspaceId workspaceId,
) {
  return <String>[
    for (final Project project in projects.listProjects(workspaceId))
      project.id.value,
  ];
}

void main() {
  test('test_list_projects_property_mirrors_node_per_workspace', () async {
    final Random random = seededRandom(9701);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    simulated.addWorkspace('home');
    simulated.addWorkspace('office');
    final _OpenedProjects opened = await _openProjects(simulated);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace workspace = pickOne(
        random,
        opened.workspaces.listWorkspaces(),
      );
      if (random.nextBool()) {
        await opened.projects.createProject(
          ProjectDraft(
            workspaceId: workspace.id,
            name: 'project-$i',
            repositories: <Repository>[_randomRepository(random)],
          ),
        );
      } else {
        simulated.projects.add(<String, Object?>{
          'id': simulated.nextIdentifier('project'),
          'workspace_id': workspace.id.value,
          'name': 'remote-$i',
          'repositories': <Object?>[],
        });
        await opened.projects.applyChange(
          const node.AreaChanged(area: node.ChangeArea.projects),
        );
      }
      for (final Workspace listed in opened.workspaces.listWorkspaces()) {
        expect(
          _listProjectIds(opened.projects, listed.id),
          _listNodeProjectIds(simulated, listed.id),
        );
      }
    }
    _closeProjects(opened);
  });

  test('test_create_project_property_is_found_or_rejected', () async {
    final Random random = seededRandom(9702);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final WorkspaceId workspaceId = WorkspaceId(
      simulated.addWorkspace('home')['id'] as String,
    );
    final _OpenedProjects opened = await _openProjects(simulated);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isValid = random.nextBool();
      final String name = isValid ? 'site-$i' : 'Site ${randomText(random)}';
      final ProjectDraft draft = ProjectDraft(
        workspaceId: workspaceId,
        name: name,
        repositories: const <Repository>[],
      );
      if (!isValid) {
        await expectLater(
          opened.projects.createProject(draft),
          throwsArgumentError,
        );
        continue;
      }
      final Project created = await opened.projects.createProject(draft);
      expect(opened.projects.findProject(created.id).name, name);
    }
    expect(
      opened.projects.listProjects(workspaceId).length,
      simulated.projects.length,
    );
    _closeProjects(opened);
  });

  test('test_add_repository_property_appends_each_address_once', () async {
    final Random random = seededRandom(9703);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final WorkspaceId workspaceId = WorkspaceId(
      simulated.addWorkspace('home')['id'] as String,
    );
    final _OpenedProjects opened = await _openProjects(simulated);
    final Project project = await opened.projects.createProject(
      ProjectDraft(
        workspaceId: workspaceId,
        name: 'site',
        repositories: const <Repository>[],
      ),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Repository repository = _randomRepository(random);
      final List<Repository> before = opened.projects
          .findProject(project.id)
          .repositories;
      final bool isKnown = before.any(
        (Repository existing) => existing.address == repository.address,
      );
      if (isKnown) {
        await expectLater(
          opened.projects.addRepository(project.id, repository),
          throwsStateError,
        );
        continue;
      }
      final Project updated = await opened.projects.addRepository(
        project.id,
        repository,
      );
      expect(updated.repositories.length, before.length + 1);
      expect(updated.repositories.last.address, repository.address);
    }
    await expectLater(
      opened.projects.addRepository(
        const ProjectId('missing'),
        _randomRepository(random),
      ),
      throwsA(isA<RecordNotFound>()),
    );
    _closeProjects(opened);
  });

  test('test_remove_repository_property_keeps_the_others', () async {
    final Random random = seededRandom(9704);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final WorkspaceId workspaceId = WorkspaceId(
      simulated.addWorkspace('home')['id'] as String,
    );
    final _OpenedProjects opened = await _openProjects(simulated);
    final Project project = await opened.projects.createProject(
      ProjectDraft(
        workspaceId: workspaceId,
        name: 'site',
        repositories: const <Repository>[],
      ),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Repository repository = _randomRepository(random);
      final Project current = opened.projects.findProject(project.id);
      final bool isListed = current.repositories.any(
        (Repository existing) => existing.address == repository.address,
      );
      if (!isListed) {
        await opened.projects.addRepository(project.id, repository);
        continue;
      }

      final Project trimmed = await opened.projects.removeRepository(
        project.id,
        repository.address,
      );
      final List<String> expected = <String>[
        for (final Repository existing in current.repositories)
          if (existing.address != repository.address) existing.address,
      ];
      expect(
        trimmed.repositories.map((Repository kept) => kept.address),
        expected,
      );
      expect(
        opened.projects.findProject(project.id).repositories.length,
        expected.length,
      );
    }
    _closeProjects(opened);
  });

  test('test_load_property_follows_workspace_changes', () async {
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: false,
    );
    final _OpenedProjects opened = await _openProjects(simulated);
    expect(opened.workspaces.listWorkspaces(), isEmpty);

    for (int i = 0; i < _followIterations; i += 1) {
      simulated.hasAccount = true;
      final String workspaceId =
          simulated.addWorkspace('joined-$i')['id'] as String;
      simulated.projects.add(<String, Object?>{
        'id': simulated.nextIdentifier('project'),
        'workspace_id': workspaceId,
        'name': 'shared-$i',
        'repositories': <Object?>[],
      });
      await opened.workspaces.applyChange(
        const node.AreaChanged(area: node.ChangeArea.account),
      );
      await pumpEventQueue(times: _followPumps);
      expect(
        _listProjectIds(opened.projects, WorkspaceId(workspaceId)),
        _listNodeProjectIds(simulated, WorkspaceId(workspaceId)),
      );
    }
    _closeProjects(opened);
  });
}
