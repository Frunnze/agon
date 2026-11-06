import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../support/random_file_json.dart';
import '../support/random_repository_file_values.dart';
import '../support/wire_contract_checks.dart';

const WireFields _fileRunnerFields = WireFields(
  requiredFields: <String>['device_id', 'name'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields _repositoryHolderFields = WireFields(
  requiredFields: <String>['device_id', 'name', 'last_seen'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

void main() {
  test('test_file_runner_from_json_property_round_trips_node_json', () {
    final Random random = seededRandom(52401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomFileRunnerJson(random);

      final FileRunner runner = FileRunner.fromJson(json);

      expect(reencodeThroughText(runner), equals(json));
    }
  });

  test('test_file_runner_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(52402);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRequiredFieldsAreNeeded(
        randomFileRunnerJson(random),
        _fileRunnerFields,
        FileRunner.fromJson,
      );
    }
  });

  test('test_file_runner_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(52403);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomFileRunnerJson(random),
        FileRunner.fromJson,
      );
    }
  });

  test('test_file_runner_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(52404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomFileRunnerJson(random);

      final FileRunner runner = FileRunner.fromJson(
        withUnknownFields(random, json),
      );

      expect(runner.deviceId, DeviceId(json['device_id']!.toString()));
      expect(runner.name, json['name']);
    }
  });

  test('test_file_runner_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = randomFileRunner(random).toJson();

      expect(encoded.keys.toSet(), equals(_fileRunnerFields.everyField));
    }
  });

  test('test_file_runner_to_json_property_values_mirror_the_runner', () {
    final Random random = seededRandom(52406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FileRunner runner = randomFileRunner(random);

      final JsonObject encoded = runner.toJson();

      expect(encoded['device_id'], runner.deviceId.value);
      expect(encoded['name'], runner.name);
    }
  });

  test('test_file_runner_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52407);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        randomFileRunner(random),
        FileRunner.fromJson,
      );
    }
  });

  test(
    'test_repository_holder_from_json_property_missing_fields_follow_node',
    () {
      final Random random = seededRandom(52408);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectRequiredFieldsAreNeeded(
          randomRepositoryHolderJson(random),
          _repositoryHolderFields,
          RepositoryHolder.fromJson,
        );
      }
    },
  );

  test(
    'test_repository_holder_from_json_property_wrong_kinds_raise_format',
    () {
      final Random random = seededRandom(52409);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectWrongKindValuesAreRejected(
          random,
          randomRepositoryHolderJson(random),
          RepositoryHolder.fromJson,
        );
      }
    },
  );

  test(
    'test_repository_holder_from_json_property_reads_each_field_by_name',
    () {
      final Random random = seededRandom(52410);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomRepositoryHolderJson(random);

        final RepositoryHolder holder = RepositoryHolder.fromJson(
          withUnknownFields(random, json),
        );

        expect(holder.deviceId, DeviceId(json['device_id']!.toString()));
        expect(holder.name, json['name']);
        expectSameMoment(holder.lastSeen, json['last_seen']);
      }
    },
  );

  test(
    'test_repository_holder_to_json_property_writes_exactly_node_fields',
    () {
      final Random random = seededRandom(52411);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject encoded = randomRepositoryHolder(random).toJson();

        expect(
          encoded.keys.toSet(),
          equals(_repositoryHolderFields.everyField),
        );
      }
    },
  );

  test('test_repository_holder_to_json_property_last_seen_is_utc', () {
    final Random random = seededRandom(52412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryHolder holder = randomRepositoryHolder(random);

      final JsonObject encoded = holder.toJson();

      expect(encoded['device_id'], holder.deviceId.value);
      expect(encoded['name'], holder.name);
      expectUtcMomentText(encoded['last_seen'], holder.lastSeen);
    }
  });

  test('test_repository_holder_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52413);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        randomRepositoryHolder(random),
        RepositoryHolder.fromJson,
      );
    }
  });
}
