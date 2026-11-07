import 'dart:math';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_json_primitives.dart';
import '../../../bridge/support/random_typed_values.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_records.dart';
import 'domain_model_properties.dart';

const int workflowAgentNameField = 1;
const int workflowAgentKindField = 3;
const int workflowAgentTaskField = 4;
const int workflowAgentRunsOnField = 5;
const int workflowAgentSkillsField = 6;
const int workflowAgentUsesAutomaticSkillsField = 7;
const int workflowAgentApprovalPolicyField = 8;
const int workflowAgentPositionField = 9;

AgentKind? _randomOptionalKind(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return pickOne(random, AgentKind.values);
}

CanvasPosition randomWorkflowAgentPosition(Random random) {
  return CanvasPosition(
    horizontal: randomCanvasCoordinate(random),
    vertical: randomCanvasCoordinate(random),
  );
}

ModelFieldValues randomWorkflowAgentFields(Random random) {
  return <Object?>[
    WorkflowAgentId(randomHostileText(random)),
    randomHostileText(random),
    pickOne(random, StepKind.values),
    _randomOptionalKind(random),
    randomHostileText(random),
    randomRunnerTarget(random),
    randomSkillIds(random),
    random.nextBool(),
    randomInheritableApprovalPolicy(random),
    randomWorkflowAgentPosition(random),
  ];
}

WorkflowAgent buildWorkflowAgent(ModelFieldValues fieldValues) {
  return WorkflowAgent(
    id: fieldValues[0]! as WorkflowAgentId,
    name: fieldValues[workflowAgentNameField]! as String,
    stepKind: fieldValues[2]! as StepKind,
    kind: fieldValues[workflowAgentKindField] as AgentKind?,
    task: fieldValues[workflowAgentTaskField]! as String,
    runsOn: fieldValues[workflowAgentRunsOnField]! as RunnerTarget,
    skills: fieldValues[workflowAgentSkillsField]! as List<SkillId>,
    usesAutomaticSkills:
        fieldValues[workflowAgentUsesAutomaticSkillsField]! as bool,
    approvalPolicy:
        fieldValues[workflowAgentApprovalPolicyField] as ApprovalPolicy?,
    position: fieldValues[workflowAgentPositionField]! as CanvasPosition,
  );
}

ModelFieldValues readWorkflowAgentFields(WorkflowAgent agent) {
  return <Object?>[
    agent.id,
    agent.name,
    agent.stepKind,
    agent.kind,
    agent.task,
    agent.runsOn,
    agent.skills,
    agent.usesAutomaticSkills,
    agent.approvalPolicy,
    agent.position,
  ];
}

ModelFieldValues readWorkflowAgentFieldsBesides(
  WorkflowAgent agent,
  int skippedField,
) {
  final ModelFieldValues fieldValues = readWorkflowAgentFields(agent);
  final ModelFieldValues otherFieldValues = <Object?>[];
  for (int i = 0; i < fieldValues.length; i += 1) {
    if (i != skippedField) {
      otherFieldValues.add(fieldValues[i]);
    }
  }
  return otherFieldValues;
}
