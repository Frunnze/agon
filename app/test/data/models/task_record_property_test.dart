import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_moments.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/domain_model_properties.dart';

const int _draftFieldCount = 9;
const int _skillsField = 7;

Schedule? _randomOptionalSchedule(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomJobSchedule(random);
}

ModelFieldValues _randomTaskFields(Random random) {
  return <Object?>[
    randomTaskId(random),
    randomHostileText(random),
    randomHostileText(random),
    randomProjectId(random),
    randomTaskDoer(random),
    randomRunnerTarget(random),
    pickOne(random, AgentPlace.values),
    randomSkillIds(random),
    random.nextBool(),
    randomInheritableApprovalPolicy(random),
    _randomOptionalSchedule(random),
    pickOne(random, TaskStatus.values),
    randomPreciseMoment(random),
  ];
}

Task _buildTask(ModelFieldValues fieldValues) {
  return Task(
    id: fieldValues[0]! as TaskId,
    title: fieldValues[1]! as String,
    details: fieldValues[2]! as String,
    projectId: fieldValues[3]! as ProjectId,
    doer: fieldValues[4]! as TaskDoer,
    runsOn: fieldValues[5]! as RunnerTarget,
    agentPlace: fieldValues[6]! as AgentPlace,
    skills: fieldValues[_skillsField]! as List<SkillId>,
    usesAutomaticSkills: fieldValues[8]! as bool,
    approvalPolicy: fieldValues[9] as ApprovalPolicy?,
    schedule: fieldValues[10] as Schedule?,
    status: fieldValues[11]! as TaskStatus,
    createdAt: fieldValues[12]! as DateTime,
  );
}

ModelFieldValues _readTaskFields(Task task) {
  return <Object?>[
    task.id,
    ..._readDraftPartOfTask(task),
    task.schedule,
    task.status,
    task.createdAt,
  ];
}

ModelFieldValues _readDraftPartOfTask(Task task) {
  return <Object?>[
    task.title,
    task.details,
    task.projectId,
    task.doer,
    task.runsOn,
    task.agentPlace,
    task.skills,
    task.usesAutomaticSkills,
    task.approvalPolicy,
  ];
}

ModelFieldValues _readDraftFields(TaskDraft draft) {
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

ModelFieldValues _readTaskFieldsBesidesStatus(Task task) {
  return <Object?>[
    task.id,
    ..._readDraftPartOfTask(task),
    task.schedule,
    task.createdAt,
  ];
}

Task _buildTaskWithSkills(Random random, List<SkillId> skills) {
  final ModelFieldValues fieldValues = _randomTaskFields(random);
  fieldValues[_skillsField] = skills;

  return _buildTask(fieldValues);
}

Task _randomTask(Random random) => _buildTask(_randomTaskFields(random));

Task _rebuildFromDraft(Task task, TaskDraft draft) {
  return Task.fromDraft(
    id: task.id,
    draft: draft,
    schedule: task.schedule,
    status: task.status,
    createdAt: task.createdAt,
  );
}

void main() {
  testModelConstructorProperties(
    const ModelConstructor<Task>(
      testNamePrefix: 'test_task_constructor_property',
      seed: 703401,
      randomFieldValues: _randomTaskFields,
      construct: _buildTask,
      readFieldValues: _readTaskFields,
    ),
  );

  testListCopyProperties(
    ListCopy<Task, SkillId>(
      testNamePrefix: 'test_task_constructor_property_skills',
      seed: 703411,
      buildElement: (Random random) => SkillId(randomHostileText(random)),
      construct: _buildTaskWithSkills,
      readList: (Task task) => task.skills,
    ),
  );

  test('test_task_from_draft_property_keeps_draft_and_given_fields', () {
    final Random random = seededRandom(703421);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDraft draft = randomTaskDraft(random);
      final TaskId id = randomTaskId(random);
      final Schedule? schedule = _randomOptionalSchedule(random);
      final TaskStatus status = pickOne(random, TaskStatus.values);
      final DateTime createdAt = randomPreciseMoment(random);

      final Task task = Task.fromDraft(
        id: id,
        draft: draft,
        schedule: schedule,
        status: status,
        createdAt: createdAt,
      );

      final ModelFieldValues givenFields = <Object?>[
        id,
        schedule,
        status,
        createdAt,
      ];
      final ModelFieldValues keptFields = <Object?>[
        task.id,
        task.schedule,
        task.status,
        task.createdAt,
      ];

      expect(_readDraftPartOfTask(task), _readDraftFields(draft));
      expect(keptFields, givenFields);
    }
  });

  test('test_task_from_draft_property_agrees_with_the_constructor', () {
    final Random random = seededRandom(703431);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task built = _randomTask(random);

      final Task fromDraft = _rebuildFromDraft(built, built.toDraft());

      expect(_readTaskFields(fromDraft), _readTaskFields(built));
    }
  });

  test('test_task_from_draft_property_skills_stay_frozen', () {
    final Random random = seededRandom(703441);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDraft draft = randomTaskDraft(random);
      final List<SkillId> skillsBefore = List<SkillId>.of(draft.skills);
      final Task task = _rebuildFromDraft(_randomTask(random), draft);

      expect(
        () => task.skills.add(SkillId(randomHostileText(random))),
        throwsUnsupportedError,
      );
      expect(task.skills, orderedEquals(skillsBefore));
      expect(draft.skills, orderedEquals(skillsBefore));
    }
  });

  test('test_task_to_draft_property_keeps_every_draft_field', () {
    final Random random = seededRandom(703451);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = _randomTask(random);

      final TaskDraft draft = task.toDraft();

      expect(_readDraftFields(draft), hasLength(_draftFieldCount));
      expect(_readDraftFields(draft), _readDraftPartOfTask(task));
    }
  });

  test('test_task_to_draft_property_round_trips_through_from_draft', () {
    final Random random = seededRandom(703461);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskDraft draft = randomTaskDraft(random);
      final Task task = _rebuildFromDraft(_randomTask(random), draft);

      final TaskDraft reread = task.toDraft();

      expect(_readDraftFields(reread), _readDraftFields(draft));
    }
  });

  test('test_task_to_draft_property_is_repeatable_and_frozen', () {
    final Random random = seededRandom(703471);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = _randomTask(random);
      final ModelFieldValues taskFieldsBefore = _readTaskFields(task);
      final TaskDraft first = task.toDraft();

      final TaskDraft second = task.toDraft();

      expect(_readDraftFields(second), _readDraftFields(first));
      expect(
        () => first.skills.add(SkillId(randomHostileText(random))),
        throwsUnsupportedError,
      );
      expect(_readTaskFields(task), taskFieldsBefore);
    }
  });

  testModelCopyProperties(
    ModelCopy<Task, TaskStatus>(
      testNamePrefix: 'test_task_with_status_property',
      seed: 703481,
      randomModel: _randomTask,
      randomChange: (Random random) => pickOne(random, TaskStatus.values),
      applyChange: (Task task, TaskStatus status) => task.withStatus(status),
      readChangedField: (Task task) => task.status,
      readOtherFields: _readTaskFieldsBesidesStatus,
    ),
  );
}
