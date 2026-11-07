import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import 'support/catalog_repository_rigs.dart';
import 'support/rule_reply_race.dart';
import 'support/simulated_node_replies.dart';

const int _rigIterations = 40;
const int _largestSwitchCount = 6;
const String _listRulesCommand = 'list_rules';

List<String> _describeShown(RuleRig rig) {
  return describeSortedRules(rig.rules.listRules());
}

Future<void> _switchRandomly(Random random, RuleRig rig) async {
  await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
  await pumpEventQueue();
}

void _addRuleSomewhere(Random random, RuleRig rig) {
  final WorkspaceId workspaceId = pickOne(random, rig.workspaceIds);
  rig.node.simulated.addRule(
    workspaceId: workspaceId.value,
    title: 'Rule ${randomText(random)}x',
  );
}

void main() {
  test('test_node_backed_rule_repository_dispose_property_stops_following_'
      'workspace_changes', () async {
    final Random random = seededRandom(80831);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      rig.rules.dispose();
      final int listingsBefore = rig.node.countCommands(_listRulesCommand);

      await _switchRandomly(random, rig);

      expect(rig.node.countCommands(_listRulesCommand), listingsBefore);
      rig.workspaces.dispose();
    }
  });

  test('test_node_backed_rule_repository_dispose_property_others_keep_'
      'following', () async {
    final Random random = seededRandom(80832);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      final NodeBackedRuleRepository disposed = NodeBackedRuleRepository(
        channel: rig.node.channel,
        workspaceRepository: rig.workspaces,
      );
      disposed.dispose();
      _addRuleSomewhere(random, rig);

      await _switchRandomly(random, rig);

      expect(
        _describeShown(rig),
        await reloadRulesFrom(rig.node.channel, rig.workspaces),
      );
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_dispose_property_asks_nothing_and_'
      'keeps_the_last_listing', () async {
    final Random random = seededRandom(80833);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      final List<String> before = _describeShown(rig);
      final int commandsBefore = rig.node.receivedCommands.length;

      rig.rules.dispose();

      expect(rig.node.receivedCommands.length, commandsBefore);
      expect(_describeShown(rig), before);
      rig.workspaces.dispose();
    }
  });

  test('test_node_backed_rule_repository_load_after_workspace_change_property_'
      'quick_switches_end_in_the_last_workspace', () async {
    final Random random = seededRandom(80834);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      final int switchCount = 1 + random.nextInt(_largestSwitchCount);
      final List<Future<Workspace>> switches = <Future<Workspace>>[];

      for (int step = 0; step < switchCount; step += 1) {
        _addRuleSomewhere(random, rig);
        switches.add(
          rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds)),
        );
      }
      await Future.wait(switches);
      await pumpEventQueue();

      expect(
        _describeShown(rig),
        await reloadRulesFrom(rig.node.channel, rig.workspaces),
      );
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_load_after_workspace_change_property_'
      'failed_reload_stays_inside', () async {
    final Random random = seededRandom(80835);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      final List<String> before = _describeShown(rig);
      final List<Object> escaped = <Object>[];
      rig.node.refusals[_listRulesCommand] = simulatedOutageMessage;

      await runZonedGuarded(
        () => _switchRandomly(random, rig),
        (Object problem, StackTrace _) => escaped.add(problem),
      );

      expect(escaped, isEmpty);
      expect(_describeShown(rig), before);
      closeRuleRig(rig);
    }
  });
}
