import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_app_server_refusals.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/rule_inputs.dart';
import 'support/catalog_repository_rigs.dart';
import 'support/rule_reply_race.dart';
import 'support/simulated_node_replies.dart';

const int _rigIterations = 40;
const String _listRulesCommand = 'list_rules';
const String _switchCommand = 'set_rule_enabled';

Future<List<String>> _reload(RuleRig rig) {
  return reloadRulesFrom(rig.node.channel, rig.workspaces);
}

List<String> _describeShown(RuleRig rig) {
  return describeSortedRules(rig.rules.listRules());
}

void _addRuleHere(Random random, RuleRig rig) {
  rig.node.simulated.addRule(
    workspaceId: rig.workspaces.currentWorkspace().id.value,
    title: 'Rule ${randomText(random)}x',
  );
}

Future<RuleRig> _openRigWithARuleHere(Random random) async {
  final RuleRig rig = await openRuleRig(random);
  _addRuleHere(random, rig);
  await rig.rules.load();
  rig.notifications.count = 0;
  return rig;
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

Future<Rule> _switchRule(Random random, RuleRig rig, RuleId ruleId) {
  if (random.nextBool()) {
    return rig.rules.turnRuleOn(ruleId);
  }
  return rig.rules.turnRuleOff(ruleId);
}

void main() {
  test('test_node_backed_rule_repository_apply_change_property_rule_changes_'
      'reload', () async {
    final Random random = seededRandom(80821);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      _addRuleHere(random, rig);

      await rig.rules.applyChange(
        const node.AreaChanged(area: node.ChangeArea.rules),
      );

      expect(_describeShown(rig), await _reload(rig));
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_apply_change_property_other_topics_'
      'ask_nothing', () async {
    final Random random = seededRandom(80822);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      final List<String> before = _describeShown(rig);
      final int listingsBefore = rig.node.countCommands(_listRulesCommand);
      _addRuleHere(random, rig);
      final List<node.ChangeTopic> otherTopics = <node.ChangeTopic>[
        node.RunChanged(runId: RunId('run-${random.nextInt(99)}')),
        for (final node.ChangeArea area in node.ChangeArea.values)
          if (area != node.ChangeArea.rules) node.AreaChanged(area: area),
      ];

      await rig.rules.applyChange(pickOne(random, otherTopics));

      expect(_describeShown(rig), before);
      expect(rig.node.countCommands(_listRulesCommand), listingsBefore);
      expect(rig.notifications.count, 0);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_apply_change_property_refused_'
      'listing_keeps_the_rules', () async {
    final Random random = seededRandom(80823);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      final List<String> before = _describeShown(rig);
      _addRuleHere(random, rig);
      rig.node.refusals[_listRulesCommand] = simulatedOutageMessage;

      await expectLater(
        rig.rules.applyChange(
          const node.AreaChanged(area: node.ChangeArea.rules),
        ),
        throwsStateError,
      );

      expect(_describeShown(rig), before);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_turn_rule_on_property_lists_like_a_'
      'reload_and_notifies_once', () async {
    final Random random = seededRandom(80824);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigWithARuleHere(random);
      final Rule listed = pickOne(random, rig.rules.listRules());

      final Rule switched = await rig.rules.turnRuleOn(listed.id);

      expect(switched.enabled, isTrue);
      expect(switched.title, listed.title);
      expect(_describeShown(rig), await _reload(rig));
      expect(rig.notifications.count, 1);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_turn_rule_off_property_lists_like_a_'
      'reload_and_notifies_once', () async {
    final Random random = seededRandom(80825);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigWithARuleHere(random);
      final Rule listed = pickOne(random, rig.rules.listRules());

      final Rule switched = await rig.rules.turnRuleOff(listed.id);

      expect(switched.enabled, isFalse);
      expect(switched.scope.workspaces, listed.scope.workspaces);
      expect(_describeShown(rig), await _reload(rig));
      expect(rig.notifications.count, 1);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_turn_rule_on_property_unlisted_rule_'
      'never_reaches_the_node', () async {
    final Random random = seededRandom(80826);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await openRuleRig(random);
      final int switchesBefore = rig.node.countCommands(_switchCommand);

      await expectLater(
        rig.rules.turnRuleOn(randomMissingRuleId(random)),
        throwsA(isA<RecordNotFound>()),
      );

      expect(rig.node.countCommands(_switchCommand), switchesBefore);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_turn_rule_off_property_refusals_keep_'
      'status_and_listing', () async {
    final Random random = seededRandom(80827);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigWithARuleHere(random);
      final List<String> before = _describeShown(rig);
      final RandomRefusal refusal = randomRefusal(random);
      rig.node.refusals[_switchCommand] = refusal.nodeMessage;

      await expectLater(
        _switchRule(random, rig, pickOne(random, rig.rules.listRules()).id),
        throwsA(_isRefusal(refusal)),
      );

      expect(_describeShown(rig), before);
      expect(rig.notifications.count, 0);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_delete_rule_property_lists_like_a_'
      'reload', () async {
    final Random random = seededRandom(80828);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigWithARuleHere(random);
      final Rule listed = pickOne(random, rig.rules.listRules());

      await rig.rules.deleteRule(listed.id);

      expect(_describeShown(rig), await _reload(rig));
      expect(
        () => rig.rules.findRule(listed.id),
        throwsA(isA<RecordNotFound>()),
      );
      expect(rig.notifications.count, 1);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_delete_rule_property_missing_rule_'
      'changes_nothing', () async {
    final Random random = seededRandom(80829);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigWithARuleHere(random);
      final List<String> before = _describeShown(rig);

      await expectLater(
        rig.rules.deleteRule(randomMissingRuleId(random)),
        throwsA(isA<RecordNotFound>()),
      );

      expect(_describeShown(rig), before);
      expect(rig.notifications.count, 0);
      closeRuleRig(rig);
    }
  });

  test('test_node_backed_rule_repository_delete_rule_property_refusals_keep_'
      'status_and_listing', () async {
    final Random random = seededRandom(80830);
    for (int i = 0; i < _rigIterations; i += 1) {
      final RuleRig rig = await _openRigWithARuleHere(random);
      final List<String> before = _describeShown(rig);
      final RandomRefusal refusal = randomRefusal(random);
      rig.node.refusals['delete_rule'] = refusal.nodeMessage;

      await expectLater(
        rig.rules.deleteRule(pickOne(random, rig.rules.listRules()).id),
        throwsA(_isRefusal(refusal)),
      );

      expect(_describeShown(rig), before);
      closeRuleRig(rig);
    }
  });
}
