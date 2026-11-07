import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/catalog_repository_rigs.dart';
import 'support/project_reply_race.dart';

const int _rigIterations = 40;
const String _listProjectsCommand = 'list_projects';
const node.AreaChanged _projectsChanged = node.AreaChanged(
  area: node.ChangeArea.projects,
);

List<String> _listNodeProjectIdsIn(ProjectRig rig, WorkspaceId workspaceId) {
  return <String>[
    for (final Map<String, Object?> project in rig.node.simulated.projects)
      if (project['workspace_id'] == workspaceId.value)
        project['id']! as String,
  ];
}

List<String> _listShownProjectIdsIn(ProjectRig rig, WorkspaceId workspaceId) {
  return <String>[
    for (final Project project in rig.projects.listProjects(workspaceId))
      project.id.value,
  ];
}

void main() {
  test(
    'test_node_backed_project_repository_constructor_property_lists_nothing_'
    'and_asks_nothing_before_load',
    () async {
      final Random random = seededRandom(80761);
      for (int i = 0; i < _rigIterations; i += 1) {
        final ProjectRig rig = await openProjectRig(random);
        final int commandsBefore = rig.node.receivedCommands.length;

        final NodeBackedProjectRepository fresh = NodeBackedProjectRepository(
          channel: rig.node.channel,
          workspaceRepository: rig.workspaces,
        );

        for (final Workspace workspace in rig.workspaces.listWorkspaces()) {
          expect(fresh.listProjects(workspace.id), isEmpty);
        }
        expect(rig.node.receivedCommands.length, commandsBefore);
        fresh.dispose();
        closeProjectRig(rig);
      }
    },
  );

  test('test_node_backed_project_repository_constructor_property_follows_the_'
      'given_workspace_repository', () async {
    final Random random = seededRandom(80762);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final NodeBackedProjectRepository fresh = NodeBackedProjectRepository(
        channel: rig.node.channel,
        workspaceRepository: rig.workspaces,
      );

      await rig.workspaces.switchWorkspace(
        pickOne(random, rig.workspaces.listWorkspaces()).id,
      );
      await pumpEventQueue();

      expect(
        describeSortedProjects(listEveryProject(fresh, rig.workspaces)),
        await reloadProjectsFrom(rig.node.channel, rig.workspaces),
      );
      fresh.dispose();
      closeProjectRig(rig);
    }
  });

  test(
    'test_node_backed_project_repository_constructor_property_two_instances_'
    'agree_after_loading',
    () async {
      final Random random = seededRandom(80763);
      for (int i = 0; i < _rigIterations; i += 1) {
        final ProjectRig rig = await openProjectRig(random);
        final NodeBackedProjectRepository second = NodeBackedProjectRepository(
          channel: rig.node.channel,
          workspaceRepository: rig.workspaces,
        );
        await second.load();

        expect(
          describeSortedProjects(listEveryProject(second, rig.workspaces)),
          describeSortedProjects(
            listEveryProject(rig.projects, rig.workspaces),
          ),
        );
        second.dispose();
        closeProjectRig(rig);
      }
    },
  );

  test('test_node_backed_project_repository_list_projects_property_unknown_'
      'workspace_lists_nothing', () async {
    final Random random = seededRandom(80764);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final WorkspaceId unknown = WorkspaceId(
        'workspace-unknown-${randomText(random)}',
      );

      expect(rig.projects.listProjects(unknown), isEmpty);
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_list_projects_property_answer_'
      'cannot_be_changed', () async {
    final Random random = seededRandom(80765);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final WorkspaceId workspaceId = _pickWorkspaceId(random, rig);
      final List<Project> listed = rig.projects.listProjects(workspaceId);

      expect(listed.clear, throwsUnsupportedError);
      expect(
        _listShownProjectIdsIn(rig, workspaceId),
        _listNodeProjectIdsIn(rig, workspaceId),
      );
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_list_projects_property_workspaces_'
      'split_every_project_once', () async {
    final Random random = seededRandom(80766);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final List<String> shownIds = <String>[];

      for (final Workspace workspace in rig.workspaces.listWorkspaces()) {
        for (final Project project in rig.projects.listProjects(
          workspace.id,
        )) {
          expect(project.workspaceId, workspace.id);
          shownIds.add(project.id.value);
        }
      }

      final List<String> nodeIds = <String>[
        for (final Map<String, Object?> project in rig.node.simulated.projects)
          project['id']! as String,
      ];
      expect(shownIds.toSet(), nodeIds.toSet());
      expect(shownIds.length, nodeIds.length);
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_find_project_property_finds_'
      'every_listed_project', () async {
    final Random random = seededRandom(80767);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);

      for (final Project listed in listEveryProject(
        rig.projects,
        rig.workspaces,
      )) {
        final Project found = rig.projects.findProject(listed.id);
        expect(describeProject(found), describeProject(listed));
      }
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_find_project_property_unknown_'
      'project_is_not_found', () async {
    final Random random = seededRandom(80768);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final String identifier = 'project-missing-${randomText(random)}';

      expect(
        () => rig.projects.findProject(ProjectId(identifier)),
        throwsA(
          isA<RecordNotFound>()
              .having(
                (RecordNotFound missing) => missing.kind,
                'kind',
                'project',
              )
              .having(
                (RecordNotFound missing) => missing.identifier,
                'identifier',
                identifier,
              ),
        ),
      );
      closeProjectRig(rig);
    }
  });

  test(
    'test_node_backed_project_repository_find_project_property_projects_gone_'
    'from_the_node_are_not_found',
    () async {
      final Random random = seededRandom(80769);
      for (int i = 0; i < _rigIterations; i += 1) {
        final ProjectRig rig = await openProjectRig(random);
        rig.node.simulated.projects.clear();
        await rig.projects.applyChange(_projectsChanged);

        for (final Workspace workspace in rig.workspaces.listWorkspaces()) {
          expect(rig.projects.listProjects(workspace.id), isEmpty);
        }
        expect(
          () => rig.projects.findProject(const ProjectId('project-1')),
          throwsA(isA<RecordNotFound>()),
        );
        expect(rig.node.countCommands(_listProjectsCommand), greaterThan(0));
        closeProjectRig(rig);
      }
    },
  );
}

WorkspaceId _pickWorkspaceId(Random random, ProjectRig rig) {
  return pickOne(random, rig.workspaces.listWorkspaces()).id;
}
