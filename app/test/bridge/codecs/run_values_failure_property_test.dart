import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_run_json.dart';
import '../support/random_typed_values.dart';
import '../support/wire_contract_checks.dart';

const WireFields _runFailureFields = WireFields(
  requiredFields: <String>['step_name', 'reason', 'retry_runs_on_same_runner'],
  optionalFields: <String>['runner'],
  defaultedListFields: <String>[],
);

RunFailure _randomRunFailure(Random random) {
  return RunFailure(
    stepName: randomText(random),
    runner: random.nextBool() ? null : randomDeviceId(random),
    reason: randomText(random),
    retryRunsOnSameRunner: random.nextBool(),
  );
}

void main() {
  test('test_run_failure_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(53114);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunFailureJson(random);

      expectRequiredFieldsAreNeeded(
        json,
        _runFailureFields,
        RunFailure.fromJson,
      );
      expectOptionalFieldsMayBeLeftOut(
        random,
        json,
        _runFailureFields,
        RunFailure.fromJson,
      );
    }
  });

  test('test_run_failure_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(53115);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomRunFailureJson(random),
        RunFailure.fromJson,
      );
    }
  });

  test('test_run_failure_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(53116);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunFailureJson(random);

      final RunFailure failure = RunFailure.fromJson(
        withUnknownFields(random, json),
      );

      expect(failure.stepName, json['step_name']);
      expect(failure.runner?.value, json['runner']);
      expect(failure.reason, json['reason']);
      expect(failure.retryRunsOnSameRunner, json['retry_runs_on_same_runner']);
    }
  });

  test('test_run_failure_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(53117);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomRunFailure(random).toJson();

      expect(encoded.keys.toSet(), equals(_runFailureFields.everyField));
    }
  });

  test('test_run_failure_to_json_property_values_mirror_the_failure', () {
    final Random random = seededRandom(53118);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunFailure failure = _randomRunFailure(random);

      final JsonObject encoded = failure.toJson();

      expect(encoded['step_name'], failure.stepName);
      expect(encoded['runner'], failure.runner?.value);
      expect(encoded['reason'], failure.reason);
      expect(
        encoded['retry_runs_on_same_runner'],
        failure.retryRunsOnSameRunner,
      );
    }
  });

  test('test_run_failure_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(53119);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomRunFailure(random),
        RunFailure.fromJson,
      );
    }
  });
}
