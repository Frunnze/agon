import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';

import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';

const int _longestSequence = 8;
const int _hugeTextRepeats = 2000;

String? _randomPeerProblem(Random random) {
  return pickOne<String?>(random, <String?>[
    null,
    '',
    '   ',
    randomText(random),
    'no relay ${randomWordPhrase(random)}',
    'Ünïcødé ${randomText(random) * _hugeTextRepeats}',
  ]);
}

void main() {
  test('test_find_peer_address_problem_property_returns_the_seeded_'
      'problem', () {
    final Random random = seededRandom(64113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String? problem = _randomPeerProblem(random);
      final FakeDeviceRepository repository = FakeDeviceRepository(
        devices: randomDeviceSeeds(random),
        currentDeviceId: deviceTestThisDevice,
        peerAddressProblem: problem,
        gitlessFolderPaths: const <String>{},
      );

      expect(repository.findPeerAddressProblem(), problem);
    }
  });

  test('test_find_peer_address_problem_property_is_stable_across_device_'
      'changes', () async {
    final Random random = seededRandom(64114);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String? problem = _randomPeerProblem(random);
      final FakeDeviceRepository repository = FakeDeviceRepository(
        devices: randomDeviceSeeds(random),
        currentDeviceId: deviceTestThisDevice,
        peerAddressProblem: problem,
        gitlessFolderPaths: const <String>{},
      );
      final int stepCount = random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await changeRandomDeviceValidly(random, repository);
      }

      expect(repository.findPeerAddressProblem(), problem);
    }
  });

  test('test_find_peer_address_problem_property_repeated_reads_'
      'agree', () {
    final Random random = seededRandom(64115);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = FakeDeviceRepository(
        devices: randomDeviceSeeds(random),
        currentDeviceId: deviceTestThisDevice,
        peerAddressProblem: _randomPeerProblem(random),
        gitlessFolderPaths: const <String>{},
      );
      final String? first = repository.findPeerAddressProblem();

      expect(repository.findPeerAddressProblem(), first);
      expect(repository.currentDevice().id, deviceTestThisDevice);
    }
  });
}
