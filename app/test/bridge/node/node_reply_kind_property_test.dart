import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_reply.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/hostile_texts.dart';
import '../support/scripted_node_transport.dart';

const String _errorField = 'error';
const String _errorKindField = 'error_kind';

NodeCommandFailure _readFailure(String replyJson) {
  try {
    readNodeReply(replyJson);
  } on NodeCommandFailure catch (failure) {
    return failure;
  }
  throw StateError('the reply $replyJson was not a failure');
}

Object _randomJsonThatIsNotText(Random random) {
  while (true) {
    final Object? json = randomArbitraryJson(random);
    if (json != null && json is! String) {
      return json;
    }
  }
}

void main() {
  test('test_read_node_reply_property_raises_the_node_kind', () {
    final Random random = seededRandom(47621);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomHostileText(random);
      final String kind = pickOne(random, <String>[
        noAccountFailureKind,
        randomHostileText(random),
      ]);

      final NodeCommandFailure failure = _readFailure(
        encodeKindedErrorReply(message: message, kind: kind),
      );

      expect(failure.message, message);
      expect(failure.kind, kind);
    }
  });

  test('test_read_node_reply_property_a_missing_kind_reads_as_none', () {
    final Random random = seededRandom(47622);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomHostileText(random);
      final String nullKindReply = jsonEncode(<String, Object?>{
        _errorField: message,
        _errorKindField: null,
      });

      final NodeCommandFailure plain = _readFailure(encodeErrorReply(message));
      final NodeCommandFailure nullKind = _readFailure(nullKindReply);

      expect(plain.message, message);
      expect(plain.kind, isNull);
      expect(nullKind.message, message);
      expect(nullKind.kind, isNull);
    }
  });

  test('test_read_node_reply_property_a_kind_must_be_text', () {
    final Random random = seededRandom(47623);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String replyJson = jsonEncode(<String, Object?>{
        _errorField: randomHostileText(random),
        _errorKindField: _randomJsonThatIsNotText(random),
      });

      expect(() => readNodeReply(replyJson), throwsFormatException);
    }
  });
}
