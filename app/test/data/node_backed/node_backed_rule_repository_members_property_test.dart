import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/rule_inputs.dart';
import 'support/catalog_repository_rigs.dart';
import 'support/rule_reply_race.dart';
import 'support/simulated_scopes.dart';

const int _rigIterations = 40;

List<String> _listNodeRuleIdsHere(RuleRig rig) {
  final String currentWorkspaceId = rig.workspaces.currentWorkspace().id.value;
  return <String>[
    for (final Map<String, Object?> rule in rig.node.simulated.rules)
      if (isSimulatedScopeInWorkspace(rule, currentWorkspaceId))
        rule['id']! as String,
  ];
}

List<String> _listShownRuleIds(RuleRig rig) {
  return <String>[
    for (final Rule rule in rig.rules.listRules()) rule.id.value,
  ];
}

Future<List<String>> _reload(RuleRig rig) {
  return reloadRulesFrom(rig.node.channel, rig.workspaces);
}

Future<RuleRig> _openRigInRandomWorkspace(Random random) async {
  final RuleRig rig = await openRuleRig(random);
  await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
  await pumpEventQueue();
  return rig;
}

void main() {
  test('test_node_backed_rule_repository_constructor_property_lists_nothing_'
      'and_asks_nothing_before_load', () async {
    final Random random = seededRandom(80801);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      final int commandsBefore = rig.node.receivedCommands.length;

      final NodeBackedRuleRepository fresh = NodeBackedRuleRepository(
        channel: rig.node.channel,
        workspaceRepository: rig.workspaces,
      );

      expect(fresh.listRules(), isEmpty);
      expect(rig.node.receivedCommands.length, commandsBefore);
      fresh.dispose();
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_constructor_property_follows_the_'
      'given_workspace_repository', () async {
    final Random random = seededRandom(80802);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      final NodeBackedRuleRepository fresh = NodeBackedRuleRepository(
        channel: rig.node.channel,
        workspaceRepository: rig.workspaces,
      );

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();

      expect(describeSortedRules(fresh.listRules()), await _reload(rig));
      fresh.dispose();
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_constructor_property_two_instances_'
      'agree_after_loading', () async {
    final Random random = seededRandom(80803);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigInRandomWorkspace(random);
      final NodeBackedRuleRepository second = NodeBackedRuleRepository(
        channel: rig.node.channel,
        workspaceRepository: rig.workspaces,
      );
      await second.load();

      expect(
        describeSortedRules(second.listRules()),
        describeSortedRules(rig.rules.listRules()),
      );
      second.dispose();
      closeRuleRig(rig);
    }
  });

  test(
    'test_node_backed_rule_repository_list_rules_property_only_rules_usable_'
    'here_in_node_order',
    () async {
      final Random random = seededRandom(80804);
      for (int i = 0; i < _rigIterations; i += 1) {
        final RuleRig rig = await _openRigInRandomWorkspace(random);

        expect(_listShownRuleIds(rig), _listNodeRuleIdsHere(rig));
        closeRuleRig(rig);
      }
    },
  );

  test('test_node_backed_rule_repository_list_rules_property_is_stable_'
      'without_changes', () async {
    final Random random = seededRandom(80805);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigInRandomWorkspace(random);
      final List<String> first = describeSortedRules(rig.rules.listRules());
      final int commandsBefore = rig.node.receivedCommands.length;

      for (int read = 0; read < 1 + random.nextInt(5); read += 1) {
        expect(describeSortedRules(rig.rules.listRules()), first);
      }
      expect(rig.node.receivedCommands.length, commandsBefore);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_list_rules_property_answer_cannot_be_'
      'changed', () async {
    final Random random = seededRandom(80806);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigInRandomWorkspace(random);

      expect(rig.rules.listRules().clear, throwsUnsupportedError);
      expect(_listShownRuleIds(rig), _listNodeRuleIdsHere(rig));
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_find_rule_property_finds_every_'
      'listed_rule', () async {
    final Random random = seededRandom(80807);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigInRandomWorkspace(random);

      for (final Rule listed in rig.rules.listRules()) {
        expect(
          describeRuleContent(rig.rules.findRule(listed.id)),
          describeRuleContent(listed),
        );
      }
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_find_rule_property_rules_of_other_'
      'workspaces_are_not_found', () async {
    final Random random = seededRandom(80808);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigInRandomWorkspace(random);
      final Set<String> shown = _listShownRuleIds(rig).toSet();

      for (final Map<String, Object?> rule in rig.node.simulated.rules) {
        final String identifier = rule['id']! as String;
        if (shown.contains(identifier)) {
          continue;
        }
        expect(
          () => rig.rules.findRule(RuleId(identifier)),
          throwsA(
            isA<RecordNotFound>()
                .having(
                  (RecordNotFound missing) => missing.kind,
                  'kind',
                  'rule',
                )
                .having(
                  (RecordNotFound missing) => missing.identifier,
                  'identifier',
                  identifier,
                ),
          ),
        );
      }
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_find_rule_property_unknown_rule_is_'
      'not_found', () async {
    final Random random = seededRandom(80809);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigInRandomWorkspace(random);

      expect(
        () => rig.rules.findRule(randomMissingRuleId(random)),
        throwsA(isA<RecordNotFound>()),
      );
      closeRuleRig(rig);
    }
  });
}
