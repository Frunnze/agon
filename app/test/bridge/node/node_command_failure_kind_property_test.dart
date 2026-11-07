import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';

const String _failurePrefix = 'NodeCommandFailure: ';

void main() {
  test(
    'test_node_command_failure_constructor_property_keeps_message_and_kind',
    () {
      final Random random = seededRandom(47611);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = randomHostileText(random);
        final String kind = randomHostileText(random);

        final NodeCommandFailure failure = NodeCommandFailure(
          message,
          kind: kind,
        );

        expect(failure.message, message);
        expect(failure.kind, kind);
      }
    },
  );

  test(
    'test_node_command_failure_constructor_property_kind_only_when_given',
    () {
      final Random random = seededRandom(47612);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = randomHostileText(random);

        expect(NodeCommandFailure(message).kind, isNull);
        expect(
          NodeCommandFailure(message, kind: noAccountFailureKind).kind,
          noAccountFailureKind,
        );
      }
    },
  );

  test(
    'test_node_command_failure_to_string_property_kind_leaves_the_text_alone',
    () {
      final Random random = seededRandom(47613);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = randomHostileText(random);
        final String kind = randomHostileText(random);

        final String kindedText = NodeCommandFailure(
          message,
          kind: kind,
        ).toString();

        expect(kindedText, '$_failurePrefix$message');
        expect(kindedText, NodeCommandFailure(message).toString());
      }
    },
  );
}
