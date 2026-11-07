import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/rule_inputs.dart';
import 'support/skill_inputs.dart';
import 'support/workspace_scope_inputs.dart';

const String _typePrefix = 'test_fake_skill_repository';

typedef _SkillForgetting = ({
  List<Skill> seeded,
  FakeSkillRepository repository,
  WorkspaceId deletedWorkspaceId,
  Set<WorkspaceId> remainingWorkspaceIds,
});

Skill _withRandomScope(
  Random random,
  Skill skill,
  List<WorkspaceId> workspaceIds,
) {
  return Skill(
    id: skill.id,
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: randomScopeOver(random, workspaceIds),
    usage: skill.usage,
    source: skill.source,
    improvement: skill.improvement,
    history: skill.history,
  );
}

_SkillForgetting _planSkillForgetting(Random random) {
  final List<WorkspaceId> workspaceIds = randomWorkspaceIds(random);
  final List<Skill> seeded = <Skill>[
    for (final Skill skill in randomSeededSkills(random))
      _withRandomScope(random, skill, workspaceIds),
  ];
  final WorkspaceId deletedWorkspaceId = pickOne(random, workspaceIds);
  return (
    seeded: seeded,
    repository: buildSkillRepository(seeded),
    deletedWorkspaceId: deletedWorkspaceId,
    remainingWorkspaceIds: randomRemainingWorkspaceIds(
      random,
      workspaceIds: workspaceIds,
      deletedWorkspaceId: deletedWorkspaceId,
    ),
  );
}

void _forget(_SkillForgetting forgetting) {
  forgetting.repository.forgetWorkspace(
    deletedWorkspaceId: forgetting.deletedWorkspaceId,
    remainingWorkspaceIds: forgetting.remainingWorkspaceIds,
  );
}

List<String> _predictListingAfterForget(_SkillForgetting forgetting) {
  final List<String> expected = <String>[];
  for (final Skill skill in forgetting.seeded) {
    final Scope scope = predictScopeAfterForget(
      skill.scope,
      forgetting.deletedWorkspaceId,
    );
    if (!isModelSeenInNoWorkspace(
      scope.workspaces,
      forgetting.remainingWorkspaceIds,
    )) {
      expected.add('${describeSkill(skill)} ${describeScope(scope)}');
    }
  }
  return expected;
}

List<String> _describeListing(FakeSkillRepository repository) {
  return <String>[
    for (final Skill skill in repository.listSkills())
      '${describeSkill(skill)} ${describeScope(skill.scope)}',
  ];
}

Map<SkillId, Skill> _indexSkills(List<Skill> skills) {
  return <SkillId, Skill>{for (final Skill skill in skills) skill.id: skill};
}

bool _namesWorkspace(Skill skill, WorkspaceId workspaceId) {
  final WorkspaceScope workspaces = skill.scope.workspaces;
  return workspaces is OnlyWorkspaces &&
      workspaces.workspaces.contains(workspaceId);
}

void main() {
  test('${_typePrefix}_forget_workspace_property_matches_the_model', () {
    final Random random = seededRandom(75101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SkillForgetting forgetting = _planSkillForgetting(random);

      _forget(forgetting);

      expect(
        _describeListing(forgetting.repository),
        orderedEquals(_predictListingAfterForget(forgetting)),
      );
    }
  });

  test('${_typePrefix}_forget_workspace_property_keeps_all_workspaces_'
      'skills', () {
    final Random random = seededRandom(75102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SkillForgetting forgetting = _planSkillForgetting(random);

      _forget(forgetting);

      final Map<SkillId, Skill> listed = _indexSkills(
        forgetting.repository.listSkills(),
      );
      for (final Skill skill in forgetting.seeded) {
        if (skill.scope.workspaces is AllWorkspaces) {
          expect(listed[skill.id]?.scope.workspaces, isA<AllWorkspaces>());
        }
      }
    }
  });

  test('${_typePrefix}_forget_workspace_property_is_idempotent', () {
    final Random random = seededRandom(75103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SkillForgetting forgetting = _planSkillForgetting(random);

      _forget(forgetting);
      final List<String> afterOnce = _describeListing(forgetting.repository);
      _forget(forgetting);

      expect(
        _describeListing(forgetting.repository),
        orderedEquals(afterOnce),
      );
    }
  });

  test('${_typePrefix}_forget_workspace_property_notifies_once', () {
    final Random random = seededRandom(75104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SkillForgetting forgetting = _planSkillForgetting(random);
      final NotificationCounter notifications = NotificationCounter();
      forgetting.repository.addListener(notifications.record);

      _forget(forgetting);

      expect(notifications.count, 1);
    }
  });

  test('${_typePrefix}_forget_workspace_property_removed_skills_are_not_'
      'found', () async {
    final Random random = seededRandom(75105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SkillForgetting forgetting = _planSkillForgetting(random);
      final FakeSkillRepository repository = forgetting.repository;

      _forget(forgetting);

      final Map<SkillId, Skill> listed = _indexSkills(repository.listSkills());
      for (final Skill skill in forgetting.seeded) {
        if (listed.containsKey(skill.id)) {
          expect(repository.findSkill(skill.id).id, skill.id);
          continue;
        }
        final Matcher isNotFound = throwsA(isA<RecordNotFound>());
        expect(() => repository.findSkill(skill.id), isNotFound);
        await expectLater(repository.deleteSkill(skill.id), isNotFound);
      }
    }
  });

  test('${_typePrefix}_with_scope_property_keeps_every_other_field_and_'
      'history', () {
    final Random random = seededRandom(75106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SkillForgetting forgetting = _planSkillForgetting(random);
      final Map<SkillId, Skill> seeded = _indexSkills(forgetting.seeded);

      _forget(forgetting);

      for (final Skill skill in forgetting.repository.listSkills()) {
        final Skill original = seeded[skill.id]!;
        expect(describeSkill(skill), describeSkill(original));
        expect(skill.history, orderedEquals(original.history));
      }
    }
  });

  test('${_typePrefix}_with_scope_property_keeps_the_project_scope', () {
    final Random random = seededRandom(75107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SkillForgetting forgetting = _planSkillForgetting(random);
      final Map<SkillId, Skill> seeded = _indexSkills(forgetting.seeded);

      _forget(forgetting);

      for (final Skill skill in forgetting.repository.listSkills()) {
        expect(skill.scope.projects, same(seeded[skill.id]!.scope.projects));
      }
    }
  });

  test('${_typePrefix}_with_scope_property_skills_not_naming_the_'
      'workspace_keep_their_scope', () {
    final Random random = seededRandom(75108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _SkillForgetting forgetting = _planSkillForgetting(random);
      final Map<SkillId, Skill> seeded = _indexSkills(forgetting.seeded);

      _forget(forgetting);

      for (final Skill skill in forgetting.repository.listSkills()) {
        final Skill original = seeded[skill.id]!;
        if (!_namesWorkspace(original, forgetting.deletedWorkspaceId)) {
          expect(describeScope(skill.scope), describeScope(original.scope));
        }
        expect(_namesWorkspace(skill, forgetting.deletedWorkspaceId), isFalse);
      }
    }
  });
}
