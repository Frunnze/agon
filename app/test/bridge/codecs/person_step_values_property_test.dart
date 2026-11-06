import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/person_step_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/random_branching_json.dart';
import '../support/random_typed_values.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';

const WireFields _openPersonStepFields = WireFields(
  requiredFields: <String>[
    'run_id',
    'task_id',
    'workspace_id',
    'step_name',
    'question',
    'choices',
  ],
  optionalFields: <String>['asked_at'],
  defaultedListFields: <String>[],
);

OpenPersonStep _buildOpenPersonStep(Random random, List<String> choices) {
  return OpenPersonStep(
    runId: randomRunId(random),
    taskId: randomTaskId(random),
    workspaceId: randomWorkspaceId(random),
    stepName: randomText(random),
    question: randomText(random),
    choices: choices,
    askedAt: random.nextBool() ? null : randomLocalMoment(random),
  );
}

void main() {
  test('test_open_person_step_property_keeps_choices_in_order', () {
    final Random random = seededRandom(52201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> choices = randomTextList(random);

      final OpenPersonStep step = _buildOpenPersonStep(random, choices);

      expect(step.choices, orderedEquals(choices));
    }
  });

  test('test_open_person_step_property_ignores_later_caller_changes', () {
    final Random random = seededRandom(52202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> choices = randomTextList(random);

      final OpenPersonStep step = _buildOpenPersonStep(random, choices);

      expectListIgnoresCallerChanges(choices, step.choices, 'choice');
    }
  });

  test('test_open_person_step_property_choices_refuse_changes', () {
    final Random random = seededRandom(52203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final OpenPersonStep step = _buildOpenPersonStep(
        random,
        randomTextList(random),
      );

      expectListRefusesChanges(step.choices, 'choice');
    }
  });

  test(
    'test_open_person_step_from_json_property_missing_fields_follow_node',
    () {
      final Random random = seededRandom(52204);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomOpenPersonStepJson(random);

        expectRequiredFieldsAreNeeded(
          json,
          _openPersonStepFields,
          OpenPersonStep.fromJson,
        );
        expectOptionalFieldsMayBeLeftOut(
          random,
          json,
          _openPersonStepFields,
          OpenPersonStep.fromJson,
        );
      }
    },
  );

  test(
    'test_open_person_step_from_json_property_wrong_kinds_raise_format',
    () {
      final Random random = seededRandom(52205);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectWrongKindValuesAreRejected(
          random,
          randomOpenPersonStepJson(random),
          OpenPersonStep.fromJson,
        );
      }
    },
  );

  test(
    'test_open_person_step_from_json_property_reads_each_field_by_name',
    () {
      final Random random = seededRandom(52206);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomOpenPersonStepJson(random);

        final OpenPersonStep step = OpenPersonStep.fromJson(
          withUnknownFields(random, json),
        );

        expect(step.runId, RunId(json['run_id']!.toString()));
        expect(step.taskId, TaskId(json['task_id']!.toString()));
        expect(
          step.workspaceId,
          WorkspaceId(json['workspace_id']!.toString()),
        );
        expect(step.stepName, json['step_name']);
        expect(step.question, json['question']);
        expect(step.choices, orderedEquals(json['choices']! as List<Object?>));
        expectSameMoment(step.askedAt, json['asked_at']);
      }
    },
  );

  test(
    'test_open_person_step_to_json_property_writes_exactly_node_fields',
    () {
      final Random random = seededRandom(52207);

      for (int i = 0; i < propertyIterations; i += 1) {
        final OpenPersonStep step = _buildOpenPersonStep(
          random,
          randomTextList(random),
        );

        final Set<String> fields = step.toJson().keys.toSet();

        expect(fields, equals(_openPersonStepFields.everyField));
      }
    },
  );

  test('test_open_person_step_to_json_property_values_mirror_the_step', () {
    final Random random = seededRandom(52208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final OpenPersonStep step = _buildOpenPersonStep(
        random,
        randomTextList(random),
      );

      final JsonObject encoded = step.toJson();

      expect(encoded['run_id'], step.runId.value);
      expect(encoded['task_id'], step.taskId.value);
      expect(encoded['workspace_id'], step.workspaceId.value);
      expect(encoded['step_name'], step.stepName);
      expect(encoded['question'], step.question);
      expect(encoded['choices'], orderedEquals(step.choices));
      expectOptionalUtcMomentText(encoded['asked_at'], step.askedAt);
    }
  });

  test('test_open_person_step_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final OpenPersonStep step = _buildOpenPersonStep(
        random,
        randomTextList(random),
      );

      expectPlainJsonThatDecodesBack(step, OpenPersonStep.fromJson);
    }
  });
}
