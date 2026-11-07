import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/runner_inputs.dart';

const String _typePrefix = 'test_fake_runner_repository';
const int _longestSequence = 12;

void main() {
  test('${_typePrefix}_new_property_keeps_every_seeded_record', () {
    final Random random = seededRandom(66101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomDistinctRunners(random);
      final List<PlaceOffer> offers = randomPlaceOffers(random);
      final String? problem = randomOfferProblem(random);

      final FakeRunnerRepository repository = buildRunnerRepository(
        runners: runners,
        offers: offers,
        problem: problem,
      );

      expect(
        describeRunners(repository.listRunners()),
        describeRunners(runners),
      );
      expect(repository.findThisDeviceOffers(), orderedEquals(offers));
      expect(repository.findThisRunnerProblem(), problem);
    }
  });

  test('${_typePrefix}_new_property_later_seed_edits_do_not_leak', () {
    final Random random = seededRandom(66102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomDistinctRunners(random);
      final List<PlaceOffer> offers = randomPlaceOffers(random);
      final List<String> runnersBefore = describeRunners(runners);
      final List<PlaceOffer> offersBefore = List<PlaceOffer>.of(offers);
      final FakeRunnerRepository repository = buildRunnerRepository(
        runners: runners,
        offers: offers,
        problem: null,
      );

      runners.clear();
      offers.add(
        const PlaceOffer(place: AgentPlace.container, problem: 'late'),
      );

      expect(describeRunners(repository.listRunners()), runnersBefore);
      expect(repository.findThisDeviceOffers(), orderedEquals(offersBefore));
    }
  });

  test('${_typePrefix}_new_property_shown_lists_cannot_be_edited', () {
    final Random random = seededRandom(66103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = buildRunnerRepository(
        runners: randomDistinctRunners(random),
        offers: randomPlaceOffers(random),
        problem: null,
      );
      final PlaceOffer extra = PlaceOffer(
        place: pickOne(random, AgentPlace.values),
        problem: null,
      );

      expect(repository.listRunners().clear, throwsUnsupportedError);
      expect(
        () => repository.findThisDeviceOffers()!.add(extra),
        throwsUnsupportedError,
      );
    }
  });

  test(
    'test_list_runners_property_changes_keep_the_order_and_count',
    () async {
      final Random random = seededRandom(66104);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Runner> runners = randomDistinctRunners(random);
        final FakeRunnerRepository repository = buildRunnerRepository(
          runners: runners,
          offers: null,
          problem: null,
        );
        if (runners.isEmpty) {
          expect(repository.listRunners(), isEmpty);
          continue;
        }

        final int stepCount = random.nextInt(_longestSequence);
        for (int step = 0; step < stepCount; step += 1) {
          final Runner runner = pickOne(random, runners);
          await pauseOrResumeRunner(random, repository, runner.deviceId);
        }

        final List<DeviceId> listed = <DeviceId>[
          for (final Runner runner in repository.listRunners())
            runner.deviceId,
        ];
        final List<DeviceId> seeded = <DeviceId>[
          for (final Runner runner in runners) runner.deviceId,
        ];
        expect(listed, seeded);
      }
    },
  );

  test('test_list_runners_property_only_the_changed_runner_differs', () async {
    final Random random = seededRandom(66105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomDistinctRunners(random);
      if (runners.isEmpty) {
        continue;
      }
      final FakeRunnerRepository repository = buildRunnerRepository(
        runners: runners,
        offers: null,
        problem: null,
      );
      final Runner changed = pickOne(random, runners);

      final Runner stored = await pauseOrResumeRunner(
        random,
        repository,
        changed.deviceId,
      );

      final Runner expectedChanged = stored.acceptingNewRuns
          ? changed.asAcceptingNewRuns()
          : changed.asPaused();
      final List<String> expected = <String>[];
      for (final Runner runner in runners) {
        final bool isChanged = runner.deviceId == changed.deviceId;
        final Runner shown = isChanged ? expectedChanged : runner;
        expected.add(describeRunner(shown));
      }
      expect(describeRunners(repository.listRunners()), expected);
    }
  });

  test(
    'test_list_runners_property_offer_choices_leave_runners_alone',
    () async {
      final Random random = seededRandom(66112);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Runner> runners = randomDistinctRunners(random);
        final FakeRunnerRepository repository = buildRunnerRepository(
          runners: runners,
          offers: randomPlaceOffers(random),
          problem: null,
        );

        await repository.chooseAgentOffers(randomPlaceChoice(random));

        expect(
          describeRunners(repository.listRunners()),
          describeRunners(runners),
        );
      }
    },
  );

  test('test_find_runner_property_finds_exactly_the_listed_runners', () {
    final Random random = seededRandom(66106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = buildRandomRunnerRepository(
        random,
      );

      for (final Runner listed in repository.listRunners()) {
        expect(repository.findRunner(listed.deviceId), same(listed));
      }
    }
  });

  test('test_find_runner_property_unknown_devices_are_not_found', () {
    final Random random = seededRandom(66107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = buildRandomRunnerRepository(
        random,
      );
      final DeviceId unknown = randomUnknownDeviceId(random);

      expect(
        () => repository.findRunner(unknown),
        throwsA(
          isA<RecordNotFound>().having(
            (RecordNotFound error) => error.identifier,
            'identifier',
            unknown.value,
          ),
        ),
      );
    }
  });

  test('test_find_runner_property_shows_the_latest_change', () async {
    final Random random = seededRandom(66108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomDistinctRunners(random);
      if (runners.isEmpty) {
        continue;
      }
      final FakeRunnerRepository repository = buildRunnerRepository(
        runners: runners,
        offers: null,
        problem: null,
      );
      final Map<DeviceId, bool> expectedAccepting = <DeviceId, bool>{
        for (final Runner runner in runners)
          runner.deviceId: runner.acceptingNewRuns,
      };

      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        final DeviceId deviceId = pickOne(random, runners).deviceId;
        final Runner stored = await pauseOrResumeRunner(
          random,
          repository,
          deviceId,
        );
        expectedAccepting[deviceId] = stored.acceptingNewRuns;
      }

      for (final Runner runner in runners) {
        final Runner found = repository.findRunner(runner.deviceId);
        expect(found.acceptingNewRuns, expectedAccepting[runner.deviceId]);
      }
    }
  });
}
