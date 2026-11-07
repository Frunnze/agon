import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';
import 'support/runner_inputs.dart';

const int _longestSequence = 8;

FakeRunnerRepository _buildRunnerDevice(Random random) {
  return buildRunnerRepository(
    runners: randomDistinctRunners(random),
    offers: randomPlaceOffers(random),
    problem: randomOfferProblem(random),
  );
}

String? _findProblemOf(List<PlaceOffer> offers, AgentPlace place) {
  for (final PlaceOffer offer in offers) {
    if (offer.place == place) {
      return offer.problem;
    }
  }
  return null;
}

Set<AgentPlace> _listPlaces(List<PlaceOffer> offers) {
  return <AgentPlace>{for (final PlaceOffer offer in offers) offer.place};
}

bool _isEveryOfferBlocked(List<PlaceOffer> offers) {
  for (final PlaceOffer offer in offers) {
    if (offer.problem == null) {
      return false;
    }
  }
  return true;
}

void main() {
  test(
    'test_find_this_device_offers_property_null_without_a_runner',
    () async {
      final Random random = seededRandom(66301);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeRunnerRepository repository = buildRunnerRepository(
          runners: randomDistinctRunners(random),
          offers: null,
          problem: randomOfferProblem(random),
        );

        final bool wasRefused = await isRefused(
          () => repository.chooseAgentOffers(randomPlaceChoice(random)),
          isRefusal: refusesWithStateError,
        );

        expect(wasRefused, isTrue);
        expect(repository.findThisDeviceOffers(), isNull);
      }
    },
  );

  test(
    'test_find_this_device_offers_property_lists_each_place_once',
    () async {
      final Random random = seededRandom(66302);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeRunnerRepository repository = _buildRunnerDevice(random);

        await repository.chooseAgentOffers(randomPlaceChoice(random));

        final List<PlaceOffer> offers = repository.findThisDeviceOffers()!;
        expect(_listPlaces(offers).length, offers.length);
      }
    },
  );

  test(
    'test_find_this_device_offers_property_lists_the_chosen_places',
    () async {
      final Random random = seededRandom(66303);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeRunnerRepository repository = _buildRunnerDevice(random);
        final List<AgentPlace> choice = randomPlaceChoice(random);

        await repository.chooseAgentOffers(choice);

        final List<PlaceOffer> offers = repository.findThisDeviceOffers()!;
        expect(_listPlaces(offers), choice.toSet());
      }
    },
  );

  test('test_find_this_runner_problem_property_kept_until_a_choice', () async {
    final Random random = seededRandom(66304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = _buildRunnerDevice(random);
      final String? seeded = repository.findThisRunnerProblem();

      for (final Runner runner in repository.listRunners()) {
        await pauseOrResumeRunner(random, repository, runner.deviceId);
      }

      expect(repository.findThisRunnerProblem(), seeded);
    }
  });

  test(
    'test_find_this_runner_problem_property_set_when_nothing_runs',
    () async {
      final Random random = seededRandom(66305);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeRunnerRepository repository = _buildRunnerDevice(random);
        final int stepCount = 1 + random.nextInt(_longestSequence);

        for (int step = 0; step < stepCount; step += 1) {
          await repository.chooseAgentOffers(randomPlaceChoice(random));

          final List<PlaceOffer> offers = repository.findThisDeviceOffers()!;
          final String? problem = repository.findThisRunnerProblem();
          expect(problem != null, _isEveryOfferBlocked(offers));
        }
      }
    },
  );

  test(
    'test_find_this_runner_problem_property_names_an_offers_problem',
    () async {
      final Random random = seededRandom(66306);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeRunnerRepository repository = _buildRunnerDevice(random);

        await repository.chooseAgentOffers(randomPlaceChoice(random));

        final List<PlaceOffer> offers = repository.findThisDeviceOffers()!;
        final String? problem = repository.findThisRunnerProblem();
        if (problem != null) {
          expect(problem, offers.first.problem);
        }
      }
    },
  );

  test('test_choose_agent_offers_property_refuses_an_empty_choice', () async {
    final Random random = seededRandom(66307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = _buildRunnerDevice(random);
      final List<PlaceOffer> offersBefore = repository.findThisDeviceOffers()!;
      final String? problemBefore = repository.findThisRunnerProblem();
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);

      final bool wasRefused = await isRefused(
        () => repository.chooseAgentOffers(const <AgentPlace>[]),
        isRefusal: refusesWithStateError,
      );

      expect(wasRefused, isTrue);
      expect(repository.findThisDeviceOffers(), orderedEquals(offersBefore));
      expect(repository.findThisRunnerProblem(), problemBefore);
      expect(counter.count, 0);
    }
  });

  test('test_choose_agent_offers_property_is_idempotent', () async {
    final Random random = seededRandom(66308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = _buildRunnerDevice(random);
      final List<AgentPlace> choice = randomPlaceChoice(random);

      await repository.chooseAgentOffers(choice);
      final List<PlaceOffer> once = repository.findThisDeviceOffers()!;
      final String? problemOnce = repository.findThisRunnerProblem();
      await repository.chooseAgentOffers(choice);

      expect(repository.findThisDeviceOffers(), orderedEquals(once));
      expect(repository.findThisRunnerProblem(), problemOnce);
    }
  });

  test('test_choose_agent_offers_property_notifies_once_per_choice', () async {
    final Random random = seededRandom(66309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = _buildRunnerDevice(random);
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);
      final int stepCount = random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await repository.chooseAgentOffers(randomPlaceChoice(random));
      }

      expect(counter.count, stepCount);
    }
  });

  test('test_find_previous_problem_property_kept_places_keep_it', () async {
    final Random random = seededRandom(66310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = _buildRunnerDevice(random);
      final List<PlaceOffer> before = repository.findThisDeviceOffers()!;
      final List<AgentPlace> choice = randomPlaceChoice(random);

      await repository.chooseAgentOffers(choice);

      for (final PlaceOffer offer in repository.findThisDeviceOffers()!) {
        if (_listPlaces(before).contains(offer.place)) {
          expect(offer.problem, _findProblemOf(before, offer.place));
        }
      }
    }
  });

  test('test_find_previous_problem_property_new_places_start_clear', () async {
    final Random random = seededRandom(66311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = _buildRunnerDevice(random);
      final Set<AgentPlace> before = _listPlaces(
        repository.findThisDeviceOffers()!,
      );

      await repository.chooseAgentOffers(randomPlaceChoice(random));

      for (final PlaceOffer offer in repository.findThisDeviceOffers()!) {
        if (!before.contains(offer.place)) {
          expect(offer.problem, isNull);
        }
      }
    }
  });

  test('test_find_previous_problem_property_order_does_not_matter', () async {
    final Random random = seededRandom(66312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PlaceOffer> seeded = randomPlaceOffers(random);
      final List<AgentPlace> choice = randomPlaceChoice(random);
      final List<AgentPlace> shuffled = List<AgentPlace>.of(choice);
      shuffled.shuffle(random);
      final FakeRunnerRepository inOrder = buildRunnerRepository(
        runners: const <Runner>[],
        offers: seeded,
        problem: null,
      );
      final FakeRunnerRepository reordered = buildRunnerRepository(
        runners: const <Runner>[],
        offers: seeded,
        problem: null,
      );

      await inOrder.chooseAgentOffers(choice);
      await reordered.chooseAgentOffers(shuffled);

      for (final AgentPlace place in choice) {
        expect(
          _findProblemOf(reordered.findThisDeviceOffers()!, place),
          _findProblemOf(inOrder.findThisDeviceOffers()!, place),
        );
      }
    }
  });
}
