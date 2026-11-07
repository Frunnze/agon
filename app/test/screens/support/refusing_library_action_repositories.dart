import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';

import 'planned_refusal.dart';

final class RefusingSkillRepository implements SkillRepository {
  RefusingSkillRepository({required this.stored, required this.refusal});

  final SkillRepository stored;
  final PlannedRefusal refusal;

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
  Future<Skill> createSkill(SkillDraft draft) {
    return refusal.refuseOr(() => stored.createSkill(draft));
  }

  @override
  Future<Skill> updateSkill(SkillId skillId, SkillDraft draft) {
    return refusal.refuseOr(() => stored.updateSkill(skillId, draft));
  }

  @override
  Future<void> deleteSkill(SkillId skillId) => stored.deleteSkill(skillId);

  @override
  Future<Skill> undoLatestAgentChange(SkillId skillId) {
    return refusal.refuseOr(() => stored.undoLatestAgentChange(skillId));
  }
}

final class RefusingRuleRepository implements RuleRepository {
  RefusingRuleRepository({required this.stored, required this.refusal});

  final RuleRepository stored;
  final PlannedRefusal refusal;

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
  Future<Rule> createRule(RuleDraft draft) {
    return refusal.refuseOr(() => stored.createRule(draft));
  }

  @override
  Future<Rule> updateRule(RuleId ruleId, RuleDraft draft) {
    return refusal.refuseOr(() => stored.updateRule(ruleId, draft));
  }

  @override
  Future<Rule> turnRuleOn(RuleId ruleId) {
    return refusal.refuseOr(() => stored.turnRuleOn(ruleId));
  }

  @override
  Future<Rule> turnRuleOff(RuleId ruleId) {
    return refusal.refuseOr(() => stored.turnRuleOff(ruleId));
  }

  @override
  Future<void> deleteRule(RuleId ruleId) => stored.deleteRule(ruleId);
}

final class RefusingWorkflowRepository implements WorkflowRepository {
  RefusingWorkflowRepository({required this.stored, required this.refusal});

  final WorkflowRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Workflow> listWorkflows() => stored.listWorkflows();

  @override
  Workflow findWorkflow(WorkflowId workflowId) {
    return stored.findWorkflow(workflowId);
  }

  @override
  WorkflowChange? findPendingChange(WorkflowId workflowId) {
    return stored.findPendingChange(workflowId);
  }

  @override
  Future<Workflow> createWorkflow(Workflow unsavedWorkflow) {
    return stored.createWorkflow(unsavedWorkflow);
  }

  @override
  Future<Workflow> saveWorkflow(Workflow workflow) {
    return refusal.refuseOr(() => stored.saveWorkflow(workflow));
  }

  @override
  Future<Workflow> signWorkflow(WorkflowId workflowId) {
    return refusal.refuseOr(() => stored.signWorkflow(workflowId));
  }

  @override
  Future<Workflow> discardChange(WorkflowId workflowId) {
    return refusal.refuseOr(() => stored.discardChange(workflowId));
  }

  @override
  Future<void> deleteWorkflow(WorkflowId workflowId) {
    return stored.deleteWorkflow(workflowId);
  }

  @override
  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft) {
    return stored.draftWorkflow(draft);
  }

  @override
  Future<void> stopDrafting(WorkflowDraft draft) {
    return stored.stopDrafting(draft);
  }

  @override
  Future<Workflow> changeWorkflow(
    WorkflowId workflowId,
    String request,
    AgentKind agent,
  ) {
    return stored.changeWorkflow(workflowId, request, agent);
  }

  @override
  Future<Workflow> fillAgentSettings(
    WorkflowId workflowId,
    WorkflowAgentId agentId,
  ) {
    return refusal.refuseOr(
      () => stored.fillAgentSettings(workflowId, agentId),
    );
  }
}
