import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/task_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import '../support/node_json_primitives.dart';
import '../support/random_work_json.dart';
import '../support/utc_offset_moments.dart';
import '../support/wire_codec_properties.dart';
import '../support/wire_json_edits.dart';

const WireCodec _taskCodec = WireCodec(
  typeName: 'task',
  seed: 53300,
  buildJson: randomTaskJson,
  decode: Task.fromJson,
  requiredFields: <String>{
    'id',
    'title',
    'details',
    'project_id',
    'doer',
    'runs_on',
    'agent_place',
    'skills',
    'uses_automatic_skills',
    'status',
    'created_at',
  },
  optionalFields: <String>{'approval_policy', 'schedule'},
);

SkillId _buildSkillId(Random random) => SkillId(randomUuidText(random));

Task _rebuildTask(
  Task template, {
  required List<SkillId> skills,
  required String title,
  required String details,
  required DateTime createdAt,
}) {
  return Task(
    id: template.id,
    title: title,
    details: details,
    projectId: template.projectId,
    doer: template.doer,
    runsOn: template.runsOn,
    agentPlace: template.agentPlace,
    skills: skills,
    usesAutomaticSkills: template.usesAutomaticSkills,
    approvalPolicy: template.approvalPolicy,
    schedule: template.schedule,
    status: template.status,
    createdAt: createdAt,
  );
}

Task _buildTaskWithSkills(Random random, List<SkillId> skills) {
  final Task template = Task.fromJson(randomTaskJson(random));
  return _rebuildTask(
    template,
    skills: skills,
    title: template.title,
    details: template.details,
    createdAt: template.createdAt,
  );
}

List<SkillId> _readSkills(Task task) => task.skills;

void main() {
  testWireDecodingProperties(_taskCodec);
  testWireEncodingProperties(_taskCodec);

  testListCopyProperties(
    const ListCopy<Task, SkillId>(
      testNamePrefix: 'test_task_constructor_property_skills',
      seed: 53310,
      buildElement: _buildSkillId,
      construct: _buildTaskWithSkills,
      readList: _readSkills,
    ),
  );

  test('test_task_to_json_property_writes_created_at_as_utc_text', () {
    final Random random = seededRandom(53320);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task template = Task.fromJson(randomTaskJson(random));
      final DateTime createdAt = randomMicrosecondMoment(random);
      final Task task = _rebuildTask(
        template,
        skills: template.skills,
        title: template.title,
        details: template.details,
        createdAt: createdAt,
      );

      expectUtcMomentText(task.toJson()['created_at'], createdAt);
    }
  });

  test('test_task_to_json_property_keeps_hostile_texts_and_skill_order', () {
    final Random random = seededRandom(53321);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task template = Task.fromJson(randomTaskJson(random));
      final List<SkillId> skills = <SkillId>[
        _buildSkillId(random),
        _buildSkillId(random),
      ];
      skills.add(skills.first);
      final Task task = _rebuildTask(
        template,
        skills: skills,
        title: randomHostileText(random),
        details: randomHostileText(random),
        createdAt: template.createdAt,
      );

      final Task decodedAgain = Task.fromJson(reencodeAsJsonText(task));

      expect(decodedAgain.title, task.title);
      expect(decodedAgain.details, task.details);
      expect(decodedAgain.skills, orderedEquals(skills));
    }
  });

  test('test_task_from_json_property_'
      'reads_offset_created_at_as_the_same_utc_instant', () {
    final Random random = seededRandom(53322);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime createdAt = randomMicrosecondMoment(random).toUtc();
      final JsonObject wireJson = replaceWireField(
        randomTaskJson(random),
        'created_at',
        writeMomentAtRandomOffset(random, createdAt),
      );

      final Task task = Task.fromJson(wireJson);

      expect(task.createdAt.isUtc, isTrue);
      expect(task.createdAt, equals(createdAt));
    }
  });

  test('test_task_from_json_property_rejects_moments_without_a_zone', () {
    final Random random = seededRandom(53323);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime createdAt = randomMicrosecondMoment(random).toUtc();
      final String utcText = createdAt.toIso8601String();
      final String zonelessText = utcText.substring(0, utcText.length - 1);
      final JsonObject wireJson = replaceWireField(
        randomTaskJson(random),
        'created_at',
        zonelessText,
      );

      expect(() => Task.fromJson(wireJson), throwsFormatException);
    }
  });
}
