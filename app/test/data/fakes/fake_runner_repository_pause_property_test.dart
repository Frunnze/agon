import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_device_node.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';
import 'support/runner_inputs.dart';

const int _longestSequence = 12;
const int _sequenceIterations = 40;
const int _largestNodeRunnerCount = 5;

typedef _RunnerChange = Future<Runner> Function(
  RunnerRepository repository,
  DeviceId deviceId,
);

typedef _ChangeCase = ({
  String name,
  _RunnerChange change,
  bool acceptingAfter,
  int firstSeed,
});

typedef _Pair = ({
  FakeRunnerRepository fake,
  NodeBackedRunnerRepository nodeBacked,
});

bool _refusesAsNotFound(Object error) => error is RecordNotFound;

Future<Runner> _pause(RunnerRepository repository, DeviceId deviceId) {
  return repository.pauseRunner(deviceId);
}

Future<Runner> _resume(RunnerRepository repository, DeviceId deviceId) {
  return repository.resumeRunner(deviceId);
}

String _describeEverythingButAccepting(Runner runner) {
  return describeRunner(runner.asPaused());
}

Future<_Pair> _buildPair(Random random) async {
  final SimulatedDeviceNode simulated = SimulatedDeviceNode(
    thisDeviceId: 'this-device',
  );
  final int runnerCount = 1 + random.nextInt(_largestNodeRunnerCount);
  for (int i = 0; i < runnerCount; i += 1) {
    simulated.addRunnerFromElsewhere(random);
  }
  final NodeBackedRunnerRepository nodeBacked = NodeBackedRunnerRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: buildSingleWorkspaceRepository(),
  );
  await nodeBacked.load();
  final FakeRunnerRepository fake = buildRunnerRepository(
    runners: nodeBacked.listRunners(),
    offers: null,
    problem: null,
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

const List<_RunnerChange> _bothChanges = <_RunnerChange>[_pause, _resume];

void _defineChangeProperties(_ChangeCase changeCase) {
  final String name = changeCase.name;
  final _RunnerChange change = changeCase.change;

  test('test_${name}_property_sets_only_the_accepting_switch', () async {
    final Random random = seededRandom(changeCase.firstSeed);

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
      final Runner before = pickOne(random, runners);

      final Runner after = await change(repository, before.deviceId);

      expect(after.acceptingNewRuns, changeCase.acceptingAfter);
      expect(
        _describeEverythingButAccepting(after),
        _describeEverythingButAccepting(before),
      );
    }
  });

  test('test_${name}_property_is_idempotent', () async {
    final Random random = seededRandom(changeCase.firstSeed + 1);

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
      final DeviceId deviceId = pickOne(random, runners).deviceId;

      final Runner once = await change(repository, deviceId);
      final List<String> afterOnce = describeRunners(repository.listRunners());
      final Runner twice = await change(repository, deviceId);

      expect(describeRunner(twice), describeRunner(once));
      expect(describeRunners(repository.listRunners()), afterOnce);
    }
  });

  test('test_${name}_property_unknown_devices_are_refused', () async {
    final Random random = seededRandom(changeCase.firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = buildRandomRunnerRepository(
        random,
      );
      final DeviceId unknown = randomUnknownDeviceId(random);

      final bool wasRefused = await isRefused(
        () => change(repository, unknown),
        isRefusal: _refusesAsNotFound,
      );

      expect(wasRefused, isTrue);
    }
  });

  test(
    'test_${name}_property_agrees_with_the_node_backed_repository',
    () async {
      final Random random = seededRandom(changeCase.firstSeed + 3);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _Pair pair = await _buildPair(random);
        final int stepCount = 1 + random.nextInt(_longestSequence);

        for (int step = 0; step < stepCount; step += 1) {
          final DeviceId deviceId = pickOne(
            random,
            pair.fake.listRunners(),
          ).deviceId;
          final _RunnerChange chosen = random.nextBool()
              ? change
              : pickOne(random, _bothChanges);
          final Runner fromFake = await chosen(pair.fake, deviceId);
          final Runner fromNode = await chosen(pair.nodeBacked, deviceId);

          expect(describeRunner(fromFake), describeRunner(fromNode));
        }

        expect(
          describeRunners(pair.fake.listRunners()),
          describeRunners(pair.nodeBacked.listRunners()),
        );
        pair.nodeBacked.dispose();
      }
    },
  );
}

void main() {
  _defineChangeProperties((
    name: 'pause_runner',
    change: _pause,
    acceptingAfter: false,
    firstSeed: 66201,
  ));
  _defineChangeProperties((
    name: 'resume_runner',
    change: _resume,
    acceptingAfter: true,
    firstSeed: 66211,
  ));

  test('test_resume_runner_property_undoes_a_pause', () async {
    final Random random = seededRandom(66221);

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
      final Runner before = pickOne(random, runners);

      await repository.pauseRunner(before.deviceId);
      final Runner resumed = await repository.resumeRunner(before.deviceId);

      expect(
        describeRunner(resumed),
        describeRunner(before.asAcceptingNewRuns()),
      );
    }
  });

  test('test_store_runner_property_notifies_once_per_change', () async {
    final Random random = seededRandom(66109);

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
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);

      final int stepCount = random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        final Runner runner = pickOne(random, runners);
        await pauseOrResumeRunner(random, repository, runner.deviceId);
      }

      expect(counter.count, stepCount);
    }
  });

  test('test_store_runner_property_returns_what_it_stores', () async {
    final Random random = seededRandom(66110);

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
      final DeviceId deviceId = pickOne(random, runners).deviceId;

      final Runner returned = await pauseOrResumeRunner(
        random,
        repository,
        deviceId,
      );

      expect(repository.findRunner(deviceId), same(returned));
      final int sameDeviceCount = repository
          .listRunners()
          .where((Runner runner) => runner.deviceId == deviceId)
          .length;
      expect(sameDeviceCount, 1);
    }
  });

  test('test_store_runner_property_refusals_store_nothing', () async {
    final Random random = seededRandom(66111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRunnerRepository repository = buildRandomRunnerRepository(
        random,
      );
      final List<String> before = describeRunners(repository.listRunners());
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);
      final DeviceId unknown = randomUnknownDeviceId(random);

      final bool wasRefused = await isRefused(
        () => pauseOrResumeRunner(random, repository, unknown),
        isRefusal: _refusesAsNotFound,
      );

      expect(wasRefused, isTrue);
      expect(describeRunners(repository.listRunners()), before);
      expect(counter.count, 0);
    }
  });
}
