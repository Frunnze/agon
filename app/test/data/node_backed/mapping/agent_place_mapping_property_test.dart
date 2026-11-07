import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/node_wire_names.dart';
import '../../../bridge/support/random_catalog_json.dart';
import '../../../support/random_inputs.dart';
import '../support/node_enum_mapping_properties.dart';

const int _largestListLength = 7;

List<node.AgentPlace> _randomNodePlaces(Random random) {
  final int count = random.nextInt(_largestListLength);
  return <node.AgentPlace>[
    for (int i = 0; i < count; i += 1) pickOne(random, node.AgentPlace.values),
  ];
}

node.PlaceOffer _randomNodeOffer(Random random) {
  if (random.nextBool()) {
    return node.PlaceOffer.fromJson(randomPlaceOfferJson(random));
  }
  return node.PlaceOffer(
    place: pickOne(random, node.AgentPlace.values),
    problem: random.nextBool() ? null : randomHostileText(random),
  );
}

List<node.PlaceOffer> _randomNodeOffers(Random random) {
  final int count = random.nextInt(_largestListLength);
  return <node.PlaceOffer>[
    for (int i = 0; i < count; i += 1) _randomNodeOffer(random),
  ];
}

void main() {
  testEnumMappingFromNodeProperties(
    const EnumMappingFromNode<node.AgentPlace, AgentPlace>(
      functionName: 'map_agent_place_from_node',
      seed: 71301,
      rustWireNames: nodeAgentPlaces,
      decodeNode: node.AgentPlace.decode,
      modelValues: AgentPlace.values,
      mapFromNode: mapAgentPlaceFromNode,
    ),
  );

  testEnumMappingToNodeProperties(
    const EnumMappingToNode<node.AgentPlace, AgentPlace>(
      functionName: 'map_agent_place_to_node',
      rustWireNames: nodeAgentPlaces,
      nodeValues: node.AgentPlace.values,
      modelValues: AgentPlace.values,
      mapToNode: mapAgentPlaceToNode,
      mapFromNode: mapAgentPlaceFromNode,
    ),
  );

  test('test_map_agent_places_from_node_property_keeps_order_and_repeats', () {
    final Random random = seededRandom(71303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.AgentPlace> wirePlaces = _randomNodePlaces(random);

      final List<AgentPlace> places = mapAgentPlacesFromNode(wirePlaces);

      expect(places, <AgentPlace>[
        for (final node.AgentPlace place in wirePlaces)
          mapAgentPlaceFromNode(place),
      ]);
    }
  });

  test('test_map_agent_places_from_node_property_maps_joined_lists_'
      'piece_by_piece', () {
    final Random random = seededRandom(71304);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.AgentPlace> firstPlaces = _randomNodePlaces(random);
      final List<node.AgentPlace> secondPlaces = _randomNodePlaces(random);

      final List<AgentPlace> joinedPlaces = mapAgentPlacesFromNode(
        <node.AgentPlace>[...firstPlaces, ...secondPlaces],
      );

      expect(joinedPlaces, <AgentPlace>[
        ...mapAgentPlacesFromNode(firstPlaces),
        ...mapAgentPlacesFromNode(secondPlaces),
      ]);
    }
  });

  test('test_map_agent_places_from_node_property_result_stays_fixed', () {
    final Random random = seededRandom(71305);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.AgentPlace> wirePlaces = _randomNodePlaces(random);
      final List<AgentPlace> places = mapAgentPlacesFromNode(wirePlaces);
      final List<AgentPlace> placesAtMapping = List<AgentPlace>.of(places);

      wirePlaces.add(pickOne(random, node.AgentPlace.values));

      expect(places, placesAtMapping);
      expect(() => places.add(AgentPlace.container), throwsUnsupportedError);
    }
  });

  test('test_map_place_offers_from_node_property_keeps_every_offer', () {
    final Random random = seededRandom(71306);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.PlaceOffer> wireOffers = _randomNodeOffers(random);

      final List<PlaceOffer> offers = mapPlaceOffersFromNode(wireOffers);

      expect(offers, <PlaceOffer>[
        for (final node.PlaceOffer offer in wireOffers)
          PlaceOffer(
            place: mapAgentPlaceFromNode(offer.place),
            problem: offer.problem,
          ),
      ]);
    }
  });

  test(
    'test_map_place_offers_from_node_property_problem_text_is_untouched',
    () {
      final Random random = seededRandom(71307);
      for (int i = 0; i < propertyIterations; i += 1) {
        final List<node.PlaceOffer> wireOffers = _randomNodeOffers(random);

        final List<PlaceOffer> offers = mapPlaceOffersFromNode(wireOffers);

        expect(offers.length, wireOffers.length);
        for (int j = 0; j < offers.length; j += 1) {
          final String? wireProblem = wireOffers[j].problem;
          expect(offers[j].problem, wireProblem);
          expect(offers[j].problem == null, wireProblem == null);
        }
      }
    },
  );

  test('test_map_place_offers_from_node_property_result_stays_fixed', () {
    final Random random = seededRandom(71308);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.PlaceOffer> wireOffers = _randomNodeOffers(random);
      final List<PlaceOffer> offers = mapPlaceOffersFromNode(wireOffers);
      final List<PlaceOffer> offersAtMapping = List<PlaceOffer>.of(offers);
      const PlaceOffer extraOffer = PlaceOffer(
        place: AgentPlace.container,
        problem: null,
      );

      wireOffers.insert(0, _randomNodeOffer(random));

      expect(offers, offersAtMapping);
      expect(() => offers.add(extraOffer), throwsUnsupportedError);
    }
  });
}
