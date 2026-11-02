import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/commands/task_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import 'node_json_primitives.dart';
import 'random_catalog_json.dart';
import 'random_work_json.dart';

const String unreachableServerAddress = 'http://127.0.0.1:9';

WorkspaceId randomWorkspaceId(Random random) {
  return WorkspaceId(randomUuidText(random));
}

ProjectId randomProjectId(Random random) {
  return ProjectId(randomUuidText(random));
}

DeviceId randomDeviceId(Random random) {
  return DeviceId(randomDeviceIdText(random));
}

WorkflowId randomWorkflowId(Random random) {
  return WorkflowId(randomUuidText(random));
}

TaskId randomTaskId(Random random) => TaskId(randomUuidText(random));

RunId randomRunId(Random random) => RunId(randomUuidText(random));

List<WorkspaceId> randomWorkspaceIds(Random random) {
  final List<WorkspaceId> workspaceIds = <WorkspaceId>[];
  for (final Object? uuidText in randomUuidTexts(random)) {
    workspaceIds.add(WorkspaceId(uuidText! as String));
  }
  return workspaceIds;
}

List<SkillId> randomSkillIds(Random random) {
  final List<SkillId> skillIds = <SkillId>[];
  for (final Object? uuidText in randomUuidTexts(random)) {
    skillIds.add(SkillId(uuidText! as String));
  }
  return skillIds;
}

TaskArguments randomTaskArguments(Random random) {
  return TaskArguments(
    workspaceId: randomWorkspaceId(random),
    projectId: randomProjectId(random),
    title: randomText(random),
    details: randomText(random),
    doer: TaskDoer.fromJson(randomTaskDoerJson(random)),
    runsOn: RunnerTarget.fromJson(randomRunnerTargetJson(random)),
    skills: randomSkillIds(random),
    usesAutomaticSkills: random.nextBool(),
    approvalPolicy: pickOne(random, ApprovalPolicy.values),
  );
}
