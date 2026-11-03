import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/device_values.dart' as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/arbitrary_json.dart';
import '../../bridge/support/decoding_outcome.dart';
import '../../bridge/support/random_catalog_json.dart';
import '../../support/random_inputs.dart';

void main() {
  test('test_map_runner_target_to_node_property_round_trips', () {
    final Random random = seededRandom(9301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunnerTarget wire = node.RunnerTarget.fromJson(
        randomRunnerTargetJson(random),
      );
      final RunnerTarget target = mapRunnerTargetFromNode(wire);
      expect(mapRunnerTargetToNode(target).toJson(), wire.toJson());
    }
  });

  test('test_map_runner_target_from_node_property_keeps_equality', () {
    final Random random = seededRandom(9302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Map<String, Object?> json = randomRunnerTargetJson(random);
      final RunnerTarget first = mapRunnerTargetFromNode(
        node.RunnerTarget.fromJson(json),
      );
      final RunnerTarget second = mapRunnerTargetFromNode(
        node.RunnerTarget.fromJson(json),
      );
      expect(first, second);
    }
  });

  test('test_map_runner_link_from_node_property_keeps_name', () {
    for (final node.RunnerLink wire in node.RunnerLink.values) {
      expect(mapRunnerLinkFromNode(wire).name, wire.name);
    }
  });

  test('test_map_runner_from_node_property_keeps_every_field', () {
    final Random random = seededRandom(9303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.Runner wire = node.RunnerView.fromJson(
        randomRunnerViewJson(random),
      ).runner;
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

  test('test_map_runner_from_node_property_malformed_json_only_format', () {
    final Random random = seededRandom(9304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? mutated = mutateJson(random, randomRunnerJson(random));
      expect(
        attemptDecoding(
          () => mapRunnerFromNode(node.Runner.fromJson(mutated)),
        ),
        isIn(DecodingOutcome.values),
      );
    }
  });
}
