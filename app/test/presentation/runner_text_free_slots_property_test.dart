import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';

import '../support/random_inputs.dart';
import '../support/sample_runners.dart';

const int _largestExtraBusySlots = 5;

Runner _withBusySlots(Runner runner, int slotsBusy) {
  return Runner(
    deviceId: runner.deviceId,
    labels: runner.labels,
    slotsTotal: runner.slotsTotal,
    slotsBusy: slotsBusy,
    link: runner.link,
    online: runner.online,
    acceptingNewRuns: runner.acceptingNewRuns,
    offers: runner.offers,
    allowedHosts: runner.allowedHosts,
  );
}

Runner _randomOverfullRunner(Random random) {
  final Runner runner = randomRunner(random);
  final int extraBusySlots = 1 + random.nextInt(_largestExtraBusySlots);
  return _withBusySlots(runner, runner.slotsTotal + extraBusySlots);
}

List<Runner> _randomMixedRunners(Random random) {
  final List<Runner> runners = randomRunners(random);
  final int overfullCount = random.nextInt(3);
  for (int i = 0; i < overfullCount; i += 1) {
    final Runner overfull = _randomOverfullRunner(random);
    runners.insert(random.nextInt(runners.length + 1), overfull);
  }
  return runners;
}

int _countFreeSlotsByModel(List<Runner> runners) {
  int freeSlots = 0;
  for (final Runner runner in runners) {
    final bool takesWork = runner.online && runner.acceptingNewRuns;
    final int unusedSlots = runner.slotsTotal - runner.slotsBusy;
    if (takesWork && unusedSlots > 0) {
      freeSlots += unusedSlots;
    }
  }
  return freeSlots;
}

void main() {
  test('test_count_free_slots_property_is_never_negative', () {
    final Random random = seededRandom(74801);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = _randomMixedRunners(random);

      expect(countFreeSlots(runners), greaterThanOrEqualTo(0));
      expect(describeRunnerFleet(runners), isNot(contains('-')));
    }
  });

  test('test_count_free_slots_property_overfull_runner_adds_nothing', () {
    final Random random = seededRandom(74802);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final List<Runner> withOverfull = <Runner>[
        ...runners,
        _randomOverfullRunner(random),
      ];

      expect(countFreeSlots(withOverfull), countFreeSlots(runners));
    }
  });

  test('test_count_free_slots_property_matches_clamped_model', () {
    final Random random = seededRandom(74803);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = _randomMixedRunners(random);

      expect(countFreeSlots(runners), _countFreeSlotsByModel(runners));
    }
  });
}
