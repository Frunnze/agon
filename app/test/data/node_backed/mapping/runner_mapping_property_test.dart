import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../bridge/support/random_typed_values.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/domain_model_properties.dart';

const int _largestSlotCount = 1 << 32;

RunnerTarget _randomRunnerTarget(Random random) {
  return pickOne<RunnerTarget>(random, <RunnerTarget>[
    const AnyFreeRunner(),
    SpecificRunner(randomDeviceId(random)),
    RunnerWithLabels(randomHostileTexts(random)),
  ]);
}

List<String> _randomLabelsWithRepeats(Random random) {
  final List<String> labels = randomHostileTexts(random);
  return <String>[...labels, ...labels];
}

node.Runner _randomHostileNodeRunner(Random random) {
  return node.Runner(
    deviceId: randomDeviceId(random),
    labels: _randomLabelsWithRepeats(random),
    slotsTotal: random.nextInt(_largestSlotCount),
    slotsBusy: random.nextInt(_largestSlotCount),
    link: pickOne(random, node.RunnerLink.values),
    online: random.nextBool(),
    acceptingNewRuns: random.nextBool(),
    offers: <node.AgentPlace>[
      for (final node.AgentPlace place in node.AgentPlace.values)
        if (random.nextBool()) place,
    ],
    allowedHosts: randomHostileTexts(random),
  );
}

void main() {
  testNodeEnumMappingProperties(
    const NodeEnumMapping<RunnerLink, node.RunnerLink>(
      testNamePrefix: 'test_map_runner_link_from_node_property',
      choices: RunnerLink.values,
      nodeChoices: node.RunnerLink.values,
      mapFromNode: mapRunnerLinkFromNode,
    ),
  );

  test('test_map_runner_target_from_node_property_keeps_kind_and_payload', () {
    final Random random = seededRandom(73401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunnerTarget wire = pickOne<node.RunnerTarget>(
        random,
        <node.RunnerTarget>[
          const node.AnyFreeRunner(),
          node.SpecificRunner(deviceId: randomDeviceId(random)),
          node.RunnerWithLabels(labels: _randomLabelsWithRepeats(random)),
        ],
      );

      final RunnerTarget target = mapRunnerTargetFromNode(wire);

      switch (wire) {
        case node.AnyFreeRunner():
          expect(target, isA<AnyFreeRunner>());
        case node.SpecificRunner(:final DeviceId deviceId):
          expect(target, SpecificRunner(deviceId));
        case node.RunnerWithLabels(:final List<String> labels):
          expect(target, RunnerWithLabels(labels));
      }
    }
  });

  test('test_map_runner_target_from_node_property_labels_are_frozen', () {
    final Random random = seededRandom(73402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = mapRunnerTargetFromNode(
        node.RunnerWithLabels(labels: randomHostileTexts(random)),
      );

      expect(target, isA<RunnerWithLabels>());
      final RunnerWithLabels labelled = target as RunnerWithLabels;
      expect(
        () => labelled.labels.add(randomText(random)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_map_runner_target_to_node_property_round_trips_the_model', () {
    final Random random = seededRandom(73403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = _randomRunnerTarget(random);

      final node.RunnerTarget wire = mapRunnerTargetToNode(target);

      expect(mapRunnerTargetFromNode(wire), target);
    }
  });

  test('test_map_runner_target_to_node_property_survives_node_json', () {
    final Random random = seededRandom(73404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget target = _randomRunnerTarget(random);
      final node.RunnerTarget wire = mapRunnerTargetToNode(target);

      final node.RunnerTarget reread = node.RunnerTarget.fromJson(
        wire.toJson(),
      );

      expect(reread.toJson(), wire.toJson());
      expect(mapRunnerTargetFromNode(reread), target);
    }
  });

  test('test_map_runner_from_node_property_keeps_hostile_fields', () {
    final Random random = seededRandom(73405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Runner wire = _randomHostileNodeRunner(random);

      final Runner runner = mapRunnerFromNode(wire);

      expect(runner.deviceId, wire.deviceId);
      expect(runner.labels, wire.labels);
      expect(runner.slotsTotal, wire.slotsTotal);
      expect(runner.slotsBusy, wire.slotsBusy);
      expect(runner.link.name, wire.link.name);
      expect(runner.online, wire.online);
      expect(runner.acceptingNewRuns, wire.acceptingNewRuns);
      expect(
        <String>[for (final AgentPlace offer in runner.offers) offer.name],
        <String>[for (final node.AgentPlace offer in wire.offers) offer.name],
      );
      expect(runner.allowedHosts, wire.allowedHosts);
    }
  });

  test('test_map_runner_from_node_property_lists_are_frozen', () {
    final Random random = seededRandom(73406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = mapRunnerFromNode(
        node.Runner.fromJson(randomRunnerJson(random)),
      );

      expect(
        () => runner.labels.add(randomText(random)),
        throwsUnsupportedError,
      );
      expect(
        () => runner.offers.add(pickOne(random, AgentPlace.values)),
        throwsUnsupportedError,
      );
      expect(
        () => runner.allowedHosts.add(randomText(random)),
        throwsUnsupportedError,
      );
    }
  });
}
