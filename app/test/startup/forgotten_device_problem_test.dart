import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/startup/forgotten_device_problem.dart';

import '../support/random_inputs.dart';

const String _noAccountMessage = 'this device has no account yet';
const List<String> _forgottenDeviceMessages = <String>[
  'the app server answered 401: the device is not paired',
  'the app server answered 403: the device has been revoked',
  _noAccountMessage,
];

const List<String> _otherStartupMessages = <String>[
  'could not reach the app server: connection refused',
  'the app server answered 401: the request signature does not verify',
  'the app server answered 403: only a client device can do this',
  'the app server answered 500: the device is not paired',
  'could not delete the device identity, nothing was forgotten: denied',
];

Object _translate(String nodeMessage) {
  final String? kind = nodeMessage == _noAccountMessage
      ? noAccountFailureKind
      : null;
  return translateNodeFailure(NodeCommandFailure(nodeMessage, kind: kind));
}

Object _wrapInOtherProblem(Random random, String message) {
  final List<Object> otherProblems = <Object>[
    message,
    ArgumentError(message),
    FormatException(message),
    Exception(message),
  ];
  return pickOne(random, otherProblems);
}

void main() {
  test(
    'test_is_forgotten_device_problem_property_unpaired_revoked_or_lost',
    () {
      final Random random = seededRandom(9411);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = pickOne(random, _forgottenDeviceMessages);

        expect(isForgottenDeviceProblem(_translate(message)), isTrue);
      }
    },
  );

  test('test_is_forgotten_device_problem_property_other_answers_are_not', () {
    final Random random = seededRandom(9412);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = pickOne(random, _otherStartupMessages);

      expect(isForgottenDeviceProblem(_translate(message)), isFalse);
    }
  });

  test('test_is_forgotten_device_problem_property_text_must_match_whole', () {
    final Random random = seededRandom(9413);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = pickOne(random, _forgottenDeviceMessages);
      final String noise = 'x${randomText(random)}';

      expect(isForgottenDeviceProblem(_translate('$noise$message')), isFalse);
      expect(isForgottenDeviceProblem(_translate('$message$noise')), isFalse);
    }
  });

  test('test_is_forgotten_device_problem_property_only_node_refusals', () {
    final Random random = seededRandom(9414);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = pickOne(random, _forgottenDeviceMessages);
      final Object problem = _wrapInOtherProblem(random, message);

      expect(isForgottenDeviceProblem(problem), isFalse);
    }
  });

  test('test_is_forgotten_device_problem_property_fuzz_gives_an_answer', () {
    final Random random = seededRandom(9415);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomText(random);
      final bool isKnownMessage = _forgottenDeviceMessages.contains(message);

      expect(isForgottenDeviceProblem(_translate(message)), isKnownMessage);
      expect(
        isForgottenDeviceProblem(_wrapInOtherProblem(random, message)),
        isFalse,
      );
    }
  });
}
