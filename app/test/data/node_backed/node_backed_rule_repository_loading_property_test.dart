import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/catalog_repository_rigs.dart';
import 'support/out_of_order_replies.dart';
import 'support/rule_reply_race.dart';
import 'support/simulated_catalog_node.dart';
import 'support/simulated_node_replies.dart';
import 'support/simulated_scopes.dart';

const int _rigIterations = 40;
const String _listRulesCommand = 'list_rules';

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

Future<RuleRig> _openRigInRandomWorkspace(Random random) async {
  final RuleRig rig = await openRuleRig(random);
  await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
  await pumpEventQueue();
  return rig;
}

void main() {
  test('test_node_backed_rule_repository_load_rules_property_no_workspace_'
      'lists_nothing_and_asks_nothing', () async {
    final Random random = seededRandom(80810);
    for (int i = 0; i < _rigIterations; i += 1) {
      final SimulatedCatalogNode simulated = SimulatedCatalogNode(
        hasAccount: false,
      );
      simulated.addRule(
        workspaceId: 'workspace-${random.nextInt(9)}',
        title: 'Rule ${randomText(random)}x',
      );
      final RefusingCatalogNode refusing = RefusingCatalogNode(simulated);
      final NodeBackedWorkspaceRepository workspaces =
          await openRaceWorkspaces(refusing.channel);
      final NodeBackedRuleRepository rules = NodeBackedRuleRepository(
        channel: refusing.channel,
        workspaceRepository: workspaces,
      );

      await rules.load();

      expect(rules.listRules(), isEmpty);
      expect(refusing.countCommands(_listRulesCommand), 0);
      rules.dispose();
      workspaces.dispose();
    }
  });

  test('test_node_backed_rule_repository_load_rules_property_asks_for_the_'
      'current_workspace_only', () async {
    final Random random = seededRandom(80811);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigInRandomWorkspace(random);
      final int before = rig.node.countCommands(_listRulesCommand);

      await rig.rules.load();

      expect(rig.node.countCommands(_listRulesCommand) - before, 1);
      expect(_listShownRuleIds(rig), _listNodeRuleIdsHere(rig));
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_load_rules_property_refused_listing_'
      'keeps_the_rules', () async {
    final Random random = seededRandom(80812);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigInRandomWorkspace(random);
      final List<String> before = describeSortedRules(rig.rules.listRules());
      final int notificationsBefore = rig.notifications.count;
      rig.node.simulated.rules.clear();
      rig.node.refusals[_listRulesCommand] = simulatedOutageMessage;

      await expectLater(rig.rules.load(), throwsStateError);

      expect(describeSortedRules(rig.rules.listRules()), before);
      expect(rig.notifications.count, notificationsBefore);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_load_property_matches_the_node_after_'
      'changes_elsewhere', () async {
    final Random random = seededRandom(80813);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigInRandomWorkspace(random);
      rig.node.simulated.addRule(
        workspaceId: rig.workspaces.currentWorkspace().id.value,
        title: 'Rule ${randomText(random)}x',
      );
      if (rig.node.simulated.rules.length > 1 && random.nextBool()) {
        rig.node.simulated.rules.removeAt(0);
      }

      await rig.rules.load();

      expect(
        describeSortedRules(rig.rules.listRules()),
        await reloadRulesFrom(rig.node.channel, rig.workspaces),
      );
      closeRuleRig(rig);
    }
  });

  test(
    'test_node_backed_rule_repository_load_property_is_idempotent',
    () async {
      final Random random = seededRandom(80814);
      for (int i = 0; i < _rigIterations; i += 1) {
        final RuleRig rig = await _openRigInRandomWorkspace(random);
        final List<String> first = describeSortedRules(rig.rules.listRules());
        final int notificationsBefore = rig.notifications.count;
        final int loadCount = 1 + random.nextInt(4);

        for (int load = 0; load < loadCount; load += 1) {
          await rig.rules.load();
        }

        expect(describeSortedRules(rig.rules.listRules()), first);
        expect(rig.notifications.count - notificationsBefore, loadCount);
        closeRuleRig(rig);
      }
    },
  );
}
