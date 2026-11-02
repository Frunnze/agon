import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/rules/rule_titles.dart';

const String _ruleKind = 'rule';

final class FakeRuleRepository extends ChangeNotifier
    implements RuleRepository {
  FakeRuleRepository({required List<Rule> rules, required Clock clock})
    : _rules = List<Rule>.unmodifiable(rules),
      _clock = clock;

  final Clock _clock;
  List<Rule> _rules;
  int _createdRuleCount = 0;

  @override
  List<Rule> listRules() => _rules;

  @override
  Rule findRule(RuleId ruleId) {
    return findRecord(
      _rules,
      matches: (Rule rule) => rule.id == ruleId,
      kind: _ruleKind,
      identifier: ruleId.value,
    );
  }

  @override
  Future<Rule> createRule(RuleDraft draft) async {
    requireRuleTitle(draft.title);

    _createdRuleCount += 1;
    final Rule rule = Rule(
      id: RuleId('created-rule-$_createdRuleCount'),
      title: draft.title.trim(),
      details: draft.details,
      scope: draft.scope,
      enabled: true,
      addedAt: _clock.now(),
    );

    _rules = appendRecord(_rules, rule);
    notifyListeners();
    return rule;
  }

  @override
  Future<Rule> updateRule(RuleId ruleId, RuleDraft draft) async {
    requireRuleTitle(draft.title);
    final Rule original = findRule(ruleId);

    return _storeRule(
      Rule(
        id: ruleId,
        title: draft.title.trim(),
        details: draft.details,
        scope: draft.scope,
        enabled: original.enabled,
        addedAt: original.addedAt,
      ),
    );
  }

  @override
  Future<Rule> turnRuleOn(RuleId ruleId) async {
    return _storeRule(findRule(ruleId).asEnabled());
  }

  @override
  Future<Rule> turnRuleOff(RuleId ruleId) async {
    return _storeRule(findRule(ruleId).asDisabled());
  }

  @override
  Future<void> deleteRule(RuleId ruleId) async {
    findRule(ruleId);

    _rules = removeRecord(_rules, matches: (Rule rule) => rule.id == ruleId);
    notifyListeners();
  }

  Rule _storeRule(Rule rule) {
    _rules = replaceRecord(
      _rules,
      matches: (Rule candidate) => candidate.id == rule.id,
      replacement: rule,
    );
    notifyListeners();
    return rule;
  }
}
