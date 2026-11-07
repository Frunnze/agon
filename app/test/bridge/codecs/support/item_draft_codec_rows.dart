import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/drafting_task_views.dart';
import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/item_draft_command_shapes.dart';
import '../../support/random_work_json.dart';
import 'codec_rows.dart';

const List<ConstructorRow> itemDraftConstructorRows = <ConstructorRow>[
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'drafting_task_view',
      buildJson: randomDraftingTaskViewJson,
      decode: DraftingTaskView.fromJson,
    ),
    rebuild: _rebuildDraftingTaskView,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'workflow_agent_task_view',
      buildJson: randomWorkflowAgentTaskJson,
      decode: WorkflowAgentTaskView.fromJson,
    ),
    rebuild: _rebuildWorkflowAgentTaskView,
  ),
  ConstructorRow(encodable: itemDraftRow, rebuild: _rebuildItemDraft),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'work_item_draft',
      buildJson: randomWorkItemDraftJson,
      decode: ItemDraft.fromJson,
    ),
    rebuild: _rebuildItemDraft,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'skill_item_draft',
      buildJson: randomSkillItemDraftJson,
      decode: ItemDraft.fromJson,
    ),
    rebuild: _rebuildItemDraft,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'rule_item_draft',
      buildJson: randomRuleItemDraftJson,
      decode: ItemDraft.fromJson,
    ),
    rebuild: _rebuildItemDraft,
  ),
  ConstructorRow(
    encodable: itemDraftStatusRow,
    rebuild: _rebuildItemDraftStatus,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'item_draft_working',
      buildJson: randomItemDraftWorkingJson,
      decode: ItemDraftStatus.fromJson,
    ),
    rebuild: _rebuildItemDraftStatus,
  ),
  ConstructorRow(
    encodable: EncodableRow(
      typeName: 'item_draft_done',
      buildJson: randomItemDraftDoneJson,
      decode: ItemDraftStatus.fromJson,
    ),
    rebuild: _rebuildItemDraftStatus,
  ),
];

const EncodableRow itemDraftRow = EncodableRow(
  typeName: 'item_draft',
  buildJson: randomItemDraftJson,
  decode: ItemDraft.fromJson,
);

const EncodableRow itemDraftStatusRow = EncodableRow(
  typeName: 'item_draft_status',
  buildJson: randomItemDraftStatusJson,
  decode: ItemDraftStatus.fromJson,
);

Object? randomWorkItemDraftJson(Random random) {
  return randomJsonOfKind<WorkItemDraft>(
    random: random,
    buildJson: randomItemDraftJson,
    decode: ItemDraft.fromJson,
  );
}

Object? randomSkillItemDraftJson(Random random) {
  return randomJsonOfKind<SkillItemDraft>(
    random: random,
    buildJson: randomItemDraftJson,
    decode: ItemDraft.fromJson,
  );
}

Object? randomRuleItemDraftJson(Random random) {
  return randomJsonOfKind<RuleItemDraft>(
    random: random,
    buildJson: randomItemDraftJson,
    decode: ItemDraft.fromJson,
  );
}

Object? randomItemDraftWorkingJson(Random random) {
  return randomJsonOfKind<ItemDraftWorking>(
    random: random,
    buildJson: randomItemDraftStatusJson,
    decode: ItemDraftStatus.fromJson,
  );
}

Object? randomItemDraftDoneJson(Random random) {
  return randomJsonOfKind<ItemDraftDone>(
    random: random,
    buildJson: randomItemDraftStatusJson,
    decode: ItemDraftStatus.fromJson,
  );
}

WorkItemDraft rebuildWorkItemDraft({
  required WorkItemDraft draft,
  required DraftKind kind,
}) {
  return WorkItemDraft(
    kind: kind,
    title: draft.title,
    details: draft.details,
    projectId: draft.projectId,
    doer: draft.doer,
    runsOn: draft.runsOn,
    agentPlace: draft.agentPlace,
    skills: draft.skills,
    usesAutomaticSkills: draft.usesAutomaticSkills,
    approvalPolicy: draft.approvalPolicy,
    schedule: draft.schedule,
  );
}

JsonEncodable _rebuildDraftingTaskView(JsonEncodable value) {
  final DraftingTaskView view = value as DraftingTaskView;
  return DraftingTaskView(taskId: view.taskId, drafter: view.drafter);
}

JsonEncodable _rebuildWorkflowAgentTaskView(JsonEncodable value) {
  final WorkflowAgentTaskView view = value as WorkflowAgentTaskView;
  return WorkflowAgentTaskView(
    workflowId: view.workflowId,
    taskId: view.taskId,
    drafter: view.drafter,
  );
}

JsonEncodable _rebuildItemDraft(JsonEncodable value) {
  final ItemDraft draft = value as ItemDraft;
  return switch (draft) {
    WorkItemDraft() => rebuildWorkItemDraft(draft: draft, kind: draft.kind),
    SkillItemDraft() => SkillItemDraft(
      name: draft.name,
      summary: draft.summary,
      instructions: draft.instructions,
      scope: draft.scope,
      usage: draft.usage,
      improvement: draft.improvement,
    ),
    RuleItemDraft() => RuleItemDraft(
      title: draft.title,
      details: draft.details,
      scope: draft.scope,
    ),
  };
}

JsonEncodable _rebuildItemDraftStatus(JsonEncodable value) {
  final ItemDraftStatus status = value as ItemDraftStatus;
  return switch (status) {
    ItemDraftWorking() => const ItemDraftWorking(),
    ItemDraftDone() => ItemDraftDone(
      draft: status.draft,
      problems: status.problems,
    ),
  };
}
