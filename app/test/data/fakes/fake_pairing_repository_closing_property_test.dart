import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/pairing.dart';

import '../../support/random_inputs.dart';
import 'support/pairing_inputs.dart';
import 'support/pairing_steps.dart';

const String _typePrefix = 'test_fake_pairing_repository';

void main() {
  test('${_typePrefix}_close_session_property_notifies_once_per_'
      'ending', () async {
    final Random random = seededRandom(65213);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);

      if (random.nextBool()) {
        await setup.pairing.cancelPairing();
      } else {
        await decidePairingRandomly(random, setup);
      }

      expect(setup.notifications.count, 1);
    }
  });

  test('${_typePrefix}_close_session_property_leaves_nothing_'
      'showing', () async {
    final Random random = seededRandom(65214);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);

      await decidePairingRandomly(random, setup);

      expect(setup.pairing.findActiveSession(), isNull);
      expect(setup.pairing.findPendingRequest(), isNull);
      await expectLater(setup.pairing.cancelPairing(), throwsStateError);
    }
  });

  test('${_typePrefix}_close_session_property_a_new_code_starts_'
      'after', () async {
    final Random random = seededRandom(65215);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSetup setup = buildWaitingPairingSetup(random);
      await decidePairingRandomly(random, setup);

      final PairingSession session = await setup.pairing.startPairing();

      expect(identical(setup.pairing.findActiveSession(), session), isTrue);
      expect(setup.pairing.findPendingRequest(), isNull);
    }
  });
}
