import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/pairing.dart';

import '../../support/random_inputs.dart';

const List<String> _untrimmedProblems = <String>[
  '',
  '  no peer endpoint  ',
  '\tthe relay is down\n',
  'Ünïcødé 🚧',
];

PairingSession _randomSession(Random random, String? rendezvousProblem) {
  final DateTime createdAt = randomUtcMoment(random);
  return PairingSession(
    code: randomText(random),
    createdAt: createdAt,
    expiresAt: createdAt.add(Duration(seconds: random.nextInt(600))),
    rendezvousProblem: rendezvousProblem,
  );
}

void main() {
  test('test_pairing_session_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(73401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String code = randomText(random);
      final DateTime createdAt = randomUtcMoment(random);
      final DateTime expiresAt = randomUtcMoment(random);
      final String problem = randomText(random);

      final PairingSession session = PairingSession(
        code: code,
        createdAt: createdAt,
        expiresAt: expiresAt,
        rendezvousProblem: problem,
      );

      expect(session.code, code);
      expect(session.createdAt, createdAt);
      expect(session.expiresAt, expiresAt);
      expect(session.rendezvousProblem, problem);
    }
  });

  test('test_pairing_session_constructor_property_'
      'keeps_rendezvous_problem_text_exactly', () {
    final Random random = seededRandom(73402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = pickOne(random, _untrimmedProblems);

      final PairingSession session = _randomSession(random, problem);

      expect(session.rendezvousProblem, problem);
      expect(session.rendezvousProblem?.length, problem.length);
    }
  });

  test('test_pairing_session_constructor_property_'
      'allows_a_code_without_rendezvous_problem', () {
    final Random random = seededRandom(73403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingSession session = _randomSession(random, null);

      expect(session.rendezvousProblem, isNull);
      expect(session.expiresAt.isBefore(session.createdAt), isFalse);
    }
  });
}
