import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/list_copy_properties.dart';
import '../../bridge/support/random_typed_values.dart';
import '../../support/random_inputs.dart';
import 'support/domain_model_properties.dart';
import 'support/value_equality_properties.dart';

const List<String> _fewLabels = <String>['gpu', 'mac', ''];
const List<String?> _fewProblems = <String?>[null, '', 'Docker is off'];
const List<DeviceId> _fewDeviceIds = <DeviceId>[
  DeviceId('gpu'),
  DeviceId('mac'),
  DeviceId(''),
];
const int _largestFewLabelCount = 3;

List<String> _randomFewLabels(Random random) {
  final List<String> labels = <String>[];
  final int count = random.nextInt(_largestFewLabelCount);
  for (int i = 0; i < count; i += 1) {
    labels.add(pickOne(random, _fewLabels));
  }
  return labels;
}

RunnerTarget _roundTripThroughNode(RunnerTarget target) {
  return mapRunnerTargetFromNode(mapRunnerTargetToNode(target));
}

void main() {
  testModelConstructorProperties(
    ModelConstructor<PlaceOffer>(
      testNamePrefix: 'test_place_offer_constructor_property',
      seed: 692101,
      randomFieldValues: (Random random) => <Object?>[
        pickOne(random, AgentPlace.values),
        if (random.nextBool()) null else randomHostileText(random),
      ],
      construct: (ModelFieldValues fieldValues) => PlaceOffer(
        place: fieldValues[0]! as AgentPlace,
        problem: fieldValues[1] as String?,
      ),
      readFieldValues: (PlaceOffer offer) => <Object?>[
        offer.place,
        offer.problem,
      ],
    ),
  );

  testValueEqualityProperties(
    ValueEquality<PlaceOffer>(
      typeName: 'place_offer',
      seed: 692111,
      randomValue: (Random random) => PlaceOffer(
        place: pickOne(random, AgentPlace.values),
        problem: pickOne(random, _fewProblems),
      ),
      copyValue: (PlaceOffer offer) =>
          PlaceOffer(place: offer.place, problem: offer.problem),
      haveSameFields: (PlaceOffer first, PlaceOffer second) =>
          first.place == second.place && first.problem == second.problem,
      otherKinds: <Object>[const AnyFreeRunner(), AgentPlace.container],
    ),
  );

  test('test_any_free_runner_constructor_property_is_one_value', () {
    const RunnerTarget constant = AnyFreeRunner();

    expect(constant, isA<AnyFreeRunner>());
    expect(constant == const AnyFreeRunner(), isTrue);
    expect(identical(constant, const AnyFreeRunner()), isTrue);
  });

  test('test_any_free_runner_constructor_property_round_trips_the_node', () {
    const RunnerTarget target = AnyFreeRunner();

    final node.RunnerTarget nodeTarget = mapRunnerTargetToNode(target);

    expect(nodeTarget, isA<node.AnyFreeRunner>());
    expect(_roundTripThroughNode(target), target);
  });

  test('test_any_free_runner_constructor_property_names_no_runner', () {
    const RunnerTarget target = AnyFreeRunner();

    expect(target, isNot(isA<SpecificRunner>()));
    expect(target, isNot(isA<RunnerWithLabels>()));
  });

  testValueEqualityProperties(
    ValueEquality<AnyFreeRunner>(
      typeName: 'any_free_runner',
      seed: 692121,
      randomValue: (Random random) => const AnyFreeRunner(),
      copyValue: (AnyFreeRunner target) => const AnyFreeRunner(),
      haveSameFields: (AnyFreeRunner first, AnyFreeRunner second) => true,
      otherKinds: <Object>[
        RunnerWithLabels(const <String>[]),
        const SpecificRunner(DeviceId('')),
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<SpecificRunner>(
      testNamePrefix: 'test_specific_runner_constructor_property',
      seed: 692131,
      randomFieldValues: (Random random) => <Object?>[randomDeviceId(random)],
      construct: (ModelFieldValues fieldValues) =>
          SpecificRunner(fieldValues[0]! as DeviceId),
      readFieldValues: (SpecificRunner target) => <Object?>[target.deviceId],
    ),
  );

  test('test_specific_runner_constructor_property_round_trips_the_node', () {
    final Random random = seededRandom(692141);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SpecificRunner target = SpecificRunner(randomDeviceId(random));

      expect(_roundTripThroughNode(target), target);
    }
  });

  testValueEqualityProperties(
    ValueEquality<SpecificRunner>(
      typeName: 'specific_runner',
      seed: 692151,
      randomValue: (Random random) =>
          SpecificRunner(pickOne(random, _fewDeviceIds)),
      copyValue: (SpecificRunner target) => SpecificRunner(target.deviceId),
      haveSameFields: (SpecificRunner first, SpecificRunner second) =>
          first.deviceId == second.deviceId,
      otherKinds: <Object>[
        const AnyFreeRunner(),
        RunnerWithLabels(const <String>['gpu']),
        const DeviceId('gpu'),
      ],
    ),
  );

  testModelConstructorProperties(
    ModelConstructor<RunnerWithLabels>(
      testNamePrefix: 'test_runner_with_labels_constructor_property',
      seed: 692161,
      randomFieldValues: (Random random) => <Object?>[
        randomHostileTexts(random),
      ],
      construct: (ModelFieldValues fieldValues) =>
          RunnerWithLabels(fieldValues[0]! as List<String>),
      readFieldValues: (RunnerWithLabels target) => <Object?>[target.labels],
    ),
  );

  testListCopyProperties(
    ListCopy<RunnerWithLabels, String>(
      testNamePrefix: 'test_runner_with_labels_constructor_property_labels',
      seed: 692171,
      buildElement: randomHostileText,
      construct: (Random random, List<String> labels) =>
          RunnerWithLabels(labels),
      readList: (RunnerWithLabels target) => target.labels,
    ),
  );

  testValueEqualityProperties(
    ValueEquality<RunnerWithLabels>(
      typeName: 'runner_with_labels',
      seed: 692181,
      randomValue: (Random random) =>
          RunnerWithLabels(_randomFewLabels(random)),
      copyValue: (RunnerWithLabels target) =>
          RunnerWithLabels(List<String>.of(target.labels)),
      haveSameFields: (RunnerWithLabels first, RunnerWithLabels second) =>
          _haveSameLabelsInOrder(first.labels, second.labels),
      otherKinds: <Object>[
        const AnyFreeRunner(),
        const SpecificRunner(DeviceId('gpu')),
        const <String>['gpu'],
      ],
    ),
  );
}

bool _haveSameLabelsInOrder(List<String> first, List<String> second) {
  if (first.length != second.length) {
    return false;
  }
  for (int i = 0; i < first.length; i += 1) {
    if (first[i] != second[i]) {
      return false;
    }
  }
  return true;
}
