import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/domain_model_properties.dart';
import 'support/value_equality_properties.dart';

const List<String> _closeWorkflowIdTexts = <String>[
  '',
  ' ',
  'release',
  'Release',
  'release ',
  'café',
  'café',
];

WorkflowId _randomCloseWorkflowId(Random random) {
  return WorkflowId(pickOne(random, _closeWorkflowIdTexts));
}

ModelFieldValues _randomTaskDraftFields(Random random) {
  return <Object?>[
    randomHostileText(random),
    randomHostileText(random),
    randomProjectId(random),
    randomTaskDoer(random),
    randomRunnerTarget(random),
    pickOne(random, AgentPlace.values),
    randomSkillIds(random),
    random.nextBool(),
    randomInheritableApprovalPolicy(random),
  ];
}

TaskDraft _buildTaskDraft(ModelFieldValues fieldValues) {
  return TaskDraft(
    title: fieldValues[0]! as String,
    details: fieldValues[1]! as String,
    projectId: fieldValues[2]! as ProjectId,
    doer: fieldValues[3]! as TaskDoer,
    runsOn: fieldValues[4]! as RunnerTarget,
    agentPlace: fieldValues[5]! as AgentPlace,
    skills: fieldValues[6]! as List<SkillId>,
    usesAutomaticSkills: fieldValues[7]! as bool,
    approvalPolicy: fieldValues[8] as ApprovalPolicy?,
  );
}

TaskDraft _buildTaskDraftWithSkills(Random random, List<SkillId> skills) {
  final ModelFieldValues fieldValues = _randomTaskDraftFields(random);
  fieldValues[6] = skills;

  return _buildTaskDraft(fieldValues);
}

ModelFieldValues _readTaskDraftFields(TaskDraft draft) {
  return <Object?>[
    draft.title,
    draft.details,
    draft.projectId,
    draft.doer,
    draft.runsOn,
    draft.agentPlace,
    draft.skills,
    draft.usesAutomaticSkills,
    draft.approvalPolicy,
  ];
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<OneAgentDoer>(
      testNamePrefix: 'test_one_agent_doer_constructor_property',
      seed: 703301,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, AgentKind.values),
      ],
      construct: (ModelFieldValues fieldValues) =>
          OneAgentDoer(fieldValues[0]! as AgentKind),
      readFieldValues: (OneAgentDoer doer) => <Object?>[doer.agent],
    ),
  );

  testValueEqualityProperties(
    ValueEquality<OneAgentDoer>(
      typeName: 'one_agent_doer',
      seed: 703311,
      randomValue: (Random random) =>
          OneAgentDoer(pickOne(random, AgentKind.values)),
      copyValue: (OneAgentDoer doer) => OneAgentDoer(doer.agent),
      haveSameFields: (OneAgentDoer first, OneAgentDoer second) =>
          first.agent == second.agent,
      otherKinds: <Object>[
        const WorkflowDoer(WorkflowId('claude_code')),
        AgentKind.claudeCode,
        'claude_code',
        const AnyFreeRunner(),
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<WorkflowDoer>(
      testNamePrefix: 'test_workflow_doer_constructor_property',
      seed: 703321,
      randomFieldValues: (Random random) => <Object?>[
        WorkflowId(randomHostileText(random)),
      ],
      construct: (ModelFieldValues fieldValues) =>
          WorkflowDoer(fieldValues[0]! as WorkflowId),
      readFieldValues: (WorkflowDoer doer) => <Object?>[doer.workflowId],
    ),
  );

  testValueEqualityProperties(
    ValueEquality<WorkflowDoer>(
      typeName: 'workflow_doer',
      seed: 703331,
      randomValue: (Random random) =>
          WorkflowDoer(_randomCloseWorkflowId(random)),
      copyValue: (WorkflowDoer doer) =>
          WorkflowDoer(WorkflowId(doer.workflowId.value)),
      haveSameFields: (WorkflowDoer first, WorkflowDoer second) =>
          first.workflowId == second.workflowId,
      otherKinds: <Object>[
        const OneAgentDoer(AgentKind.codex),
        'release',
        const SpecificRunner(DeviceId('release')),
      ],
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<TaskStatus, node.TaskStatus>(
      testNamePrefix: 'test_task_status_values_property',
      choices: TaskStatus.values,
      nodeChoices: node.TaskStatus.values,
      mapFromNode: mapTaskStatusFromNode,
    ),
  );

  testModelConstructorProperties(
    const ModelConstructor<TaskDraft>(
      testNamePrefix: 'test_task_draft_constructor_property',
      seed: 703341,
      randomFieldValues: _randomTaskDraftFields,
      construct: _buildTaskDraft,
      readFieldValues: _readTaskDraftFields,
    ),
  );

  testListCopyProperties(
    ListCopy<TaskDraft, SkillId>(
      testNamePrefix: 'test_task_draft_constructor_property_skills',
      seed: 703351,
      buildElement: (Random random) => SkillId(randomHostileText(random)),
      construct: _buildTaskDraftWithSkills,
      readList: (TaskDraft draft) => draft.skills,
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<JobDraft>(
      testNamePrefix: 'test_job_draft_constructor_property',
      seed: 703361,
      randomFieldValues: (Random random) => <Object?>[
        randomTaskDraft(random),
        randomJobSchedule(random),
      ],
      construct: (ModelFieldValues fieldValues) => JobDraft(
        task: fieldValues[0]! as TaskDraft,
        schedule: fieldValues[1]! as Schedule,
      ),
      readFieldValues: (JobDraft draft) => <Object?>[
        draft.task,
        draft.schedule,
      ],
    ),
  );
}
