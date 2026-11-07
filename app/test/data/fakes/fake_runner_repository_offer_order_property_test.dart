import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/runner_inputs.dart';

const List<AgentPlace> _nodePlaceOrder = <AgentPlace>[
  AgentPlace.localProcess,
  AgentPlace.container,
];

typedef _OfferView = ({AgentPlace place, String? problem});

FakeRunnerRepository _buildRunnerDevice(List<PlaceOffer> offers) {
  return buildRunnerRepository(
    runners: const <Runner>[],
    offers: offers,
    problem: null,
  );
}

List<_OfferView> _describeOffers(FakeRunnerRepository repository) {
  return <_OfferView>[
    for (final PlaceOffer offer in repository.findThisDeviceOffers()!)
      (place: offer.place, problem: offer.problem),
  ];
}

List<AgentPlace> _listPlaces(FakeRunnerRepository repository) {
  return <AgentPlace>[
    for (final PlaceOffer offer in repository.findThisDeviceOffers()!)
      offer.place,
  ];
}

void main() {
  test('test_choose_agent_offers_property_local_process_comes_before_'
      'container', () async {
    final Random random = seededRandom(68601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = _buildRunnerDevice(
        randomPlaceOffers(random),
      );
      final List<AgentPlace> choice = randomPlaceChoice(random);

      await repository.chooseAgentOffers(choice);

      final List<AgentPlace> places = _listPlaces(repository);
      final bool hasBoth =
          choice.contains(AgentPlace.localProcess) &&
          choice.contains(AgentPlace.container);
      if (hasBoth) {
        expect(places, _nodePlaceOrder);
      }
      final AgentPlace expectedFirst = choice.contains(AgentPlace.localProcess)
          ? AgentPlace.localProcess
          : AgentPlace.container;
      expect(places.first, expectedFirst);
    }
  });

  test('test_choose_agent_offers_property_the_callers_order_does_not_'
      'matter', () async {
    final Random random = seededRandom(68602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PlaceOffer> seeded = randomPlaceOffers(random);
      final FakeRunnerRepository first = _buildRunnerDevice(seeded);
      final FakeRunnerRepository second = _buildRunnerDevice(seeded);
      final List<AgentPlace> choice = randomPlaceChoice(random);
      final List<AgentPlace> shuffled = List<AgentPlace>.of(choice);
      shuffled.shuffle(random);

      await first.chooseAgentOffers(choice);
      await second.chooseAgentOffers(shuffled);

      expect(_describeOffers(first), _describeOffers(second));
      expect(first.findThisRunnerProblem(), second.findThisRunnerProblem());
    }
  });

  test('test_choose_agent_offers_property_matches_the_node_order', () async {
    final Random random = seededRandom(68603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PlaceOffer> seeded = randomPlaceOffers(random);
      final FakeRunnerRepository repository = _buildRunnerDevice(seeded);
      final List<AgentPlace> choice = randomPlaceChoice(random);
      final List<AgentPlace> expected = <AgentPlace>[
        for (final AgentPlace place in _nodePlaceOrder)
          if (choice.contains(place)) place,
      ];

      await repository.chooseAgentOffers(choice);

      expect(_listPlaces(repository), expected);
      expect(AgentPlace.values.toSet(), _nodePlaceOrder.toSet());
    }
  });
}
