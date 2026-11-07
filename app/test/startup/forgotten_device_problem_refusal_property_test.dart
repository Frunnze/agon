import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/startup/forgotten_device_problem.dart';

import '../support/random_app_server_refusals.dart';
import '../support/random_inputs.dart';

typedef _ForgottenRefusal = ({int status, String reason});

const List<_ForgottenRefusal> _forgottenRefusals = <_ForgottenRefusal>[
  (status: 401, reason: 'the device is not paired'),
  (status: 403, reason: 'the device has been revoked'),
];
const String _noAccountProblem = 'this device has no account yet';

Object _translate(String nodeMessage) {
  return translateNodeFailure(NodeCommandFailure(nodeMessage));
}

void main() {
  test(
    'test_is_forgotten_device_problem_property_reads_status_and_reason',
    () {
      final Random random = seededRandom(76301);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _ForgottenRefusal forgotten = pickOne(
          random,
          _forgottenRefusals,
        );
        final String nodeMessage = renderRefusalMessage(
          status: forgotten.status,
          reason: forgotten.reason,
        );

        final Object problem = _translate(nodeMessage);

        expect(isForgottenDeviceProblem(problem), isTrue);
        expect(
          isForgottenDeviceProblem(
            translateNodeFailure(
              const NodeCommandFailure(
                _noAccountProblem,
                kind: noAccountFailureKind,
              ),
            ),
          ),
          isTrue,
        );
      }
    },
  );

  test('test_is_forgotten_device_problem_property_status_must_match', () {
    final Random random = seededRandom(76302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ForgottenRefusal forgotten = pickOne(random, _forgottenRefusals);
      final RandomRefusal refusal = randomRefusalWithReason(
        random,
        pickOne(random, <String>[forgotten.reason, _noAccountProblem]),
      );
      final bool isForgottenAnswer = _forgottenRefusals.contains((
        status: refusal.status,
        reason: refusal.reason,
      ));

      final Object problem = _translate(refusal.nodeMessage);

      expect(isForgottenDeviceProblem(problem), isForgottenAnswer);
    }
  });

  test(
    'test_is_forgotten_device_problem_property_reasons_need_the_status',
    () {
      final Random random = seededRandom(76303);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _ForgottenRefusal forgotten = pickOne(
          random,
          _forgottenRefusals,
        );
        final RandomRefusal other = randomRefusal(random);
        final AppServerRefusal otherReason = AppServerRefusal(
          status: forgotten.status,
          reason: other.reason,
        );

        expect(
          isForgottenDeviceProblem(StateError(forgotten.reason)),
          isFalse,
        );
        expect(isForgottenDeviceProblem(otherReason), isFalse);
      }
    },
  );
}
