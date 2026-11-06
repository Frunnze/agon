import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/item_draft_values.dart';
import 'package:agent_orchestration/bridge/codecs/library_values.dart';
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import 'hostile_texts.dart';
import 'random_catalog_json.dart';
import 'random_typed_values.dart';
import 'random_work_json.dart';

const List<DraftKind> workDraftKinds = <DraftKind>[
  DraftKind.task,
  DraftKind.job,
];

WorkItemDraft randomWorkItemDraft(Random random) {
  final Schedule? schedule = random.nextBool()
      ? null
      : Schedule.fromJson(randomScheduleJson(random));

  return WorkItemDraft(
    kind: pickOne(random, workDraftKinds),
    title: randomHostileText(random),
    details: randomHostileText(random),
    projectId: random.nextBool() ? null : randomProjectId(random),
    doer: TaskDoer.fromJson(randomTaskDoerJson(random)),
    runsOn: RunnerTarget.fromJson(randomRunnerTargetJson(random)),
    agentPlace: pickOne(random, AgentPlace.values),
    skills: randomSkillIds(random),
    usesAutomaticSkills: random.nextBool(),
    approvalPolicy: randomOptionalApprovalPolicy(random),
    schedule: schedule,
  );
}

SkillItemDraft randomSkillItemDraft(Random random) {
  return SkillItemDraft(
    name: randomHostileText(random),
    summary: randomHostileText(random),
    instructions: randomHostileText(random),
    scope: Scope.fromJson(randomScopeJson(random)),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

RuleItemDraft randomRuleItemDraft(Random random) {
  return RuleItemDraft(
    title: randomHostileText(random),
    details: randomHostileText(random),
    scope: Scope.fromJson(randomScopeJson(random)),
  );
}

ItemDraft randomTypedItemDraft(Random random) {
  return pickOne(random, <ItemDraft>[
    randomWorkItemDraft(random),
    randomSkillItemDraft(random),
    randomRuleItemDraft(random),
  ]);
}
