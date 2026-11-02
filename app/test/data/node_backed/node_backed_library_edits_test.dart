import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/simulated_catalog_node.dart';

typedef _OpenedLibrary = ({
  NodeBackedWorkspaceRepository workspaces,
  NodeBackedSkillRepository skills,
  NodeBackedRuleRepository rules,
});

const int _seededItemCount = 4;

Future<_OpenedLibrary> _openSeededLibrary(
  SimulatedCatalogNode simulated,
) async {
  final String workspaceId = simulated.addWorkspace('home')['id'] as String;
  for (int i = 0; i < _seededItemCount; i += 1) {
    simulated.addSkill(workspaceId: workspaceId, name: 'skill-$i');
    simulated.addRule(workspaceId: workspaceId, title: 'Rule $i');
  }
  final NodeBackedWorkspaceRepository workspaces =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(DateTime.utc(2026, 10, 31)),
        retryInterval: const Duration(seconds: 30),
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  final NodeBackedSkillRepository skills = NodeBackedSkillRepository(
    channel: simulated.channel,
    workspaceRepository: workspaces,
  );
  final NodeBackedRuleRepository rules = NodeBackedRuleRepository(
    channel: simulated.channel,
    workspaceRepository: workspaces,
  );
  await workspaces.load();
  await skills.load();
  await rules.load();
  return (workspaces: workspaces, skills: skills, rules: rules);
}

void _closeLibrary(_OpenedLibrary opened) {
  opened.skills.dispose();
  opened.rules.dispose();
  opened.workspaces.dispose();
}

List<String> _listIds(List<Map<String, Object?>> records) {
  return <String>[
    for (final Map<String, Object?> record in records) record['id'] as String,
  ];
}

void main() {
  test('test_update_skill_property_node_and_list_agree', () async {
    final Random random = seededRandom(9901);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final _OpenedLibrary opened = await _openSeededLibrary(simulated);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill original = pickOne(random, opened.skills.listSkills());
      final String name = pickOne(random, <String>[
        original.name,
        'edited-$i',
        'Bad Name',
        pickOne(random, opened.skills.listSkills()).name,
      ]);
      final bool isTakenByAnother = opened.skills.listSkills().any(
        (Skill skill) => skill.name == name && skill.id != original.id,
      );
      final SkillDraft draft = SkillDraft(
        name: name,
        summary: randomText(random),
        instructions: randomText(random),
        scope: const Scope.everywhere(),
        usage: pickOne(random, SkillUsage.values),
      );
      final Future<Skill> updating = opened.skills.updateSkill(
        original.id,
        draft,
      );

      if (name == 'Bad Name') {
        await expectLater(updating, throwsArgumentError);
      } else if (isTakenByAnother) {
        await expectLater(updating, throwsStateError);
      } else {
        final Skill updated = await updating;
        expect(updated.id, original.id);
        expect(opened.skills.findSkill(original.id).name, name);
        final Map<String, Object?> stored = simulated.skills.firstWhere(
          (Map<String, Object?> skill) => skill['id'] == original.id.value,
        );
        expect(stored['instructions'], draft.instructions);
      }
      expect(opened.skills.listSkills().length, _seededItemCount);
    }
    _closeLibrary(opened);
  });

  test('test_delete_skill_property_node_and_list_agree', () async {
    final Random random = seededRandom(9902);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final _OpenedLibrary opened = await _openSeededLibrary(simulated);

    while (opened.skills.listSkills().isNotEmpty) {
      final Skill deleted = pickOne(random, opened.skills.listSkills());

      await opened.skills.deleteSkill(deleted.id);

      expect(
        () => opened.skills.findSkill(deleted.id),
        throwsA(isA<RecordNotFound>()),
      );
      expect(<String>[
        for (final Skill skill in opened.skills.listSkills()) skill.id.value,
      ], _listIds(simulated.skills));
    }
    await expectLater(
      opened.skills.deleteSkill(const SkillId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
    _closeLibrary(opened);
  });

  test('test_update_rule_property_node_and_list_agree', () async {
    final Random random = seededRandom(9903);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final _OpenedLibrary opened = await _openSeededLibrary(simulated);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule original = pickOne(random, opened.rules.listRules());
      final String title = pickOne(random, <String>['', '  ', 'Keep $i ']);
      final RuleDraft draft = RuleDraft(
        title: title,
        details: randomText(random),
        scope: const Scope.everywhere(),
      );
      final Future<Rule> updating = opened.rules.updateRule(
        original.id,
        draft,
      );

      if (title.trim().isEmpty) {
        await expectLater(updating, throwsArgumentError);
        expect(opened.rules.findRule(original.id).title, original.title);
        continue;
      }
      final Rule updated = await updating;
      expect(updated.id, original.id);
      expect(updated.enabled, original.enabled);
      expect(opened.rules.findRule(original.id).title, title.trim());
      final Map<String, Object?> stored = simulated.rules.firstWhere(
        (Map<String, Object?> rule) => rule['id'] == original.id.value,
      );
      expect(stored['title'], title.trim());
      expect(stored['details'], draft.details);
    }
    _closeLibrary(opened);
  });

  test('test_delete_rule_property_node_and_list_agree', () async {
    final Random random = seededRandom(9904);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final _OpenedLibrary opened = await _openSeededLibrary(simulated);

    while (opened.rules.listRules().isNotEmpty) {
      final Rule deleted = pickOne(random, opened.rules.listRules());

      await opened.rules.deleteRule(deleted.id);

      expect(
        () => opened.rules.findRule(deleted.id),
        throwsA(isA<RecordNotFound>()),
      );
      expect(<String>[
        for (final Rule rule in opened.rules.listRules()) rule.id.value,
      ], _listIds(simulated.rules));
    }
    _closeLibrary(opened);
  });

  test('test_delete_skill_property_node_failure_keeps_the_list', () async {
    final Random random = seededRandom(9905);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final _OpenedLibrary opened = await _openSeededLibrary(simulated);
    simulated.failingCommands.addAll(<String>[
      'delete_skill',
      'delete_rule',
      'update_skill',
      'update_rule',
    ]);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill skill = pickOne(random, opened.skills.listSkills());
      final Rule rule = pickOne(random, opened.rules.listRules());

      await expectLater(opened.skills.deleteSkill(skill.id), throwsStateError);
      await expectLater(opened.rules.deleteRule(rule.id), throwsStateError);
      await expectLater(
        opened.rules.updateRule(
          rule.id,
          const RuleDraft(
            title: 'Changed',
            details: '',
            scope: Scope.everywhere(),
          ),
        ),
        throwsStateError,
      );

      expect(opened.skills.listSkills().length, _seededItemCount);
      expect(opened.rules.findRule(rule.id).title, rule.title);
    }
    _closeLibrary(opened);
  });
}
