import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/hostile_texts.dart';
import '../support/random_catalog_json.dart';
import '../support/random_typed_values.dart';
import '../support/wire_contract_checks.dart';

const String _anyFreeRunnerKind = 'any_free_runner';
const String _specificRunnerKind = 'specific_runner';
const String _runnerWithLabelsKind = 'runner_with_labels';
const Set<String> _nodeTargetKinds = <String>{
  _anyFreeRunnerKind,
  _specificRunnerKind,
  _runnerWithLabelsKind,
};

Object? _decodeJsonText(JsonObject json) => jsonDecode(jsonEncode(json));

String _randomUnknownKind(Random random) {
  final String knownKind = pickOne(random, _nodeTargetKinds.toList());
  return pickOne(random, <String>[
    knownKind.toUpperCase(),
    ' $knownKind',
    '${knownKind}s',
    'anyFreeRunner',
    randomHostileText(random),
  ]);
}

void main() {
  test('test_runner_target_from_json_property_kind_picks_the_variant', () {
    final Random random = seededRandom(50501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomRunnerTargetJson(random);

      final RunnerTarget target = RunnerTarget.fromJson(json);

      switch (json['kind']) {
        case _anyFreeRunnerKind:
          expect(target, isA<AnyFreeRunner>());
        case _specificRunnerKind:
          expect((target as SpecificRunner).deviceId, json['device_id']);
        case _runnerWithLabelsKind:
          final List<String> labels = (target as RunnerWithLabels).labels;
          expect(labels, orderedEquals(json['labels']! as List<Object?>));
        default:
          fail('the generator made an unknown kind ${json['kind']}');
      }
    }
  });

  test('test_runner_target_from_json_property_rejects_unknown_shapes', () {
    final Random random = seededRandom(50502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String unknownKind = _randomUnknownKind(random);
      final Object? arbitraryKind = randomArbitraryJson(random);
      final JsonObject specificWithoutDevice = <String, Object?>{
        'kind': _specificRunnerKind,
        'labels': <Object?>[randomHostileText(random)],
      };
      final JsonObject labelsWithoutList = <String, Object?>{
        'kind': _runnerWithLabelsKind,
        'device_id': randomDeviceId(random).value,
      };

      expect(
        () => RunnerTarget.fromJson(<String, Object?>{'kind': unknownKind}),
        throwsFormatException,
      );
      expect(
        () => RunnerTarget.fromJson(specificWithoutDevice),
        throwsFormatException,
      );
      expect(
        () => RunnerTarget.fromJson(labelsWithoutList),
        throwsFormatException,
      );
      if (_nodeTargetKinds.contains(arbitraryKind)) {
        continue;
      }
      expect(
        () => RunnerTarget.fromJson(<String, Object?>{'kind': arbitraryKind}),
        throwsFormatException,
      );
    }
  });

  test('test_any_free_runner_to_json_property_writes_only_the_kind', () {
    const AnyFreeRunner target = AnyFreeRunner();

    expect(
      target.toJson(),
      equals(<String, Object?>{'kind': _anyFreeRunnerKind}),
    );
  });

  test('test_any_free_runner_to_json_property_decodes_back_to_itself', () {
    final Random random = seededRandom(50503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = const AnyFreeRunner().toJson();
      json['labels'] = randomHostileTexts(random);

      final RunnerTarget decoded = RunnerTarget.fromJson(
        _decodeJsonText(json),
      );

      expect(decoded, isA<AnyFreeRunner>());
    }
  });

  test(
    'test_any_free_runner_to_json_property_gives_a_fresh_map_each_time',
    () {
      final JsonObject firstJson = const AnyFreeRunner().toJson();
      firstJson['kind'] = _specificRunnerKind;

      final JsonObject secondJson = const AnyFreeRunner().toJson();

      expect(secondJson['kind'], _anyFreeRunnerKind);
    },
  );

  test('test_specific_runner_to_json_property_round_trips_the_device', () {
    final Random random = seededRandom(50504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SpecificRunner target = SpecificRunner(
        deviceId: randomDeviceId(random),
      );

      final RunnerTarget decoded = RunnerTarget.fromJson(
        _decodeJsonText(target.toJson()),
      );

      expect((decoded as SpecificRunner).deviceId, target.deviceId);
    }
  });

  test('test_specific_runner_to_json_property_writes_the_node_fields', () {
    final Random random = seededRandom(50505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SpecificRunner target = SpecificRunner(
        deviceId: randomDeviceId(random),
      );

      expect(
        target.toJson(),
        equals(<String, Object?>{
          'kind': _specificRunnerKind,
          'device_id': target.deviceId.value,
        }),
      );
    }
  });

  test('test_specific_runner_to_json_property_is_stable_across_trips', () {
    final Random random = seededRandom(50506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = <String, Object?>{
        'kind': _specificRunnerKind,
        'device_id': randomHostileText(random),
      };

      expect(RunnerTarget.fromJson(json).toJson(), equals(json));
    }
  });

  test('test_runner_with_labels_constructor_property_keeps_its_own_copy', () {
    final Random random = seededRandom(50507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = randomHostileTexts(random);

      final RunnerWithLabels target = RunnerWithLabels(labels: labels);

      expectListIgnoresCallerChanges(
        labels,
        target.labels,
        randomHostileText(random),
      );
    }
  });

  test('test_runner_with_labels_constructor_property_rejects_changes', () {
    final Random random = seededRandom(50508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerWithLabels target = RunnerWithLabels(
        labels: randomHostileTexts(random),
      );

      expectListRefusesChanges(target.labels, randomHostileText(random));
    }
  });

  test('test_runner_with_labels_constructor_property_keeps_duplicates', () {
    final Random random = seededRandom(50509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repeatedLabel = randomHostileText(random);
      final List<String> labels = <String>[
        repeatedLabel,
        ...randomHostileTexts(random),
        repeatedLabel,
      ];

      final RunnerWithLabels target = RunnerWithLabels(labels: labels);

      expect(target.labels, orderedEquals(labels));
    }
  });

  test('test_runner_with_labels_to_json_property_round_trips_labels', () {
    final Random random = seededRandom(50510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = randomHostileTexts(random);

      final RunnerTarget decoded = RunnerTarget.fromJson(
        _decodeJsonText(RunnerWithLabels(labels: labels).toJson()),
      );

      expect((decoded as RunnerWithLabels).labels, orderedEquals(labels));
    }
  });

  test('test_runner_with_labels_to_json_property_writes_the_node_fields', () {
    final Random random = seededRandom(50511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = randomHostileTexts(random);

      final JsonObject json = RunnerWithLabels(labels: labels).toJson();

      expect(json.keys.toSet(), equals(<String>{'kind', 'labels'}));
      expect(json['kind'], _runnerWithLabelsKind);
      expect(json['labels'], orderedEquals(labels));
    }
  });

  test('test_runner_with_labels_to_json_property_is_stable_across_trips', () {
    final Random random = seededRandom(50512);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = <String, Object?>{
        'kind': _runnerWithLabelsKind,
        'labels': randomHostileTexts(random),
      };

      expect(RunnerTarget.fromJson(json).toJson(), equals(json));
    }
  });
}
