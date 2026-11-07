import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/catalog_repository_rigs.dart';
import 'support/project_reply_race.dart';

const int _rigIterations = 40;
const int _largestSwitchCount = 6;
const String _listProjectsCommand = 'list_projects';

List<String> _describeShown(ProjectRig rig) {
  return describeSortedProjects(
    listEveryProject(rig.projects, rig.workspaces),
  );
}

Future<void> _switchRandomly(Random random, ProjectRig rig) async {
  await rig.workspaces.switchWorkspace(
    pickOne(random, rig.workspaces.listWorkspaces()).id,
  );
  await pumpEventQueue();
}

void main() {
  test('test_node_backed_project_repository_dispose_property_stops_following_'
      'workspace_changes', () async {
    final Random random = seededRandom(80791);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      rig.projects.dispose();
      final int listingsBefore = rig.node.countCommands(_listProjectsCommand);

      await _switchRandomly(random, rig);

      expect(rig.node.countCommands(_listProjectsCommand), listingsBefore);
      rig.workspaces.dispose();
    }
  });

  test('test_node_backed_project_repository_dispose_property_others_keep_'
      'following', () async {
    final Random random = seededRandom(80792);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final NodeBackedProjectRepository disposed = NodeBackedProjectRepository(
        channel: rig.node.channel,
        workspaceRepository: rig.workspaces,
      );
      disposed.dispose();
      addProjectElsewhere(random, rig.node.simulated);

      await _switchRandomly(random, rig);

      expect(
        _describeShown(rig),
        await reloadProjectsFrom(rig.node.channel, rig.workspaces),
      );
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_dispose_property_asks_nothing_and_'
      'keeps_the_last_listing', () async {
    final Random random = seededRandom(80793);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final List<String> before = _describeShown(rig);
      final int commandsBefore = rig.node.receivedCommands.length;

      rig.projects.dispose();

      expect(rig.node.receivedCommands.length, commandsBefore);
      expect(_describeShown(rig), before);
      rig.workspaces.dispose();
    }
  });

  test('test_node_backed_project_repository_load_after_workspace_change_'
      'property_new_workspaces_bring_their_projects', () async {
    final Random random = seededRandom(80794);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);

      final Workspace created = await rig.workspaces.createWorkspace(
        name: 'joined-$i',
      );
      await pumpEventQueue();

      expect(rig.projects.listProjects(created.id), isEmpty);
      expect(
        _describeShown(rig),
        await reloadProjectsFrom(rig.node.channel, rig.workspaces),
      );
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_load_after_workspace_change_'
      'property_quick_switches_end_like_a_reload', () async {
    final Random random = seededRandom(80795);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final int switchCount = 1 + random.nextInt(_largestSwitchCount);
      final List<Future<Workspace>> switches = <Future<Workspace>>[];

      for (int step = 0; step < switchCount; step += 1) {
        addProjectElsewhere(random, rig.node.simulated);
        switches.add(
          rig.workspaces.switchWorkspace(
            pickOne(random, rig.workspaces.listWorkspaces()).id,
          ),
        );
      }
      await Future.wait(switches);
      await pumpEventQueue();

      expect(
        _describeShown(rig),
        await reloadProjectsFrom(rig.node.channel, rig.workspaces),
      );
      closeProjectRig(rig);
    }
  });
}
