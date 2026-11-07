import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_reply.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/startup/forgotten_device_problem.dart';

import '../bridge/support/hostile_texts.dart';
import '../bridge/support/scripted_node_transport.dart';
import '../support/random_inputs.dart';

const String _noAccountMessage = 'this device has no account yet';

Object _translateReply(String replyJson) {
  try {
    readNodeReply(replyJson);
  } on NodeCommandFailure catch (failure) {
    return translateNodeFailure(failure);
  }
  throw StateError('the reply $replyJson was not a failure');
}

String _randomMessage(Random random) {
  return pickOne(random, <String>[
    _noAccountMessage,
    randomHostileText(random),
  ]);
}

void main() {
  test(
    'test_is_forgotten_device_problem_property_no_account_kind_is_forgotten',
    () {
      final Random random = seededRandom(47651);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Object problem = _translateReply(
          encodeKindedErrorReply(
            message: _randomMessage(random),
            kind: noAccountFailureKind,
          ),
        );

        expect(isForgottenDeviceProblem(problem), isTrue);
      }
    },
  );

  test(
    'test_is_forgotten_device_problem_property_text_without_kind_is_not',
    () {
      final Random random = seededRandom(47652);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = pickOne(random, <String>[
          _noAccountMessage,
          '$_noAccountMessage${randomHostileText(random)}',
        ]);

        final Object translated = _translateReply(encodeErrorReply(message));

        expect(isForgottenDeviceProblem(translated), isFalse);
        expect(isForgottenDeviceProblem(StateError(message)), isFalse);
      }
    },
  );

  test('test_is_forgotten_device_problem_property_other_kinds_are_not', () {
    final Random random = seededRandom(47653);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String kind = randomHostileText(random);
      if (kind == noAccountFailureKind) {
        continue;
      }

      final Object problem = _translateReply(
        encodeKindedErrorReply(message: _noAccountMessage, kind: kind),
      );

      expect(isForgottenDeviceProblem(problem), isFalse);
    }
  });
}
