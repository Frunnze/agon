import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';

final class DeleteRefusingRuleRepository implements RuleRepository {
  DeleteRefusingRuleRepository({required this.stored, required this.refusal});

  final RuleRepository stored;
  final String refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Rule> listRules() => stored.listRules();

  @override
  Rule findRule(RuleId ruleId) => stored.findRule(ruleId);

  @override
  Future<Rule> createRule(RuleDraft draft) => stored.createRule(draft);

  @override
  Future<Rule> updateRule(RuleId ruleId, RuleDraft draft) {
    return stored.updateRule(ruleId, draft);
  }

  @override
  Future<Rule> turnRuleOn(RuleId ruleId) => stored.turnRuleOn(ruleId);

  @override
  Future<Rule> turnRuleOff(RuleId ruleId) => stored.turnRuleOff(ruleId);

  @override
  Future<void> deleteRule(RuleId ruleId) {
    return Future<void>.error(StateError(refusal));
  }
}

final class DeleteRefusingSkillRepository implements SkillRepository {
  DeleteRefusingSkillRepository({required this.stored, required this.refusal});

  final SkillRepository stored;
  final String refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Skill> listSkills() => stored.listSkills();

  @override
  Skill findSkill(SkillId skillId) => stored.findSkill(skillId);

  @override
  Future<Skill> createSkill(SkillDraft draft) => stored.createSkill(draft);

  @override
  Future<Skill> updateSkill(SkillId skillId, SkillDraft draft) {
    return stored.updateSkill(skillId, draft);
  }

  @override
  Future<void> deleteSkill(SkillId skillId) {
    return Future<void>.error(StateError(refusal));
  }

  @override
  Future<Skill> undoLatestAgentChange(SkillId skillId) {
    return stored.undoLatestAgentChange(skillId);
  }
}
