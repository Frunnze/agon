import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/models/pairing.dart';

import '../../support/random_inputs.dart';

FakePairingRepository _buildRepository({
  required PairingSession? session,
  required Duration elapsed,
}) {
  return FakePairingRepository(
    session: session,
    request: null,
    clock: FixedClock(galleryNow.add(elapsed)),
    deviceRepository: FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      peerAddressProblem: null,
      gitlessFolderPaths: const <String>{},
    ),
    joinOutcome: galleryPairingOutcome,
  );
}

PairingSession _sessionWithProblem(String problem) {
  return PairingSession(
    code: galleryPairingSession.code,
    createdAt: galleryPairingSession.createdAt,
    expiresAt: galleryPairingSession.expiresAt,
    rendezvousProblem: problem,
  );
}

Duration _randomElapsed(Random random) {
  return Duration(seconds: random.nextInt(3600));
}

void main() {
  test(
    'test_start_pairing_property_fake_code_has_no_rendezvous_problem',
    () async {
      final Random random = seededRandom(73501);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakePairingRepository repository = _buildRepository(
          session: null,
          elapsed: _randomElapsed(random),
        );

        final PairingSession session = await repository.startPairing();

        expect(session.rendezvousProblem, isNull);
        expect(repository.findActiveSession()?.rendezvousProblem, isNull);
      }
    },
  );

  test(
    'test_start_pairing_property_new_code_replaces_the_old_problem',
    () async {
      final Random random = seededRandom(73502);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakePairingRepository repository = _buildRepository(
          session: _sessionWithProblem(randomText(random)),
          elapsed: _randomElapsed(random),
        );

        await repository.startPairing();

        expect(repository.findActiveSession(), isNotNull);
        expect(repository.findActiveSession()?.rendezvousProblem, isNull);
      }
    },
  );

  test('test_find_active_session_property_'
      'keeps_the_given_rendezvous_problem_while_live', () {
    final Random random = seededRandom(73503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomText(random);
      final Duration elapsed = _randomElapsed(random);
      final FakePairingRepository repository = _buildRepository(
        session: _sessionWithProblem(problem),
        elapsed: elapsed,
      );
      final bool isLive = galleryPairingSession.expiresAt.isAfter(
        galleryNow.add(elapsed),
      );

      final PairingSession? session = repository.findActiveSession();

      expect(session != null, isLive);
      if (session != null) {
        expect(session.rendezvousProblem, problem);
      }
    }
  });
}
