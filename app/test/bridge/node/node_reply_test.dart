import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_reply.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/scripted_node_transport.dart';

enum _ReplyOutcome { value, failure, malformed }

_ReplyOutcome _readReplyOutcome(String replyJson) {
  try {
    readNodeReply(replyJson);
  } on NodeCommandFailure {
    return _ReplyOutcome.failure;
  } on FormatException {
    return _ReplyOutcome.malformed;
  }
  return _ReplyOutcome.value;
}

void main() {
  test('test_read_node_reply_property_returns_the_ok_value', () {
    final Random random = seededRandom(4901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? okValue = randomArbitraryJson(random);

      expect(readNodeReply(encodeSuccessReply(okValue)), equals(okValue));
    }
  });

  test('test_read_node_reply_property_raises_the_node_message', () {
    final Random random = seededRandom(4902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomText(random);

      expect(
        () => readNodeReply(encodeErrorReply(message)),
        throwsA(
          isA<NodeCommandFailure>().having(
            (NodeCommandFailure failure) => failure.message,
            'message',
            message,
          ),
        ),
      );
    }
  });

  test('test_read_node_reply_property_fuzz_raises_defined_errors', () {
    final Random random = seededRandom(4903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String arbitraryText = randomText(random);
      final String arbitraryJson = jsonEncode(randomArbitraryJson(random));

      expect(_readReplyOutcome(arbitraryText), isIn(_ReplyOutcome.values));
      expect(_readReplyOutcome(arbitraryJson), isIn(_ReplyOutcome.values));
    }
  });

  test('test_read_node_reply_property_rejects_replies_without_ok', () {
    final Random random = seededRandom(4904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String replyJson = jsonEncode(<String, Object?>{
        'answer': randomText(random),
      });

      expect(() => readNodeReply(replyJson), throwsFormatException);
    }
  });

  test('test_node_command_failure_to_string_property_shows_message', () {
    final Random random = seededRandom(4905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomText(random);

      expect(NodeCommandFailure(message).toString(), contains(message));
    }
  });
}
