import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/random_schedules.dart';
import '../../support/sample_records.dart';
import 'support/domain_model_properties.dart';

const List<DraftKind> _workKinds = <DraftKind>[DraftKind.task, DraftKind.job];

ModelFieldValues _randomWorkFields(Random random) {
  return <Object?>[
    randomHostileText(random),
    randomHostileText(random),
    if (random.nextBool()) null else randomProjectId(random),
    randomTaskDoer(random),
    randomRunnerTarget(random),
    pickOne(random, AgentPlace.values),
    randomSkillIds(random),
    random.nextBool(),
    randomInheritableApprovalPolicy(random),
    if (random.nextBool()) null else randomSchedule(random),
  ];
}

DraftedWork _buildWork(ModelFieldValues fieldValues) {
  return DraftedWork(
    title: fieldValues[0]! as String,
    details: fieldValues[1]! as String,
    projectId: fieldValues[2] as ProjectId?,
    doer: fieldValues[3]! as TaskDoer,
    runsOn: fieldValues[4]! as RunnerTarget,
    agentPlace: fieldValues[5]! as AgentPlace,
    skills: fieldValues[6]! as List<SkillId>,
    usesAutomaticSkills: fieldValues[7]! as bool,
    approvalPolicy: fieldValues[8] as ApprovalPolicy?,
    schedule: fieldValues[9] as Schedule?,
  );
}

ModelFieldValues _readTaskFieldsOfWork(DraftedWork work) {
  return <Object?>[
    work.title,
    work.details,
    work.projectId,
    work.doer,
    work.runsOn,
    work.agentPlace,
    work.skills,
    work.usesAutomaticSkills,
    work.approvalPolicy,
  ];
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

DraftedWork _randomWorkInProject(Random random) {
  final DraftedWork work = _buildWork(_randomWorkFields(random));
  return DraftedWork(
    title: work.title,
    details: work.details,
    projectId: randomProjectId(random),
    doer: work.doer,
    runsOn: work.runsOn,
    agentPlace: work.agentPlace,
    skills: work.skills,
    usesAutomaticSkills: work.usesAutomaticSkills,
    approvalPolicy: work.approvalPolicy,
    schedule: work.schedule,
  );
}

DraftedWork _randomWorkWithoutProject(Random random, List<SkillId> skills) {
  return DraftedWork(
    title: randomHostileText(random),
    details: randomHostileText(random),
    projectId: null,
    doer: randomTaskDoer(random),
    runsOn: randomRunnerTarget(random),
    agentPlace: pickOne(random, AgentPlace.values),
    skills: skills,
    usesAutomaticSkills: random.nextBool(),
    approvalPolicy: randomInheritableApprovalPolicy(random),
    schedule: null,
  );
}

Object? _describeSchedule(Schedule? schedule) {
  if (schedule == null) {
    return null;
  }
  return mapScheduleToNode(schedule).toJson();
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<DraftedWork>(
      testNamePrefix: 'test_drafted_work_constructor_property',
      seed: 690801,
      randomFieldValues: _randomWorkFields,
      construct: _buildWork,
      readFieldValues: (DraftedWork work) => <Object?>[
        ..._readTaskFieldsOfWork(work),
        work.schedule,
      ],
    ),
  );

  testListCopyProperties(
    ListCopy<DraftedWork, SkillId>(
      testNamePrefix: 'test_drafted_work_constructor_property_skills',
      seed: 690811,
      buildElement: (Random random) => SkillId(randomUuidText(random)),
      construct: _randomWorkWithoutProject,
      readList: (DraftedWork work) => work.skills,
    ),
  );

  test('test_drafted_work_constructor_property_round_trips_the_node', () {
    final Random random = seededRandom(690821);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedWork work = _buildWork(_randomWorkFields(random));
      final DraftKind kind = pickOne(random, _workKinds);

      final DraftedItem roundTripped = mapDraftedItemFromNode(
        mapDraftedItemToNode(work, kind),
      );

      final DraftedWork readWork = roundTripped as DraftedWork;
      expect(_readTaskFieldsOfWork(readWork), _readTaskFieldsOfWork(work));
      expect(
        _describeSchedule(readWork.schedule),
        _describeSchedule(work.schedule),
      );
    }
  });

  test('test_to_task_draft_property_keeps_every_task_field', () {
    final Random random = seededRandom(690831);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedWork work = _randomWorkInProject(random);

      final TaskDraft draft = work.toTaskDraft();

      expect(_readTaskDraftFields(draft), _readTaskFieldsOfWork(work));
    }
  });

  test('test_to_task_draft_property_refuses_work_without_a_project', () {
    final Random random = seededRandom(690832);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedWork work = _randomWorkWithoutProject(
        random,
        randomSkillIds(random),
      );

      expect(work.toTaskDraft, throwsStateError);
    }
  });

  test('test_to_task_draft_property_is_repeatable_and_frozen', () {
    final Random random = seededRandom(690833);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedWork work = _randomWorkInProject(random);

      final TaskDraft first = work.toTaskDraft();
      final TaskDraft second = work.toTaskDraft();

      expect(_readTaskDraftFields(second), _readTaskDraftFields(first));
      expect(
        () => first.skills.add(const SkillId('extra')),
        throwsUnsupportedError,
      );
      expect(work.skills, second.skills);
    }
  });
}
