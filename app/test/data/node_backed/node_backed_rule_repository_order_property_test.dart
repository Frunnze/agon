import 'support/ordered_rule_reply_race.dart';
import 'support/reply_race_properties.dart';

typedef _RuleStep = ReplyRaceStep<OrderedRuleReplyRace>;
typedef _RuleCase = ReplyRaceCase<OrderedRuleReplyRace>;

const List<_RuleStep> _elsewhereSteps = <_RuleStep>[
  addRuleElsewhere,
  deleteRuleElsewhereInOrder,
];

const List<_RuleCase> _raceCases = <_RuleCase>[
  _RuleCase(
    testedName: 'node_backed_rule_repository_create_rule',
    seed: 81601,
    localSteps: <_RuleStep>[createOrderedRaceRule],
    elsewhereSteps: _elsewhereSteps,
  ),
  _RuleCase(
    testedName: 'node_backed_rule_repository_update_rule',
    seed: 81611,
    localSteps: <_RuleStep>[updateOrderedRaceRule],
    elsewhereSteps: _elsewhereSteps,
  ),
  _RuleCase(
    testedName: 'node_backed_rule_repository_store_rule',
    seed: 81621,
    localSteps: <_RuleStep>[createOrderedRaceRule, updateOrderedRaceRule],
    elsewhereSteps: <_RuleStep>[
      ..._elsewhereSteps,
      switchOrderedRuleWorkspace,
    ],
  ),
];

void main() {
  for (final _RuleCase raceCase in _raceCases) {
    registerReplyRaceProperties(
      openRace: openOrderedRuleReplyRace,
      raceCase: raceCase,
    );
  }
}
