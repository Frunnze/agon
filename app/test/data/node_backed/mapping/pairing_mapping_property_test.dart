import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/random_account_json.dart';
import '../../../support/random_inputs.dart';

node.PairingRequestScreen _randomScreen(Random random) {
  return node.PairingRequestScreen.fromJson(
    randomPairingRequestScreenJson(random),
  );
}

void main() {
  test('test_map_pairing_session_from_node_property_'
      'keeps_rendezvous_problem', () {
    final Random random = seededRandom(73301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomText(random);

      final PairingSession session = mapPairingSessionFromNode(
        _randomScreen(random),
        rendezvousProblem: problem,
      );

      expect(session.rendezvousProblem, problem);
    }
  });

  test('test_map_pairing_session_from_node_property_'
      'no_rendezvous_problem_stays_none', () {
    final Random random = seededRandom(73302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSession session = mapPairingSessionFromNode(
        _randomScreen(random),
        rendezvousProblem: null,
      );

      expect(session.rendezvousProblem, isNull);
    }
  });

  test('test_map_pairing_session_from_node_property_'
      'rendezvous_problem_leaves_the_code_and_countdown_alone', () {
    final Random random = seededRandom(73303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.PairingRequestScreen screen = _randomScreen(random);

      final PairingSession withoutProblem = mapPairingSessionFromNode(
        screen,
        rendezvousProblem: null,
      );
      final PairingSession withProblem = mapPairingSessionFromNode(
        screen,
        rendezvousProblem: randomText(random),
      );

      expect(withProblem.code, withoutProblem.code);
      expect(withProblem.code, screen.displayCode);
      expect(withProblem.createdAt, withoutProblem.createdAt);
      expect(withProblem.expiresAt, withoutProblem.expiresAt);
    }
  });
}
