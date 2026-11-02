import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/random_account_json.dart';
import '../../support/random_inputs.dart';

void main() {
  test('test_map_agent_place_from_node_property_follows_the_sandbox', () {
    final Random random = seededRandom(10101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.RunnerSettings wire = node.RunnerSettings.fromJson(
        randomRunnerSettingsJson(random),
      );

      final AgentPlace place = mapAgentPlaceFromNode(wire.sandbox);

      final bool isContainer = wire.sandbox is node.ContainerSandbox;
      expect(place == AgentPlace.container, isContainer);
    }
  });

  test('test_map_agent_place_to_node_property_round_trips', () {
    final Random random = seededRandom(10102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final node.AgentPlace wire = mapAgentPlaceToNode(place);
      final node.AgentPlace decoded = node.AgentPlace.decode(wire.wireName);

      expect(decoded, wire);
      expect(wire.name, place.name);
    }
  });
}
