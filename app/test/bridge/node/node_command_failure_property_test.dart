import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';

const int _firstSeed = 6273000;
const String _failurePrefix = 'NodeCommandFailure: ';

void main() {
  test('test_node_command_failure_constructor_property_keeps_message', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomHostileText(random);

      expect(NodeCommandFailure(message).message, message);
    }
  });

  test('test_node_command_failure_constructor_property_is_an_exception', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object failure = NodeCommandFailure(randomHostileText(random));

      expect(failure, isA<Exception>());
      expect(failure, isNot(isA<Error>()));
    }
  });

  test('test_node_command_failure_constructor_property_const_is_shared', () {
    const NodeCommandFailure first = NodeCommandFailure('the node refused');
    const NodeCommandFailure second = NodeCommandFailure('the node refused');

    expect(identical(first, second), isTrue);
  });

  test('test_node_command_failure_to_string_property_prefix_then_message', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomHostileText(random);

      expect(
        NodeCommandFailure(message).toString(),
        '$_failurePrefix$message',
      );
    }
  });

  test('test_node_command_failure_to_string_property_is_stable', () {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommandFailure failure = NodeCommandFailure(
        randomHostileText(random),
      );

      expect(failure.toString(), failure.toString());
    }
  });

  test(
    'test_node_command_failure_to_string_property_tells_messages_apart',
    () {
      final Random random = seededRandom(_firstSeed + 4);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String first = randomHostileText(random);
        final String second = randomHostileText(random);

        expect(
          NodeCommandFailure(first).toString() ==
              NodeCommandFailure(second).toString(),
          first == second,
        );
      }
    },
  );
}
