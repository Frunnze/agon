import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
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

const int _pumpCount = 50;

Future<_OpenedLibrary> _openLibrary(SimulatedCatalogNode simulated) async {
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

List<String> _listNodeIds(
  List<Map<String, Object?>> records,
  WorkspaceId workspaceId,
) {
  return <String>[
    for (final Map<String, Object?> record in records)
      if (record['workspace'] == workspaceId.value) record['id'] as String,
  ];
}

SkillDraft _buildSkillDraft(String name) {
  return SkillDraft(
    name: name,
    summary: 'Summary',
    instructions: 'Instructions',
    scope: const Scope.everywhere(),
    usage: SkillUsage.automatic,
    improvement: SkillImprovement.never,
  );
}

void main() {
  test('test_create_skill_property_names_stay_unique', () async {
    final Random random = seededRandom(9801);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final WorkspaceId workspaceId = WorkspaceId(
      simulated.addWorkspace('home')['id'] as String,
    );
    final _OpenedLibrary opened = await _openLibrary(simulated);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = pickOne(random, <String>[
        'review-${random.nextInt(30)}',
        'Bad Name',
        '',
      ]);
      final bool isTaken = opened.skills.listSkills().any(
        (Skill skill) => skill.name == name,
      );
      final Future<Skill> creating = opened.skills.createSkill(
        _buildSkillDraft(name),
      );
      if (name == 'Bad Name' || name.isEmpty) {
        await expectLater(creating, throwsArgumentError);
      } else if (isTaken) {
        await expectLater(creating, throwsStateError);
      } else {
        final Skill skill = await creating;
        expect(opened.skills.findSkill(skill.id).source, SkillSource.created);
      }
      final List<Skill> skills = opened.skills.listSkills();
      expect(
        skills.map((Skill skill) => skill.name).toSet().length,
        skills.length,
      );
      expect(<String>[
        for (final Skill skill in skills) skill.id.value,
      ], _listNodeIds(simulated.skills, workspaceId));
    }
    expect(
      () => opened.skills.findSkill(const SkillId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
    _closeLibrary(opened);
  });

  test('test_apply_change_property_reloads_only_on_library_topics', () async {
    final Random random = seededRandom(9802);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final WorkspaceId workspaceId = WorkspaceId(
      simulated.addWorkspace('home')['id'] as String,
    );
    final _OpenedLibrary opened = await _openLibrary(simulated);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int skillCount = opened.skills.listSkills().length;
      final int ruleCount = opened.rules.listRules().length;
      simulated.addSkill(workspaceId: workspaceId.value, name: 'remote-$i');
      simulated.addRule(workspaceId: workspaceId.value, title: 'Rule $i');
      final node.ChangeArea area = pickOne(random, node.ChangeArea.values);
      await opened.skills.applyChange(node.AreaChanged(area: area));
      await opened.rules.applyChange(node.AreaChanged(area: area));
      expect(
        opened.skills.listSkills().length,
        area == node.ChangeArea.skills
            ? _listNodeIds(simulated.skills, workspaceId).length
            : skillCount,
      );
      expect(
        opened.rules.listRules().length,
        area == node.ChangeArea.rules
            ? _listNodeIds(simulated.rules, workspaceId).length
            : ruleCount,
      );
    }
    _closeLibrary(opened);
  });

  test('test_list_skills_property_follows_current_workspace', () async {
    final Random random = seededRandom(9803);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    for (final String name in <String>['home', 'office', 'lab']) {
      final String workspaceId = simulated.addWorkspace(name)['id'] as String;
      simulated.addSkill(workspaceId: workspaceId, name: '$name-skill');
      simulated.addRule(workspaceId: workspaceId, title: '$name rule');
    }
    final _OpenedLibrary opened = await _openLibrary(simulated);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace chosen = pickOne(
        random,
        opened.workspaces.listWorkspaces(),
      );
      await opened.workspaces.switchWorkspace(chosen.id);
      await pumpEventQueue(times: _pumpCount);
      expect(
        <String>[
          for (final Skill skill in opened.skills.listSkills()) skill.name,
        ],
        <String>['${chosen.name}-skill'],
      );
      expect(
        <String>[for (final Rule rule in opened.rules.listRules()) rule.title],
        <String>['${chosen.name} rule'],
      );
    }
    _closeLibrary(opened);
  });

  test('test_turn_rule_on_property_matches_node_state', () async {
    final Random random = seededRandom(9804);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    final WorkspaceId workspaceId = WorkspaceId(
      simulated.addWorkspace('home')['id'] as String,
    );
    final _OpenedLibrary opened = await _openLibrary(simulated);
    for (int i = 0; i < 4; i += 1) {
      await opened.rules.createRule(
        RuleDraft(
          title: 'Rule $i',
          details: 'Details',
          scope: const Scope.everywhere(),
        ),
      );
    }

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = pickOne(random, opened.rules.listRules());
      final Rule switched = random.nextBool()
          ? await opened.rules.turnRuleOn(rule.id)
          : await opened.rules.turnRuleOff(rule.id);
      expect(switched.id, rule.id);
      for (final Map<String, Object?> stored in simulated.rules) {
        final Rule local = opened.rules.listRules().firstWhere(
          (Rule candidate) => candidate.id.value == stored['id'],
        );
        expect(local.enabled, stored['enabled']);
      }
    }
    await expectLater(
      opened.rules.turnRuleOn(const RuleId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
    expect(
      opened.rules.listRules().length,
      _listNodeIds(simulated.rules, workspaceId).length,
    );
    _closeLibrary(opened);
  });

  test('test_create_rule_property_rejects_empty_titles', () async {
    final Random random = seededRandom(9805);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    simulated.addWorkspace('home');
    final _OpenedLibrary opened = await _openLibrary(simulated);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = pickOne(random, <String>['', '  ', 'Keep it $i']);
      final Future<Rule> creating = opened.rules.createRule(
        RuleDraft(
          title: title,
          details: randomText(random),
          scope: const Scope.everywhere(),
        ),
      );
      if (title.trim().isEmpty) {
        await expectLater(creating, throwsArgumentError);
        continue;
      }
      final Rule rule = await creating;
      expect(rule.title, title.trim());
      expect(rule.enabled, isTrue);
    }
    expect(opened.rules.listRules().length, simulated.rules.length);
    _closeLibrary(opened);
  });

  test('test_create_skill_property_node_failure_changes_nothing', () async {
    final Random random = seededRandom(9806);
    final SimulatedCatalogNode simulated = SimulatedCatalogNode(
      hasAccount: true,
    );
    simulated.addWorkspace('home');
    final _OpenedLibrary opened = await _openLibrary(simulated);
    simulated.failingCommands.addAll(<String>['create_skill', 'create_rule']);

    for (int i = 0; i < propertyIterations; i += 1) {
      await expectLater(
        opened.skills.createSkill(_buildSkillDraft('skill-$i')),
        throwsStateError,
      );
      await expectLater(
        opened.rules.createRule(
          RuleDraft(
            title: 'Rule $i',
            details: randomText(random),
            scope: const Scope.everywhere(),
          ),
        ),
        throwsStateError,
      );
      expect(opened.skills.listSkills(), isEmpty);
      expect(opened.rules.listRules(), isEmpty);
    }
    _closeLibrary(opened);
  });
}
