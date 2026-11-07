import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/scope_cleanup.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_scopes.dart';

const int _largestListedCount = 8;
const List<ProjectId> _projectPool = <ProjectId>[
  ProjectId('project-app'),
  ProjectId('project-docs'),
  ProjectId('Project-App'),
  ProjectId(''),
  ProjectId(' '),
  ProjectId('café'),
];

ProjectId _randomProjectId(Random random) {
  if (random.nextInt(4) == 0) {
    return ProjectId(randomText(random));
  }
  return pickOne(random, _projectPool);
}

List<ProjectId> _randomProjectIds(Random random) {
  final int count = random.nextInt(_largestListedCount);
  return <ProjectId>[
    for (int i = 0; i < count; i += 1) _randomProjectId(random),
  ];
}

Scope _randomScope(Random random) {
  final ProjectScope projects = random.nextInt(3) == 0
      ? const AllProjects()
      : OnlyProjects(_randomProjectIds(random));
  return Scope(workspaces: randomWorkspaceScope(random), projects: projects);
}

List<ProjectId>? _listedProjectsOf(Scope scope) {
  final ProjectScope projects = scope.projects;
  if (projects is OnlyProjects) {
    return projects.projects;
  }
  return null;
}

void main() {
  test('test_forget_projects_in_scope_property_keeps_every_other_project_'
      'in_order', () {
    final Random random = seededRandom(91101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomScope(random);
      final Set<ProjectId> forgotten = _randomProjectIds(random).toSet();

      final Scope cleaned = forgetProjectsInScope(scope, forgotten);

      final List<ProjectId>? before = _listedProjectsOf(scope);
      final List<ProjectId>? after = _listedProjectsOf(cleaned);
      if (before == null) {
        expect(cleaned.projects, isA<AllProjects>());
        continue;
      }
      final List<ProjectId> expected = <ProjectId>[
        for (final ProjectId projectId in before)
          if (!forgotten.contains(projectId)) projectId,
      ];
      expect(after, orderedEquals(expected));
    }
  });

  test('test_forget_projects_in_scope_property_never_touches_the_'
      'workspaces', () {
    final Random random = seededRandom(91102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomScope(random);

      final Scope cleaned = forgetProjectsInScope(
        scope,
        _randomProjectIds(random).toSet(),
      );

      expect(cleaned.workspaces, same(scope.workspaces));
    }
  });

  test('test_forget_projects_in_scope_property_is_idempotent_and_'
      'forgetting_nothing_changes_nothing', () {
    final Random random = seededRandom(91103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Scope scope = _randomScope(random);
      final Set<ProjectId> forgotten = _randomProjectIds(random).toSet();

      final Scope once = forgetProjectsInScope(scope, forgotten);
      final Scope twice = forgetProjectsInScope(once, forgotten);
      final Scope untouched = forgetProjectsInScope(scope, <ProjectId>{});

      expect(_listedProjectsOf(twice), _listedProjectsOf(once));
      expect(_listedProjectsOf(untouched), _listedProjectsOf(scope));
      final List<ProjectId>? listedOnce = _listedProjectsOf(once);
      if (listedOnce != null) {
        expect(listedOnce.any(forgotten.contains), isFalse);
      }
    }
  });
}
