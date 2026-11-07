import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';

import '../../support/random_inputs.dart';
import 'support/rule_reply_race.dart';

const int _raceIterations = 40;
const int _longestRace = 12;

enum _RaceStep {
  turnRuleOn,
  turnRuleOff,
  createRule,
  updateRule,
  deleteRule,
  editElsewhere,
  deleteElsewhere,
  switchWorkspace,
  releaseOneReply,
  deliverAnnouncement,
}

const List<_RaceStep> _switchSteps = <_RaceStep>[
  _RaceStep.turnRuleOn,
  _RaceStep.turnRuleOff,
  _RaceStep.editElsewhere,
  _RaceStep.deleteElsewhere,
  _RaceStep.switchWorkspace,
  _RaceStep.releaseOneReply,
  _RaceStep.deliverAnnouncement,
];

void _startLocalWork(
  RuleReplyRace race,
  Future<Rule> Function(RuleId ruleId) work,
  RuleId? ruleId,
) {
  if (ruleId == null) {
    return;
  }
  race.pendingWork.start(work(ruleId));
}

void _takeStep(Random random, RuleReplyRace race, _RaceStep step) {
  final RuleId? listedRuleId = pickListedRuleId(random, race);
  switch (step) {
    case _RaceStep.turnRuleOn:
      _startLocalWork(race, race.rules.turnRuleOn, listedRuleId);
    case _RaceStep.turnRuleOff:
      _startLocalWork(race, race.rules.turnRuleOff, listedRuleId);
    case _RaceStep.createRule:
      race.pendingWork.start(
        race.rules.createRule(randomRaceRuleDraft(random, race)),
      );
    case _RaceStep.updateRule:
      final RuleDraft draft = randomRaceRuleDraft(random, race);
      _startLocalWork(
        race,
        (RuleId ruleId) => race.rules.updateRule(ruleId, draft),
        listedRuleId,
      );
    case _RaceStep.deleteRule:
      if (listedRuleId != null) {
        race.pendingWork.start(race.rules.deleteRule(listedRuleId));
      }
    case _RaceStep.editElsewhere:
      editRuleElsewhere(random, race);
    case _RaceStep.deleteElsewhere:
      deleteRuleElsewhere(random, race);
    case _RaceStep.switchWorkspace:
      switchWorkspaceInRace(random, race);
    case _RaceStep.releaseOneReply:
      race.transport.releaseRandomReply();
    case _RaceStep.deliverAnnouncement:
      deliverWaitingAnnouncement(race);
  }
}

Future<void> _expectRaceEndsLikeAReload(
  Random random,
  List<_RaceStep> steps,
) async {
  for (int i = 0; i < _raceIterations; i += 1) {
    final RuleReplyRace race = await openRuleReplyRace(random);
    final int stepCount = 1 + random.nextInt(_longestRace);

    for (int step = 0; step < stepCount; step += 1) {
      _takeStep(random, race, pickOne(random, steps));
      await pumpEventQueue();
    }

    final List<String> shown = await finishRuleReplyRace(race);
    expect(shown, await reloadRulesFrom(race.node.channel, race.workspaces));
    closeRuleReplyRace(race);
  }
}

void main() {
  test('test_node_backed_rule_repository_turn_rule_on_property_late_replies_'
      'end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(seededRandom(80731), const <_RaceStep>[
      _RaceStep.turnRuleOn,
      _RaceStep.editElsewhere,
      _RaceStep.deleteElsewhere,
      _RaceStep.releaseOneReply,
    ]);
  });

  test('test_node_backed_rule_repository_turn_rule_off_property_late_replies_'
      'end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(seededRandom(80732), const <_RaceStep>[
      _RaceStep.turnRuleOff,
      _RaceStep.editElsewhere,
      _RaceStep.deleteElsewhere,
      _RaceStep.releaseOneReply,
    ]);
  });

  test('test_node_backed_rule_repository_load_after_workspace_change_property_'
      'toggles_across_switches_end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(seededRandom(80733), _switchSteps);
  });

  test('test_node_backed_rule_repository_load_property_any_interleaving_ends_'
      'like_a_reload', () async {
    await _expectRaceEndsLikeAReload(seededRandom(80734), _RaceStep.values);
  });
}
