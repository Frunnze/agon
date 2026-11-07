import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/project_inputs.dart';
import 'support/catalog_repository_rigs.dart';
import 'support/project_reply_race.dart';

const int _rigIterations = 40;
const List<String> _blankOrInvalidNames = <String>[
  '',
  '   ',
  'Has Capitals',
  'spaces inside',
  'name-longer-than-forty-characters-is-refused',
];

Future<List<String>> _reload(ProjectRig rig) {
  return reloadProjectsFrom(rig.node.channel, rig.workspaces);
}

List<String> _describeShown(ProjectRig rig) {
  return describeSortedProjects(
    listEveryProject(rig.projects, rig.workspaces),
  );
}

ProjectDraft _randomDraft(Random random, ProjectRig rig) {
  return ProjectDraft(
    workspaceId: pickOne(random, rig.workspaces.listWorkspaces()).id,
    name: 'made-${random.nextInt(1000)}',
    repositories: randomDistinctRepositories(random),
    approvalPolicy: null,
  );
}

Project? _pickProjectWithRepository(Random random, ProjectRig rig) {
  final List<Project> candidates = <Project>[
    for (final Project project in listEveryProject(
      rig.projects,
      rig.workspaces,
    ))
      if (project.repositories.isNotEmpty) project,
  ];
  if (candidates.isEmpty) {
    return null;
  }
  return pickOne(random, candidates);
}

Matcher _isRefusal(RandomRefusal refusal) {
  return isA<AppServerRefusal>()
      .having(
        (AppServerRefusal shown) => shown.status,
        'status',
        refusal.status,
      )
      .having(
        (AppServerRefusal shown) => shown.message,
        'reason',
        refusal.reason,
      );
}

void main() {
  test('test_node_backed_project_repository_create_project_property_bad_names_'
      'never_reach_the_node', () async {
    final Random random = seededRandom(80781);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final int commandsBefore = rig.node.receivedCommands.length;
      final ProjectDraft valid = _randomDraft(random, rig);
      final ProjectDraft invalid = ProjectDraft(
        workspaceId: valid.workspaceId,
        name: pickOne(random, _blankOrInvalidNames),
        repositories: valid.repositories,
        approvalPolicy: null,
      );

      await expectLater(
        rig.projects.createProject(invalid),
        throwsArgumentError,
      );

      expect(rig.node.receivedCommands.length, commandsBefore);
      expect(rig.notifications.count, 0);
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_create_project_property_refusals_'
      'keep_status_and_listing', () async {
    final Random random = seededRandom(80782);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final List<String> before = _describeShown(rig);
      final RandomRefusal refusal = randomRefusal(random);
      rig.node.refusals['create_project'] = refusal.nodeMessage;

      await expectLater(
        rig.projects.createProject(_randomDraft(random, rig)),
        throwsA(_isRefusal(refusal)),
      );

      expect(_describeShown(rig), before);
      expect(rig.notifications.count, 0);
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_create_project_property_lists_'
      'like_a_reload', () async {
    final Random random = seededRandom(80783);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);

      final Project created = await rig.projects.createProject(
        _randomDraft(random, rig),
      );

      expect(_describeShown(rig), await _reload(rig));
      expect(rig.projects.findProject(created.id).name, created.name);
      expect(rig.notifications.count, 1);
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_add_repository_property_refusals_'
      'keep_status_and_listing', () async {
    final Random random = seededRandom(80784);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final Project created = await rig.projects.createProject(
        _randomDraft(random, rig),
      );
      final List<String> before = _describeShown(rig);
      final RandomRefusal refusal = randomRefusal(random);
      rig.node.refusals['create_repository'] = refusal.nodeMessage;

      await expectLater(
        rig.projects.addRepository(
          created.id,
          randomRepositoryAt(random, randomCanonicalAddress(random)),
        ),
        throwsA(_isRefusal(refusal)),
      );

      expect(_describeShown(rig), before);
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_remove_repository_property_lists_'
      'like_a_reload', () async {
    final Random random = seededRandom(80785);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final Project? project = _pickProjectWithRepository(random, rig);
      if (project == null) {
        closeProjectRig(rig);
        continue;
      }
      final Repository removed = pickOne(random, project.repositories);

      final Project updated = await rig.projects.removeRepository(
        project.id,
        removed.address,
      );

      expect(
        updated.repositories.map((Repository kept) => kept.address),
        isNot(contains(removed.address)),
      );
      expect(_describeShown(rig), await _reload(rig));
      closeProjectRig(rig);
    }
  });

  test(
    'test_node_backed_project_repository_remove_repository_property_unknown_'
    'project_never_reaches_the_node',
    () async {
      final Random random = seededRandom(80786);
      for (int i = 0; i < _rigIterations; i += 1) {
        final ProjectRig rig = await openProjectRig(random);
        final int commandsBefore = rig.node.receivedCommands.length;

        await expectLater(
          rig.projects.removeRepository(
            ProjectId('project-missing-${randomText(random)}'),
            randomCanonicalAddress(random),
          ),
          throwsA(isA<RecordNotFound>()),
        );

        expect(rig.node.receivedCommands.length, commandsBefore);
        closeProjectRig(rig);
      }
    },
  );

  test('test_node_backed_project_repository_delete_project_property_lists_'
      'like_a_reload', () async {
    final Random random = seededRandom(80787);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final Project created = await rig.projects.createProject(
        _randomDraft(random, rig),
      );

      await rig.projects.deleteProject(created.id);

      expect(_describeShown(rig), await _reload(rig));
      expect(
        () => rig.projects.findProject(created.id),
        throwsA(isA<RecordNotFound>()),
      );
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_delete_project_property_missing_'
      'project_changes_nothing', () async {
    final Random random = seededRandom(80788);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final List<String> before = _describeShown(rig);

      await expectLater(
        rig.projects.deleteProject(
          ProjectId('project-missing-${random.nextInt(1000)}'),
        ),
        throwsA(isA<RecordNotFound>()),
      );

      expect(_describeShown(rig), before);
      expect(rig.notifications.count, 0);
      closeProjectRig(rig);
    }
  });

  test('test_node_backed_project_repository_delete_project_property_notifies_'
      'once_per_deletion', () async {
    final Random random = seededRandom(80789);
    for (int i = 0; i < _rigIterations; i += 1) {
      final ProjectRig rig = await openProjectRig(random);
      final List<Project> listed = listEveryProject(
        rig.projects,
        rig.workspaces,
      );

      for (final Project project in listed) {
        await rig.projects.deleteProject(project.id);
      }

      expect(rig.notifications.count, listed.length);
      expect(_describeShown(rig), isEmpty);
      closeProjectRig(rig);
    }
  });
}
