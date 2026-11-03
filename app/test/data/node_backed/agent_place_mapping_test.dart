import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../support/random_inputs.dart';

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return randomText(random);
}

void main() {
  test('test_map_agent_place_from_node_property_keeps_the_place', () {
    final Random random = seededRandom(10101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AgentPlace wire = pickOne(random, node.AgentPlace.values);

      final AgentPlace place = mapAgentPlaceFromNode(wire);

      expect(mapAgentPlaceToNode(place), wire);
      expect(place.name, wire.name);
    }
  });

  test('test_map_agent_place_to_node_property_round_trips', () {
    final Random random = seededRandom(10102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final node.AgentPlace wire = mapAgentPlaceToNode(place);
      final node.AgentPlace decoded = node.AgentPlace.decode(wire.wireName);

      expect(decoded, wire);
      expect(mapAgentPlaceFromNode(decoded), place);
    }
  });

  test(
    'test_map_place_offers_from_node_property_keeps_order_and_problems',
    () {
      final Random random = seededRandom(10103);
      for (int i = 0; i < propertyIterations; i += 1) {
        final List<node.PlaceOffer> wire = <node.PlaceOffer>[
          for (int index = 0; index < random.nextInt(4); index += 1)
            node.PlaceOffer(
              place: pickOne(random, node.AgentPlace.values),
              problem: _randomProblem(random),
            ),
        ];

        final List<PlaceOffer> offers = mapPlaceOffersFromNode(wire);

        expect(offers.length, wire.length);
        for (int index = 0; index < wire.length; index += 1) {
          expect(offers[index].place.name, wire[index].place.name);
          expect(offers[index].problem, wire[index].problem);
        }
      }
    },
  );
}
