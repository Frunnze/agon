import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_progress_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/random_run_json.dart';
import '../support/random_typed_values.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';

const WireFields _currentStepFields = WireFields(
  requiredFields: <String>['number', 'name', 'status'],
  optionalFields: <String>['runner'],
  defaultedListFields: <String>[],
);

const WireFields _runProgressFields = WireFields(
  requiredFields: <String>[
    'run_id',
    'number',
    'status',
    'link',
    'started_at',
    'step_count',
  ],
  optionalFields: <String>['finished_at', 'current_step'],
  defaultedListFields: <String>[],
);

CurrentStep _randomCurrentStep(Random random) {
  return CurrentStep(
    number: randomWholeNumber(random),
    name: randomText(random),
    runner: random.nextBool() ? null : randomDeviceId(random),
    status: pickOne(random, StepStatus.values),
  );
}

RunProgress _randomLocalRunProgress(Random random) {
  return RunProgress(
    runId: randomRunId(random),
    number: randomWholeNumber(random),
    status: pickOne(random, RunStatus.values),
    link: pickOne(random, RunnerLink.values),
    startedAt: randomLocalMoment(random),
    finishedAt: randomOptionalLocalMoment(random),
    stepCount: randomWholeNumber(random),
    currentStep: random.nextBool() ? null : _randomCurrentStep(random),
  );
}

void main() {
  test('test_current_step_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(53001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomCurrentStepJson(random);

      expectRequiredFieldsAreNeeded(
        json,
        _currentStepFields,
        CurrentStep.fromJson,
      );
      expectOptionalFieldsMayBeLeftOut(
        random,
        json,
        _currentStepFields,
        CurrentStep.fromJson,
      );
    }
  });

  test('test_current_step_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(53002);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomCurrentStepJson(random),
        CurrentStep.fromJson,
      );
    }
  });

  test('test_current_step_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(53003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomCurrentStepJson(random);

      final CurrentStep step = CurrentStep.fromJson(
        withUnknownFields(random, json),
      );

      expect(step.number, json['number']);
      expect(step.name, json['name']);
      expect(step.runner?.value, json['runner']);
      expect(step.status.wireName, json['status']);
    }
  });

  test('test_current_step_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomCurrentStep(random).toJson();

      expect(encoded.keys.toSet(), equals(_currentStepFields.everyField));
    }
  });

  test('test_current_step_to_json_property_values_mirror_the_step', () {
    final Random random = seededRandom(53005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CurrentStep step = _randomCurrentStep(random);

      final JsonObject encoded = step.toJson();

      expect(encoded['number'], step.number);
      expect(encoded['name'], step.name);
      expect(encoded['runner'], step.runner?.value);
      expect(encoded['status'], step.status.wireName);
    }
  });

  test('test_current_step_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(53006);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomCurrentStep(random),
        CurrentStep.fromJson,
      );
    }
  });

  test('test_run_progress_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(53007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunProgressJson(random);

      expectRequiredFieldsAreNeeded(
        json,
        _runProgressFields,
        RunProgress.fromJson,
      );
      expectOptionalFieldsMayBeLeftOut(
        random,
        json,
        _runProgressFields,
        RunProgress.fromJson,
      );
    }
  });

  test('test_run_progress_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(53008);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomRunProgressJson(random),
        RunProgress.fromJson,
      );
    }
  });

  test('test_run_progress_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(53009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunProgressJson(random);

      final RunProgress progress = RunProgress.fromJson(
        withUnknownFields(random, json),
      );

      expect(progress.runId, RunId(json['run_id']!.toString()));
      expect(progress.number, json['number']);
      expect(progress.status.wireName, json['status']);
      expect(progress.link.wireName, json['link']);
      expectSameMoment(progress.startedAt, json['started_at']);
      expectSameMoment(progress.finishedAt, json['finished_at']);
      expect(progress.stepCount, json['step_count']);
      expect(progress.currentStep?.toJson(), equals(json['current_step']));
    }
  });

  test('test_run_progress_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53010);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomLocalRunProgress(random).toJson();

      expect(encoded.keys.toSet(), equals(_runProgressFields.everyField));
    }
  });

  test('test_run_progress_to_json_property_values_mirror_progress_in_utc', () {
    final Random random = seededRandom(53011);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunProgress progress = _randomLocalRunProgress(random);

      final JsonObject encoded = progress.toJson();

      expect(encoded['run_id'], progress.runId.value);
      expect(encoded['number'], progress.number);
      expect(encoded['status'], progress.status.wireName);
      expect(encoded['link'], progress.link.wireName);
      expectUtcMomentText(encoded['started_at'], progress.startedAt);
      expectOptionalUtcMomentText(encoded['finished_at'], progress.finishedAt);
      expect(encoded['step_count'], progress.stepCount);
      expect(encoded['current_step'], equals(progress.currentStep?.toJson()));
    }
  });

  test('test_run_progress_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(53012);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomLocalRunProgress(random),
        RunProgress.fromJson,
      );
    }
  });
}
