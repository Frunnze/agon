import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_workflows.dart';
import '../../support/sample_records.dart';
import 'support/domain_model_properties.dart';
import 'support/random_workflow_agent_fields.dart';
import 'support/value_equality_properties.dart';

const int _rareChoiceOdds = 8;

Choice _pickMostlyFirst<Choice>(Random random, List<Choice> choices) {
  if (random.nextInt(_rareChoiceOdds) == 0) {
    return choices.last;
  }
  return choices.first;
}

WorkflowAgent _randomCloseAgent(Random random) {
  return WorkflowAgent(
    id: _pickMostlyFirst(random, const <WorkflowAgentId>[
      WorkflowAgentId('plan'),
      WorkflowAgentId('plan '),
    ]),
    name: _pickMostlyFirst(random, const <String>['plan', 'Plan']),
    stepKind: _pickMostlyFirst(random, StepKind.values),
    kind: _pickMostlyFirst(random, const <AgentKind?>[null, AgentKind.codex]),
    task: _pickMostlyFirst(random, const <String>['', ' ']),
    runsOn: _pickMostlyFirst(random, <RunnerTarget>[
      const AnyFreeRunner(),
      RunnerWithLabels(const <String>['gpu']),
    ]),
    skills: _pickMostlyFirst(random, <List<SkillId>>[
      <SkillId>[],
      <SkillId>[sampleSkillIds.first],
    ]),
    usesAutomaticSkills: _pickMostlyFirst(random, <bool>[true, false]),
    approvalPolicy: _pickMostlyFirst(random, inheritableApprovalPolicies),
    position: _pickMostlyFirst(random, const <CanvasPosition>[
      CanvasPosition(horizontal: 0, vertical: 0),
      CanvasPosition(horizontal: 0, vertical: 1),
    ]),
  );
}

WorkflowAgent _copyAgent(WorkflowAgent agent) {
  final ModelFieldValues fieldValues = readWorkflowAgentFields(agent);
  fieldValues[workflowAgentSkillsField] = List<SkillId>.of(agent.skills);
  fieldValues[workflowAgentPositionField] = copyPosition(agent.position);

  return buildWorkflowAgent(fieldValues);
}

bool _haveSameAgentFields(WorkflowAgent first, WorkflowAgent second) {
  final bool haveSameSkills = listEquals(first.skills, second.skills);
  final ModelFieldValues firstOthers = readWorkflowAgentFieldsBesides(
    first,
    workflowAgentSkillsField,
  );
  final ModelFieldValues secondOthers = readWorkflowAgentFieldsBesides(
    second,
    workflowAgentSkillsField,
  );

  return haveSameSkills && listEquals(firstOthers, secondOthers);
}

void main() {
  testValueEqualityProperties(
    const ValueEquality<WorkflowAgent>(
      typeName: 'workflow_agent',
      seed: 703711,
      randomValue: _randomCloseAgent,
      copyValue: _copyAgent,
      haveSameFields: _haveSameAgentFields,
      otherKinds: <Object>[
        WorkflowAgentId('plan'),
        'plan',
        CanvasPosition(horizontal: 0, vertical: 0),
        AgentKind.codex,
      ],
    ),
  );
}
