import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/skill_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';
import 'support/workspace_skill_inputs.dart';

const String _typePrefix = 'test_fake_skill_repository';

typedef _ScopedSkills = ({
  SeededWorkspaces workspaces,
  List<WorkspaceId> workspaceIds,
  List<Skill> seeded,
  FakeSkillRepository repository,
});

_ScopedSkills _buildScopedSkills(Random random) {
  final SeededWorkspaces workspaces = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = listWorkspaceIds(
    workspaces.workspaces,
  );
  final List<Skill> seeded = randomSkillsScopedOver(random, workspaceIds);
  return (
    workspaces: workspaces,
    workspaceIds: workspaceIds,
    seeded: seeded,
    repository: buildSkillRepositoryIn(seeded, workspaces.repository),
  );
}

Future<WorkspaceId> _switchRandomly(Random random, _ScopedSkills scoped) {
  final Workspace target = pickOne(random, scoped.workspaces.workspaces);
  return scoped.workspaces.repository
      .switchWorkspace(target.id)
      .then((Workspace switched) => switched.id);
}

List<Skill> _unlistedSkills(_ScopedSkills scoped, WorkspaceId current) {
  return <Skill>[
    for (final Skill skill in scoped.seeded)
      if (!isModelUsableInWorkspace(skill.scope.workspaces, current)) skill,
  ];
}

SkillDraft _draftNamed(Random random, String name, WorkspaceId workspaceId) {
  final SkillDraft draft = randomSkillDraftNamed(random, name);
  return SkillDraft(
    name: draft.name,
    summary: draft.summary,
    instructions: draft.instructions,
    scope: Scope(
      workspaces: OnlyWorkspaces(<WorkspaceId>[workspaceId]),
      projects: const AllProjects(),
    ),
    usage: draft.usage,
    improvement: draft.improvement,
  );
}

void main() {
  test('${_typePrefix}_list_skills_property_lists_only_skills_usable_in_'
      'the_current_workspace', () async {
    final Random random = seededRandom(91601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScopedSkills scoped = _buildScopedSkills(random);
      final WorkspaceId current = await _switchRandomly(random, scoped);

      expect(
        describeSkillsInScope(scoped.repository.listSkills()),
        orderedEquals(predictSkillsListedIn(scoped.seeded, current)),
      );
      if (scoped.seeded.isNotEmpty) {
        expect(
          () => scoped.repository.listSkills().add(scoped.seeded.first),
          throwsUnsupportedError,
        );
      }
    }
  });

  test('${_typePrefix}_constructor_property_notifies_on_every_workspace_'
      'switch', () async {
    final Random random = seededRandom(91602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScopedSkills scoped = _buildScopedSkills(random);
      final NotificationCounter notifications = NotificationCounter();
      scoped.repository.addListener(notifications.record);
      final int switchCount = random.nextInt(4);

      for (int step = 0; step < switchCount; step += 1) {
        await _switchRandomly(random, scoped);
      }

      expect(notifications.count, switchCount);
    }
  });

  test('${_typePrefix}_dispose_property_stops_following_the_workspace_'
      'repository', () async {
    final Random random = seededRandom(91603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScopedSkills scoped = _buildScopedSkills(random);
      final NotificationCounter notifications = NotificationCounter();
      scoped.repository.addListener(notifications.record);
      scoped.repository.removeListener(notifications.record);

      scoped.repository.dispose();
      await _switchRandomly(random, scoped);

      expect(notifications.count, 0);
      expect(scoped.workspaces.repository.listWorkspaces(), isNotEmpty);
    }
  });

  test('${_typePrefix}_find_skill_property_finds_listed_skills_and_refuses_'
      'skills_of_other_workspaces', () async {
    final Random random = seededRandom(91604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScopedSkills scoped = _buildScopedSkills(random);
      final WorkspaceId current = await _switchRandomly(random, scoped);

      for (final Skill listed in scoped.repository.listSkills()) {
        expect(scoped.repository.findSkill(listed.id), same(listed));
      }
      for (final Skill hidden in _unlistedSkills(scoped, current)) {
        expect(
          () => scoped.repository.findSkill(hidden.id),
          throwsA(isA<RecordNotFound>()),
        );
      }
    }
  });

  test('${_typePrefix}_create_skill_property_a_name_used_only_in_another_'
      'workspace_is_free', () async {
    final Random random = seededRandom(91605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScopedSkills scoped = _buildScopedSkills(random);
      final WorkspaceId current = await _switchRandomly(random, scoped);
      final List<Skill> hidden = _unlistedSkills(scoped, current);
      final List<Skill> listed = scoped.repository.listSkills();
      if (hidden.isEmpty && listed.isEmpty) {
        continue;
      }
      final bool isHiddenName = listed.isEmpty || random.nextBool();
      final String name = isHiddenName && hidden.isNotEmpty
          ? pickOne(random, hidden).name
          : pickOne(random, listed).name;
      final bool isTakenHere = listed.any((Skill skill) => skill.name == name);

      final Future<Skill> creating = scoped.repository.createSkill(
        _draftNamed(random, name, current),
      );

      if (isTakenHere) {
        await expectLater(creating, throwsStateError);
        continue;
      }
      final Skill created = await creating;
      expect(scoped.repository.findSkill(created.id).name, name);
    }
  });

  test('${_typePrefix}_update_skill_property_checks_names_only_against_'
      'skills_of_the_current_workspace', () async {
    final Random random = seededRandom(91606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScopedSkills scoped = _buildScopedSkills(random);
      final WorkspaceId current = await _switchRandomly(random, scoped);
      final List<Skill> listed = scoped.repository.listSkills();
      if (listed.isEmpty) {
        continue;
      }
      final Skill updated = pickOne(random, listed);
      final String name = pickOne(random, scoped.seeded).name;
      final bool isTakenHere = listed.any(
        (Skill skill) => skill.name == name && skill.id != updated.id,
      );

      final Future<Skill> updating = scoped.repository.updateSkill(
        updated.id,
        _draftNamed(random, name, current),
      );

      if (isTakenHere) {
        await expectLater(updating, throwsStateError);
        continue;
      }
      expect((await updating).name, name);
    }
  });

  test('${_typePrefix}_delete_skill_property_refuses_skills_of_other_'
      'workspaces_and_keeps_them', () async {
    final Random random = seededRandom(91607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _ScopedSkills scoped = _buildScopedSkills(random);
      final WorkspaceId current = await _switchRandomly(random, scoped);
      final List<Skill> hidden = _unlistedSkills(scoped, current);
      if (hidden.isEmpty) {
        continue;
      }
      final Skill target = pickOne(random, hidden);

      await expectLater(
        scoped.repository.deleteSkill(target.id),
        throwsA(isA<RecordNotFound>()),
      );

      for (final WorkspaceId workspaceId in scoped.workspaceIds) {
        await scoped.workspaces.repository.switchWorkspace(workspaceId);
        final bool isListed = scoped.repository.listSkills().any(
          (Skill skill) => skill.id == target.id,
        );
        expect(
          isListed,
          isModelUsableInWorkspace(target.scope.workspaces, workspaceId),
        );
      }
    }
  });
}
