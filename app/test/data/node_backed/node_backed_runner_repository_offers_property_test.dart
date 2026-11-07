import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../bridge/support/random_account_json.dart';
import '../../support/random_inputs.dart';
import 'support/runner_repository_rig.dart';
import 'support/simulated_work_node.dart' show WireRecord;

const String _typePrefix = 'test_node_backed_runner_repository';
const int _iterations = 40;
const Map<String, AgentPlace> _placesByWireName = <String, AgentPlace>{
  'local_process': AgentPlace.localProcess,
  'container': AgentPlace.container,
};

typedef _ShownOffer = ({AgentPlace place, String? problem});

List<_ShownOffer>? _describeShownOffers(RunnerRig rig) {
  final List<PlaceOffer>? offers = rig.repository.findThisDeviceOffers();
  if (offers == null) {
    return null;
  }
  return <_ShownOffer>[
    for (final PlaceOffer offer in offers)
      (place: offer.place, problem: offer.problem),
  ];
}

List<_ShownOffer>? _describeNodeOffers(RunnerRig rig) {
  final List<WireRecord>? offers = rig.node.device.runnerOffers;
  if (offers == null) {
    return null;
  }
  return <_ShownOffer>[
    for (final WireRecord offer in offers)
      (
        place: _placesByWireName[offer['place']]!,
        problem: offer['problem'] as String?,
      ),
  ];
}

void _seedHostileOffers(Random random, RunnerRig rig) {
  rig.node.device.runnerSettings = randomRunnerSettingsJson(random);
  rig.node.device.runnerOffers = <WireRecord>[
    for (final String place in _placesByWireName.keys)
      if (random.nextBool())
        <String, Object?>{
          'place': place,
          'problem': random.nextBool() ? null : randomHostileText(random),
        },
  ];
}

void main() {
  test('${_typePrefix}_find_this_device_offers_property_none_on_a_device_'
      'that_cannot_run', () async {
    final Random random = seededRandom(81221);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.device.runnerSettings = null;
      rig.node.device.runnerOffers = null;

      await rig.repository.load();

      expect(rig.repository.findThisDeviceOffers(), isNull);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_find_this_device_offers_property_keeps_node_order_'
      'and_problems', () async {
    final Random random = seededRandom(81222);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.seedThisDevice(random);

      await rig.repository.load();

      expect(_describeShownOffers(rig), _describeNodeOffers(rig));
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_find_this_device_offers_property_reads_are_stable_'
      'and_unmodifiable', () async {
    final Random random = seededRandom(81223);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      _seedHostileOffers(random, rig);
      await rig.repository.load();
      final int notified = rig.notifications.count;

      final List<PlaceOffer> first = rig.repository.findThisDeviceOffers()!;
      final List<PlaceOffer>? second = rig.repository.findThisDeviceOffers();

      expect(identical(first, second), isTrue);
      expect(
        () => first.add(
          const PlaceOffer(place: AgentPlace.container, problem: null),
        ),
        throwsUnsupportedError,
      );
      expect(rig.notifications.count, notified);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_find_this_runner_problem_property_is_the_node_'
      'problem', () async {
    final Random random = seededRandom(81224);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final String? problem = random.nextBool()
          ? null
          : randomHostileText(random);
      rig.node.device.runnerProblem = problem;

      await rig.repository.load();

      expect(rig.repository.findThisRunnerProblem(), problem);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_find_this_runner_problem_property_follows_the_node_'
      'on_every_reload', () async {
    final Random random = seededRandom(81225);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);

      for (int step = 0; step < 4; step += 1) {
        rig.node.seedThisDevice(random);
        await rig.repository.load();

        expect(
          rig.repository.findThisRunnerProblem(),
          rig.node.device.runnerProblem,
        );
        expect(_describeShownOffers(rig), _describeNodeOffers(rig));
      }
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_find_this_runner_problem_property_is_the_first_'
      'problem_only_when_every_offer_is_blocked', () async {
    final Random random = seededRandom(81226);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.seedThisDevice(random);
      await rig.repository.load();

      final List<PlaceOffer> offers =
          rig.repository.findThisDeviceOffers() ?? <PlaceOffer>[];
      final bool isEveryOfferBlocked =
          offers.isNotEmpty &&
          offers.every((PlaceOffer offer) => offer.problem != null);
      final String? expected = isEveryOfferBlocked
          ? offers.first.problem
          : null;

      expect(rig.repository.findThisRunnerProblem(), expected);
      closeRunnerRig(rig);
    }
  });
  test('${_typePrefix}_map_this_device_offers_property_none_stays_'
      'none', () async {
    final Random random = seededRandom(81230);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.device.runnerSettings = random.nextBool()
          ? randomRunnerSettingsJson(random)
          : null;
      rig.node.device.runnerOffers = null;
      rig.node.device.runnerProblem = randomHostileText(random);

      await rig.repository.load();

      expect(rig.repository.findThisDeviceOffers(), isNull);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_map_this_device_offers_property_an_empty_list_'
      'stays_empty', () async {
    final Random random = seededRandom(81231);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.device.runnerSettings = randomRunnerSettingsJson(random);
      rig.node.device.runnerOffers = <WireRecord>[];

      await rig.repository.load();

      expect(rig.repository.findThisDeviceOffers(), isEmpty);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_map_this_device_offers_property_hostile_problems_'
      'survive', () async {
    final Random random = seededRandom(81232);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      _seedHostileOffers(random, rig);

      await rig.repository.load();

      expect(_describeShownOffers(rig), _describeNodeOffers(rig));
      closeRunnerRig(rig);
    }
  });
}
