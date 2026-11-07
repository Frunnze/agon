import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';
import 'support/rule_inputs.dart';

const String _typePrefix = 'test_fake_rule_repository';

List<ProjectId>? _listedProjects(Rule rule) {
  final ProjectScope projects = rule.scope.projects;
  if (projects is OnlyProjects) {
    return projects.projects;
  }
  return null;
}

Set<ProjectId> _randomForgotten(Random random) {
  return <ProjectId>{
    ...pickSome(random, sampleProjectIds),
    if (random.nextBool()) const ProjectId('project-never-made'),
  };
}

void main() {
  test('${_typePrefix}_forget_projects_property_drops_the_projects_from_'
      'every_rule_scope', () {
    final Random random = seededRandom(91801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      final CountedRules counted = buildCountedRules(random, seeded);
      final Set<ProjectId> forgotten = _randomForgotten(random);

      counted.repository.forgetProjects(forgotten);

      final List<Rule> listed = counted.repository.listRules();
      expect(listed, hasLength(seeded.length));
      for (int index = 0; index < seeded.length; index += 1) {
        final List<ProjectId>? before = _listedProjects(seeded[index]);
        final List<ProjectId>? after = _listedProjects(listed[index]);
        if (before == null) {
          expect(after, isNull);
          continue;
        }
        expect(after, <ProjectId>[
          for (final ProjectId projectId in before)
            if (!forgotten.contains(projectId)) projectId,
        ]);
      }
    }
  });

  test('${_typePrefix}_forget_projects_property_keeps_every_other_rule_'
      'field', () {
    final Random random = seededRandom(91802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rule> seeded = randomSeededRules(random);
      final CountedRules counted = buildCountedRules(random, seeded);

      counted.repository.forgetProjects(_randomForgotten(random));

      final List<Rule> listed = counted.repository.listRules();
      for (int index = 0; index < seeded.length; index += 1) {
        expect(listed[index].id, seeded[index].id);
        expect(listed[index].title, seeded[index].title);
        expect(listed[index].details, seeded[index].details);
        expect(listed[index].enabled, seeded[index].enabled);
        expect(listed[index].addedAt, seeded[index].addedAt);
        expect(
          listed[index].scope.workspaces,
          same(seeded[index].scope.workspaces),
        );
      }
    }
  });

  test('${_typePrefix}_forget_projects_property_notifies_once_per_call_and_'
      'is_idempotent', () {
    final Random random = seededRandom(91803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedRules counted = buildCountedRules(
        random,
        randomSeededRules(random),
      );
      final Set<ProjectId> forgotten = _randomForgotten(random);

      counted.repository.forgetProjects(forgotten);
      final List<String> once = <String>[
        for (final Rule rule in counted.repository.listRules())
          describeRuleContent(rule),
      ];
      counted.repository.forgetProjects(forgotten);

      expect(counted.notifications.count, 2);
      expect(<String>[
        for (final Rule rule in counted.repository.listRules())
          describeRuleContent(rule),
      ], once);
    }
  });
}
