import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';

abstract interface class RuleRepository implements Listenable {
  List<Rule> listRules();

  Rule findRule(RuleId ruleId);

  Future<Rule> createRule(RuleDraft draft);

  Future<Rule> updateRule(RuleId ruleId, RuleDraft draft);

  Future<Rule> turnRuleOn(RuleId ruleId);

  Future<Rule> turnRuleOff(RuleId ruleId);

  Future<void> deleteRule(RuleId ruleId);
}
