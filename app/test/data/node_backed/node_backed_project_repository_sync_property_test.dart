import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';

import '../../support/random_inputs.dart';
import 'support/catalog_repository_rigs.dart';
import 'support/project_reply_race.dart';
import 'support/simulated_node_replies.dart';

const int _rigIterations = 40;
const String _listProjectsCommand = 'list_projects';
const Set<node.ChangeArea> _projectAreas = <node.ChangeArea>{
  node.ChangeArea.projects,
  node.ChangeArea.workspaces,
};

Future<List<String>> _reload(ProjectRig rig) {
  return reloadProjectsFrom(rig.node.channel, rig.workspaces);
}

List<String> _describeShown(ProjectRig rig) {
  return describeSortedProjects(
    listEveryProject(rig.projects, rig.workspaces),
  );
}

void _changeNodeElsewhere(Random random, ProjectRig rig) {
  if (random.nextBool() || rig.node.simulated.projects.isEmpty) {
    addProjectElsewhere(random, rig.node.simulated);
    return;
  }
  rig.node.simulated.projects.remove(
    pickOne(random, rig.node.simulated.projects),
  );
}

node.ChangeTopic _randomOtherTopic(Random random) {
  final List<node.ChangeArea> otherAreas = <node.ChangeArea>[
    for (final node.ChangeArea area in node.ChangeArea.values)
      if (!_projectAreas.contains(area)) area,
  ];
  if (random.nextBool()) {
    return node.RunChanged(runId: RunId('run-${random.nextInt(99)}'));
  }
  return node.AreaChanged(area: pickOne(random, otherAreas));
}

void main() {
  test('test_node_backed_project_repository_load_property_matches_the_node_'
      'after_changes_elsewhere', () async {
    final Random random = seededRandom(80771);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      _changeNodeElsewhere(random, rig);

      await rig.projects.load();

      expect(_describeShown(rig), await _reload(rig));
      closeProjectRig(rig);
    }
  });

  test(
    'test_node_backed_project_repository_load_property_is_idempotent',
    () async {
      final Random random = seededRandom(80772);
      for (int i = 0; i < _rigIterations; i += 1) {
        final ProjectRig rig = await openProjectRig(random);
        final List<String> first = _describeShown(rig);
        final int loadCount = 1 + random.nextInt(4);

        for (int load = 0; load < loadCount; load += 1) {
          await rig.projects.load();
        }

        expect(_describeShown(rig), first);
        expect(rig.notifications.count, loadCount);
        closeProjectRig(rig);
      }
    },
  );

  test('test_node_backed_project_repository_apply_change_property_project_and_'
      'workspace_areas_reload', () async {
    final Random random = seededRandom(80773);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      _changeNodeElsewhere(random, rig);
      final node.ChangeArea area = pickOne(random, _projectAreas.toList());

      await rig.projects.applyChange(node.AreaChanged(area: area));

      expect(_describeShown(rig), await _reload(rig));
      closeProjectRig(rig);
    }
  });

  test(
    'test_node_backed_project_repository_apply_change_property_other_topics_'
    'ask_nothing',
    () async {
      final Random random = seededRandom(80774);
      for (int i = 0; i < _rigIterations; i += 1) {
        final ProjectRig rig = await openProjectRig(random);
        final List<String> before = _describeShown(rig);
        final int listingsBefore = rig.node.countCommands(
          _listProjectsCommand,
        );
        _changeNodeElsewhere(random, rig);

        await rig.projects.applyChange(_randomOtherTopic(random));

        expect(_describeShown(rig), before);
        expect(rig.node.countCommands(_listProjectsCommand), listingsBefore);
        expect(rig.notifications.count, 0);
        closeProjectRig(rig);
      }
    },
  );

  test('test_node_backed_project_repository_apply_change_property_refused_'
      'listing_keeps_the_projects', () async {
    final Random random = seededRandom(80775);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final List<String> before = _describeShown(rig);
      _changeNodeElsewhere(random, rig);
      rig.node.refusals[_listProjectsCommand] = simulatedOutageMessage;

      await expectLater(
        rig.projects.applyChange(
          const node.AreaChanged(area: node.ChangeArea.projects),
        ),
        throwsStateError,
      );

      expect(_describeShown(rig), before);
      expect(rig.notifications.count, 0);
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_load_workspace_projects_property_'
      'keeps_the_node_order', () async {
    final Random random = seededRandom(80776);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      rig.node.simulated.projects.shuffle(random);

      await rig.projects.load();

      for (final WorkspaceId workspaceId in <WorkspaceId>[
        for (final Map<String, Object?> workspace
            in rig.node.simulated.workspaces)
          WorkspaceId(workspace['id']! as String),
      ]) {
        final List<String> nodeOrder = <String>[
          for (final Map<String, Object?> project
              in rig.node.simulated.projects)
            if (project['workspace_id'] == workspaceId.value)
              project['id']! as String,
        ];
        final List<String> shownOrder = <String>[
          for (final Project project in rig.projects.listProjects(workspaceId))
            project.id.value,
        ];
        expect(shownOrder, nodeOrder);
      }
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_load_workspace_projects_property_'
      'keeps_hostile_names', () async {
    final Random random = seededRandom(80777);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      addProjectElsewhere(random, rig.node.simulated);
      final Map<String, Object?> hostile = rig.node.simulated.projects.last;
      final String name = ' ${randomText(random)}\n${randomText(random)} ';
      hostile['name'] = name;

      await rig.projects.load();

      final Project shown = rig.projects.findProject(
        ProjectId(hostile['id']! as String),
      );
      expect(shown.name, name);
      expect(shown.workspaceId.value, hostile['workspace_id']);
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_load_workspace_projects_property_'
      'asks_once_per_workspace', () async {
    final Random random = seededRandom(80778);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final int before = rig.node.countCommands(_listProjectsCommand);

      await rig.projects.load();

      expect(
        rig.node.countCommands(_listProjectsCommand) - before,
        rig.workspaces.listWorkspaces().length,
      );
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_load_after_workspace_change_'
      'property_failed_reload_stays_inside', () async {
    final Random random = seededRandom(80779);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final List<String> before = _describeShown(rig);
      final List<Object> escaped = <Object>[];
      rig.node.refusals[_listProjectsCommand] = simulatedOutageMessage;

      await runZonedGuarded(() async {
        await rig.workspaces.switchWorkspace(
          pickOne(random, rig.workspaces.listWorkspaces()).id,
        );
        await pumpEventQueue();
      }, (Object problem, StackTrace _) => escaped.add(problem));

      expect(escaped, isEmpty);
      expect(_describeShown(rig), before);
      closeProjectRig(rig);
    }
  });
}
