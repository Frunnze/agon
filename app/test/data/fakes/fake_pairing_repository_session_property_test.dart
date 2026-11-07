import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';

import '../../support/random_inputs.dart';
import 'support/pairing_inputs.dart';
import 'support/pairing_steps.dart';

const String _typePrefix = 'test_fake_pairing_repository';
const int _longestSequence = 10;
const int _largestBoundaryOffsetSeconds = 3;

PairingSession _sessionEndingNear(Random random, DateTime now) {
  final int offset =
      random.nextInt(2 * _largestBoundaryOffsetSeconds + 1) -
      _largestBoundaryOffsetSeconds;
  final DateTime expiresAt = now.add(Duration(seconds: offset));
  return PairingSession(
    code: randomText(random),
    createdAt: expiresAt.subtract(pairingLifetime),
    expiresAt: expiresAt,
    rendezvousProblem: null,
  );
}

void main() {
  test('${_typePrefix}_constructor_property_keeps_the_given_session_'
      'while_live', () {
    final Random random = seededRandom(65101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final PairingSession session = randomPairingSession(random, now);
      final PairingSetup setup = buildPairingSetup(
        session: session,
        request: null,
        now: now,
      );

      final PairingSession? active = setup.pairing.findActiveSession();

      expect(identical(active, session), isLiveAt(session, now));
    }
  });

  test('${_typePrefix}_constructor_property_keeps_the_given_request', () {
    final Random random = seededRandom(65102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final PairingRequest request = randomPairingRequest(random);
      final PairingSetup setup = buildPairingSetup(
        session: random.nextBool() ? randomPairingSession(random, now) : null,
        request: request,
        now: now,
      );

      expect(identical(setup.pairing.findPendingRequest(), request), isTrue);
    }
  });

  test('${_typePrefix}_constructor_property_starts_quiet_and_unjoined', () {
    final Random random = seededRandom(65103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);

      expect(setup.notifications.count, 0);
      expect(setup.pairing.findWaitingJoin(), isNull);
    }
  });

  test('${_typePrefix}_find_active_session_property_none_from_the_'
      'expiry_moment_on', () {
    final Random random = seededRandom(65104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final PairingSession session = _sessionEndingNear(random, now);
      final PairingSetup setup = buildPairingSetup(
        session: session,
        request: null,
        now: now,
      );

      final bool isLive = setup.pairing.findActiveSession() != null;

      expect(isLive, session.expiresAt.isAfter(now));
    }
  });

  test('${_typePrefix}_find_active_session_property_reads_are_stable_'
      'and_quiet', () {
    final Random random = seededRandom(65105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);

      final PairingSession? first = setup.pairing.findActiveSession();
      final PairingSession? second = setup.pairing.findActiveSession();

      expect(identical(first, second), isTrue);
      expect(setup.notifications.count, 0);
    }
  });

  test('${_typePrefix}_find_active_session_property_follows_the_model_'
      'over_sequences', () async {
    final Random random = seededRandom(65106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await checkRandomPairingStep(random, setup);
      }
    }
  });

  test('${_typePrefix}_start_pairing_property_lives_five_minutes_from_'
      'now', () async {
    final Random random = seededRandom(65107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);

      final PairingSession session = await setup.pairing.startPairing();

      expect(session.createdAt, setup.now);
      expect(session.expiresAt, setup.now.add(pairingLifetime));
      expect(identical(setup.pairing.findActiveSession(), session), isTrue);
      expect(session.code, isNotEmpty);
    }
  });

  test(
    '${_typePrefix}_start_pairing_property_drops_the_old_request',
    () async {
      final Random random = seededRandom(65108);

      for (int i = 0; i < propertyIterations; i += 1) {
        final DateTime now = randomPairingMoment(random);
        final PairingSetup setup = buildPairingSetup(
          session: liveSessionAt(now),
          request: randomPairingRequest(random),
          now: now,
        );

        await setup.pairing.startPairing();

        expect(setup.pairing.findPendingRequest(), isNull);
        await expectLater(setup.pairing.rejectPairing(), throwsStateError);
        await expectLater(
          setup.pairing.approvePairing(randomApproverWorkspaces(random)),
          throwsStateError,
        );
      }
    },
  );

  test('${_typePrefix}_start_pairing_property_notifies_once_per_new_'
      'code', () async {
    final Random random = seededRandom(65109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final int startCount = 1 + random.nextInt(4);

      for (int start = 0; start < startCount; start += 1) {
        await setup.pairing.startPairing();
      }

      expect(setup.notifications.count, startCount);
      expect(setup.pairing.findActiveSession(), isNotNull);
    }
  });

  test('${_typePrefix}_cancel_pairing_property_clears_a_live_code', () async {
    final Random random = seededRandom(65110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPairingMoment(random);
      final PairingSetup setup = buildPairingSetup(
        session: liveSessionAt(now),
        request: random.nextBool() ? randomPairingRequest(random) : null,
        now: now,
      );

      await setup.pairing.cancelPairing();

      expect(setup.pairing.findActiveSession(), isNull);
      expect(setup.pairing.findPendingRequest(), isNull);
      expect(setup.notifications.count, 1);
    }
  });

  test('${_typePrefix}_cancel_pairing_property_refuses_without_a_live_'
      'code', () async {
    final Random random = seededRandom(65111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final PairingRequest? requestBefore = setup.pairing.findPendingRequest();
      if (setup.pairing.findActiveSession() != null) {
        continue;
      }

      await expectLater(
        setup.pairing.cancelPairing(),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            noShowingPairingCode,
          ),
        ),
      );
      expect(
        identical(setup.pairing.findPendingRequest(), requestBefore),
        isTrue,
      );
      expect(setup.notifications.count, 0);
    }
  });

  test('${_typePrefix}_cancel_pairing_property_a_second_cancel_is_'
      'refused', () async {
    final Random random = seededRandom(65112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      await setup.pairing.startPairing();

      await setup.pairing.cancelPairing();

      await expectLater(setup.pairing.cancelPairing(), throwsStateError);
      expect(setup.pairing.findActiveSession(), isNull);
    }
  });

  test('${_typePrefix}_find_waiting_join_property_none_for_any_seed', () {
    final Random random = seededRandom(65113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);

      expect(setup.pairing.findWaitingJoin(), isNull);
    }
  });

  test('${_typePrefix}_find_waiting_join_property_none_once_a_join_'
      'returns', () async {
    final Random random = seededRandom(65114);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);

      await setup.pairing.joinWithCode(
        serverAddress: null,
        code: '4F7-K2Q',
        deviceName: randomDeviceName(random),
        role: pickOne(random, DeviceRole.values),
      );

      expect(setup.pairing.findWaitingJoin(), isNull);
    }
  });

  test('${_typePrefix}_find_waiting_join_property_none_across_'
      'sequences', () async {
    final Random random = seededRandom(65115);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildRandomPairingSetup(random);
      final int stepCount = random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await checkRandomPairingStep(random, setup);
        expect(setup.pairing.findWaitingJoin(), isNull);
      }
    }
  });
}
