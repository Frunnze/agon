import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/domain_model_properties.dart';
import 'support/random_workflow_agent_fields.dart';

WorkflowAgent _randomAgent(Random random) {
  return buildWorkflowAgent(randomWorkflowAgentFields(random));
}

WorkflowAgent _buildAgentWithSkills(Random random, List<SkillId> skills) {
  final ModelFieldValues fieldValues = randomWorkflowAgentFields(random);
  fieldValues[workflowAgentSkillsField] = skills;

  return buildWorkflowAgent(fieldValues);
}

void _testCopyWithField<Change>({
  required String fieldName,
  required int fieldIndex,
  required int seed,
  required Change Function(Random random) randomChange,
  required WorkflowAgent Function(WorkflowAgent agent, Change change)
  applyChange,
}) {
  testModelCopyProperties(
    ModelCopy<WorkflowAgent, Change>(
      testNamePrefix: 'test_workflow_agent_copy_with_property_$fieldName',
      seed: seed,
      randomModel: _randomAgent,
      randomChange: randomChange,
      applyChange: applyChange,
      readChangedField: (WorkflowAgent agent) =>
          readWorkflowAgentFields(agent)[fieldIndex],
      readOtherFields: (WorkflowAgent agent) =>
          readWorkflowAgentFieldsBesides(agent, fieldIndex),
    ),
  );
}

void main() {
  testModelConstructorProperties(
    const ModelConstructor<WorkflowAgent>(
      testNamePrefix: 'test_workflow_agent_constructor_property',
      seed: 703601,
      randomFieldValues: randomWorkflowAgentFields,
      construct: buildWorkflowAgent,
      readFieldValues: readWorkflowAgentFields,
    ),
  );

  testListCopyProperties(
    ListCopy<WorkflowAgent, SkillId>(
      testNamePrefix: 'test_workflow_agent_constructor_property_skills',
      seed: 703611,
      buildElement: (Random random) => SkillId(randomHostileText(random)),
      construct: _buildAgentWithSkills,
      readList: (WorkflowAgent agent) => agent.skills,
    ),
  );

  _testCopyWithField<String>(
    fieldName: 'name',
    fieldIndex: workflowAgentNameField,
    seed: 703621,
    randomChange: randomHostileText,
    applyChange: (WorkflowAgent agent, String name) =>
        agent.copyWith(name: name),
  );

  _testCopyWithField<AgentKind>(
    fieldName: 'kind',
    fieldIndex: workflowAgentKindField,
    seed: 703631,
    randomChange: (Random random) => pickOne(random, AgentKind.values),
    applyChange: (WorkflowAgent agent, AgentKind kind) =>
        agent.copyWith(kind: kind),
  );

  _testCopyWithField<String>(
    fieldName: 'task',
    fieldIndex: workflowAgentTaskField,
    seed: 703641,
    randomChange: randomHostileText,
    applyChange: (WorkflowAgent agent, String task) =>
        agent.copyWith(task: task),
  );

  _testCopyWithField<RunnerTarget>(
    fieldName: 'runs_on',
    fieldIndex: workflowAgentRunsOnField,
    seed: 703651,
    randomChange: randomRunnerTarget,
    applyChange: (WorkflowAgent agent, RunnerTarget runsOn) =>
        agent.copyWith(runsOn: runsOn),
  );

  _testCopyWithField<List<SkillId>>(
    fieldName: 'skills',
    fieldIndex: workflowAgentSkillsField,
    seed: 703661,
    randomChange: randomSkillIds,
    applyChange: (WorkflowAgent agent, List<SkillId> skills) =>
        agent.copyWith(skills: skills),
  );

  _testCopyWithField<bool>(
    fieldName: 'uses_automatic_skills',
    fieldIndex: workflowAgentUsesAutomaticSkillsField,
    seed: 703671,
    randomChange: (Random random) => random.nextBool(),
    applyChange: (WorkflowAgent agent, bool usesAutomaticSkills) =>
        agent.copyWith(usesAutomaticSkills: usesAutomaticSkills),
  );

  _testCopyWithField<CanvasPosition>(
    fieldName: 'position',
    fieldIndex: workflowAgentPositionField,
    seed: 703681,
    randomChange: randomWorkflowAgentPosition,
    applyChange: (WorkflowAgent agent, CanvasPosition position) =>
        agent.copyWith(position: position),
  );

  test('test_workflow_agent_copy_with_property_no_changes_keeps_all', () {
    final Random random = seededRandom(703691);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = _randomAgent(random);

      final WorkflowAgent copy = agent.copyWith();

      expect(readWorkflowAgentFields(copy), readWorkflowAgentFields(agent));
      expect(copy, agent);
      expect(copy.hashCode, agent.hashCode);
    }
  });

  test('test_workflow_agent_copy_with_property_frozen_skills_copy', () {
    final Random random = seededRandom(703693);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = _randomAgent(random);
      final List<SkillId> givenSkills = randomSkillIds(random);
      final List<SkillId> skillsAtCopy = List<SkillId>.of(givenSkills);

      final WorkflowAgent copy = agent.copyWith(skills: givenSkills);
      givenSkills.add(SkillId(randomHostileText(random)));

      expect(copy.skills, orderedEquals(skillsAtCopy));
      expect(
        () => copy.skills.add(SkillId(randomHostileText(random))),
        throwsUnsupportedError,
      );
    }
  });

  testModelCopyProperties(
    ModelCopy<WorkflowAgent, ApprovalPolicy?>(
      testNamePrefix: 'test_workflow_agent_with_approval_policy_property',
      seed: 703701,
      randomModel: _randomAgent,
      randomChange: randomInheritableApprovalPolicy,
      applyChange: (WorkflowAgent agent, ApprovalPolicy? policy) =>
          agent.withApprovalPolicy(policy),
      readChangedField: (WorkflowAgent agent) => agent.approvalPolicy,
      readOtherFields: (WorkflowAgent agent) => readWorkflowAgentFieldsBesides(
        agent,
        workflowAgentApprovalPolicyField,
      ),
    ),
  );
}
