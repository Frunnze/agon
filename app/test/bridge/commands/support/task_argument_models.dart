import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/bridge/commands/task_commands.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../../support/random_inputs.dart';
import '../../support/hostile_texts.dart';
import '../../support/node_wire_names.dart';
import '../../support/random_catalog_json.dart';
import '../../support/random_work_json.dart';
import '../../support/simple_command_properties.dart';
import 'project_command_wire_models.dart';

typedef ModelledTaskArguments = ({
  TaskArguments arguments,
  List<Object?> givenFields,
  List<SkillId> givenSkills,
  JsonObject expectedJson,
});

List<Object?> readTaskArgumentFields(TaskArguments arguments) {
  return <Object?>[
    arguments.workspaceId,
    arguments.projectId,
    arguments.title,
    arguments.details,
    arguments.doer,
    arguments.runsOn,
    arguments.agentPlace,
    arguments.usesAutomaticSkills,
    arguments.approvalPolicy,
  ];
}

List<SkillId> randomHostileSkillIds(Random random) {
  final List<SkillId> skills = <SkillId>[];
  for (final String skillText in randomHostileTexts(random)) {
    skills.add(SkillId(skillText));
  }
  return skills;
}

ModelledTaskArguments randomModelledTaskArguments(Random random) {
  final WorkspaceId workspaceId = WorkspaceId(randomHostileText(random));
  final ProjectId projectId = ProjectId(randomHostileText(random));
  final String title = randomArgumentText(random);
  final String details = randomArgumentText(random);
  final JsonObject doerJson = randomTaskDoerJson(random);
  final JsonObject runsOnJson = randomRunnerTargetJson(random);
  final String agentPlaceName = pickOne(random, nodeAgentPlaces);
  final List<SkillId> skills = randomHostileSkillIds(random);
  final bool usesAutomaticSkills = random.nextBool();
  final ApprovalPolicy? approvalPolicy = randomChosenApprovalPolicy(random);

  final TaskDoer doer = TaskDoer.fromJson(doerJson);
  final RunnerTarget runsOn = RunnerTarget.fromJson(runsOnJson);
  final AgentPlace agentPlace = AgentPlace.decode(agentPlaceName);
  final TaskArguments arguments = TaskArguments(
    workspaceId: workspaceId,
    projectId: projectId,
    title: title,
    details: details,
    doer: doer,
    runsOn: runsOn,
    agentPlace: agentPlace,
    skills: skills,
    usesAutomaticSkills: usesAutomaticSkills,
    approvalPolicy: approvalPolicy,
  );

  final List<String> skillTexts = <String>[];
  for (final SkillId skill in skills) {
    skillTexts.add(skill.value);
  }
  return (
    arguments: arguments,
    givenFields: <Object?>[
      workspaceId,
      projectId,
      title,
      details,
      doer,
      runsOn,
      agentPlace,
      usesAutomaticSkills,
      approvalPolicy,
    ],
    givenSkills: List<SkillId>.of(skills),
    expectedJson: <String, Object?>{
      'workspace_id': workspaceId.value,
      'project_id': projectId.value,
      'title': title,
      'details': details,
      'doer': doerJson,
      'runs_on': runsOnJson,
      'agent_place': agentPlaceName,
      'skills': skillTexts,
      'uses_automatic_skills': usesAutomaticSkills,
      'approval_policy': expectedApprovalPolicyName(approvalPolicy),
    },
  );
}
