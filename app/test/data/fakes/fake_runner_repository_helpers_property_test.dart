import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/runner_inputs.dart';

FakeRunnerRepository _buildWithOffers(List<PlaceOffer>? offers) {
  return buildRunnerRepository(
    runners: const <Runner>[],
    offers: offers,
    problem: null,
  );
}

List<PlaceOffer> _randomBlockedOffers(Random random) {
  return <PlaceOffer>[
    for (final AgentPlace place in AgentPlace.values)
      PlaceOffer(place: place, problem: 'blocked ${randomText(random)}'),
  ];
}

void main() {
  test(
    'test_find_blocking_problem_property_blocked_only_when_all_are',
    () async {
      final Random random = seededRandom(67401);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<PlaceOffer> seeded = randomPlaceOffers(random);
        final FakeRunnerRepository repository = _buildWithOffers(seeded);
        final List<AgentPlace> choice = <AgentPlace>[
          for (final PlaceOffer offer in seeded) offer.place,
        ];
        if (choice.isEmpty) {
          continue;
        }

        await repository.chooseAgentOffers(choice);

        final bool isEveryPlaceBlocked = seeded.every(
          (PlaceOffer offer) => offer.problem != null,
        );
        expect(
          repository.findThisRunnerProblem() != null,
          isEveryPlaceBlocked,
        );
      }
    },
  );

  test(
    'test_find_blocking_problem_property_names_the_first_problem',
    () async {
      final Random random = seededRandom(67402);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<PlaceOffer> seeded = _randomBlockedOffers(random);
        final FakeRunnerRepository repository = _buildWithOffers(seeded);
        final List<AgentPlace> choice = List<AgentPlace>.of(AgentPlace.values);
        choice.shuffle(random);

        await repository.chooseAgentOffers(choice);

        final List<PlaceOffer> shown = repository.findThisDeviceOffers()!;
        expect(repository.findThisRunnerProblem(), shown.first.problem);
      }
    },
  );

  test('test_find_blocking_problem_property_a_new_place_clears_it', () async {
    final Random random = seededRandom(67403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace kept = pickOne(random, AgentPlace.values);
      final PlaceOffer blocked = PlaceOffer(
        place: kept,
        problem: 'blocked ${randomText(random)}',
      );
      final FakeRunnerRepository repository = buildRunnerRepository(
        runners: const <Runner>[],
        offers: <PlaceOffer>[blocked],
        problem: blocked.problem,
      );

      await repository.chooseAgentOffers(AgentPlace.values);

      expect(repository.findThisRunnerProblem(), isNull);
    }
  });

  test('test_copy_offers_property_a_device_without_offers_stays_so', () {
    final Random random = seededRandom(67404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = buildRunnerRepository(
        runners: randomDistinctRunners(random),
        offers: null,
        problem: randomOfferProblem(random),
      );

      expect(repository.findThisDeviceOffers(), isNull);
    }
  });

  test('test_copy_offers_property_keeps_every_offer_in_order', () {
    final Random random = seededRandom(67405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PlaceOffer> seeded = randomPlaceOffers(random);

      final FakeRunnerRepository repository = _buildWithOffers(seeded);

      expect(repository.findThisDeviceOffers(), orderedEquals(seeded));
    }
  });

  test('test_copy_offers_property_the_copy_is_independent', () {
    final Random random = seededRandom(67406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PlaceOffer> seeded = randomPlaceOffers(random);
      final int countBefore = seeded.length;
      final FakeRunnerRepository repository = _buildWithOffers(seeded);

      seeded.clear();

      final List<PlaceOffer> shown = repository.findThisDeviceOffers()!;
      expect(shown.length, countBefore);
      expect(shown.clear, throwsUnsupportedError);
    }
  });
}
