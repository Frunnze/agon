import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

node.DraftKind mapDraftKindToNode(DraftKind kind) {
  return switch (kind) {
    DraftKind.task => node.DraftKind.task,
    DraftKind.job => node.DraftKind.job,
    DraftKind.project => node.DraftKind.project,
    DraftKind.skill => node.DraftKind.skill,
    DraftKind.rule => node.DraftKind.rule,
  };
}

node.DraftedRepository mapRepositoryDraftToNode(RepositoryDraft repository) {
  return node.DraftedRepository(
    address: repository.address,
    defaultBranch: repository.defaultBranch,
  );
}

ItemDraft mapItemDraftFromNode(node.ItemDraftDone done) {
  return ItemDraft(
    item: mapDraftedItemFromNode(done.draft),
    problems: done.problems,
  );
}

DraftedItem mapDraftedItemFromNode(node.ItemDraft draft) {
  return switch (draft) {
    node.WorkItemDraft() => _mapWorkFromNode(draft),
    node.ProjectItemDraft() => DraftedProject(
      name: draft.name,
      repositories: <RepositoryDraft>[
        for (final node.DraftedRepository repository in draft.repositories)
          RepositoryDraft(
            address: repository.address,
            defaultBranch: repository.defaultBranch,
          ),
      ],
      agentAccess: mapAgentAccessFromNode(draft.agentAccess),
    ),
    node.SkillItemDraft() => DraftedSkill(
      SkillDraft(
        name: draft.name,
        summary: draft.summary,
        instructions: draft.instructions,
        scope: mapScopeFromNode(draft.scope),
        usage: mapSkillUsageFromNode(draft.usage),
        improvement: mapSkillImprovementFromNode(draft.improvement),
      ),
    ),
    node.RuleItemDraft() => DraftedRule(
      RuleDraft(
        title: draft.title,
        details: draft.details,
        scope: mapScopeFromNode(draft.scope),
      ),
    ),
  };
}

node.ItemDraft mapDraftedItemToNode(DraftedItem item, DraftKind kind) {
  return switch (item) {
    DraftedWork() => _mapWorkToNode(item, kind),
    DraftedProject() => node.ProjectItemDraft(
      name: item.name,
      repositories: <node.DraftedRepository>[
        for (final RepositoryDraft repository in item.repositories)
          mapRepositoryDraftToNode(repository),
      ],
      agentAccess: mapAgentAccessToNode(item.agentAccess),
    ),
    DraftedSkill(:final SkillDraft skill) => node.SkillItemDraft(
      name: skill.name,
      summary: skill.summary,
      instructions: skill.instructions,
      scope: mapScopeToNode(skill.scope),
      usage: mapSkillUsageToNode(skill.usage),
      improvement: mapSkillImprovementToNode(skill.improvement),
    ),
    DraftedRule(:final RuleDraft rule) => node.RuleItemDraft(
      title: rule.title,
      details: rule.details,
      scope: mapScopeToNode(rule.scope),
    ),
  };
}

DraftedWork _mapWorkFromNode(node.WorkItemDraft draft) {
  final node.Schedule? wireSchedule = draft.schedule;
  final Schedule? schedule = wireSchedule == null
      ? null
      : mapScheduleFromNode(wireSchedule);

  return DraftedWork(
    title: draft.title,
    details: draft.details,
    projectId: draft.projectId,
    doer: mapTaskDoerFromNode(draft.doer),
    runsOn: mapRunnerTargetFromNode(draft.runsOn),
    agentPlace: mapAgentPlaceFromNode(draft.agentPlace),
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: mapApprovalPolicyFromNode(draft.approvalPolicy),
    schedule: schedule,
  );
}

node.WorkItemDraft _mapWorkToNode(DraftedWork work, DraftKind kind) {
  final Schedule? schedule = work.schedule;
  final node.Schedule? wireSchedule = schedule == null
      ? null
      : mapScheduleToNode(schedule);

  return node.WorkItemDraft(
    kind: mapDraftKindToNode(kind),
    title: work.title,
    details: work.details,
    projectId: work.projectId,
    doer: mapTaskDoerToNode(work.doer),
    runsOn: mapRunnerTargetToNode(work.runsOn),
    agentPlace: mapAgentPlaceToNode(work.agentPlace),
    skills: work.skills,
    usesAutomaticSkills: work.usesAutomaticSkills,
    approvalPolicy: mapApprovalPolicyToNode(work.approvalPolicy),
    schedule: wireSchedule,
  );
}
