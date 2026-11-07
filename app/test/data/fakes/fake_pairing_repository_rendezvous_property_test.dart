import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/pairing_repository_harness.dart';
import '../node_backed/support/simulated_pairing_node.dart';
import 'support/pairing_inputs.dart';

const int _differentialIterations = 25;
const int _largestStartCount = 5;
const int _neverJoins = 1000000;
const Duration _pastExpiry = Duration(minutes: 6);
const List<String?> _hostileProblems = <String?>[
  null,
  '',
  '   ',
  '\n\t',
  'Ünïcødé relay',
  '中继服务器不可达',
  'مرحلات غير متاحة',
  '🔌 relay down',
  '<b>relay</b> & "quotes"',
  r'\u0000 $problem ${field}',
];

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _hostileProblems);
  }
  return randomText(random);
}

PairingSession? _randomEarlierSession(Random random, DateTime now) {
  if (random.nextBool()) {
    return null;
  }
  return randomPairingSession(random, now);
}

FakePairingRepository _buildFakeRepository({
  required String? startedPairingRendezvousProblem,
  required PairingSession? session,
  required Clock clock,
}) {
  return FakePairingRepository(
    session: session,
    request: null,
    clock: clock,
    deviceRepository: FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      peerAddressProblem: null,
      gitlessFolderPaths: const <String>{},
    ),
    joinOutcome: galleryPairingOutcome,
    startedPairingRendezvousProblem: startedPairingRendezvousProblem,
  );
}

Future<void> _endSessionRandomly({
  required Random random,
  required FakePairingRepository repository,
  required MovableClock clock,
}) async {
  if (random.nextBool()) {
    await repository.cancelPairing();
    return;
  }
  if (random.nextBool()) {
    clock.moment = clock.moment.add(_pastExpiry);
  }
}

void main() {
  test(
    'test_start_pairing_property_reports_exactly_the_configured_problem',
    () async {
      final Random random = seededRandom(74901);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String? problem = _randomProblem(random);
        final DateTime now = randomPairingMoment(random);
        final FakePairingRepository repository = _buildFakeRepository(
          startedPairingRendezvousProblem: problem,
          session: _randomEarlierSession(random, now),
          clock: FixedClock(now),
        );

        final PairingSession session = await repository.startPairing();

        expect(session.rendezvousProblem, problem, reason: 'problem $problem');
        expect(
          repository.findActiveSession()?.rendezvousProblem,
          problem,
          reason: 'problem $problem',
        );
      }
    },
  );

  test(
    'test_start_pairing_property_every_repeated_start_keeps_reporting_it',
    () async {
      final Random random = seededRandom(74902);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String? problem = _randomProblem(random);
        final MovableClock clock = MovableClock(randomPairingMoment(random));
        final FakePairingRepository repository = _buildFakeRepository(
          startedPairingRendezvousProblem: problem,
          session: null,
          clock: clock,
        );
        final int startCount = 1 + random.nextInt(_largestStartCount);

        for (int start = 0; start < startCount; start += 1) {
          final PairingSession session = await repository.startPairing();

          expect(session.rendezvousProblem, problem, reason: 'start $start');
          expect(
            repository.findActiveSession()?.rendezvousProblem,
            problem,
            reason: 'start $start',
          );
          await _endSessionRandomly(
            random: random,
            repository: repository,
            clock: clock,
          );
        }
      }
    },
  );

  test(
    'test_start_pairing_property_matches_the_node_backed_problem',
    () async {
      final Random random = seededRandom(74903);

      for (int i = 0; i < _differentialIterations; i += 1) {
        final String? problem = _randomProblem(random);
        final SimulatedPairingNode simulated = buildPairingNode(
          pollsBeforeJoin: _neverJoins,
        );
        simulated.rendezvousProblem = problem;
        final MovableClock clock = MovableClock(pairingStart);
        final NodeBackedPairingRepository nodeBacked = buildPairingRepository(
          simulated,
          clock,
        );
        final FakePairingRepository fake = _buildFakeRepository(
          startedPairingRendezvousProblem: problem,
          session: null,
          clock: clock,
        );

        final PairingSession nodeSession = await nodeBacked.startPairing();
        final PairingSession fakeSession = await fake.startPairing();

        expect(
          fakeSession.rendezvousProblem,
          nodeSession.rendezvousProblem,
          reason: 'problem $problem',
        );
        expect(
          fake.findActiveSession()?.rendezvousProblem,
          nodeBacked.findActiveSession()?.rendezvousProblem,
          reason: 'problem $problem',
        );
        nodeBacked.dispose();
      }
    },
  );
}
