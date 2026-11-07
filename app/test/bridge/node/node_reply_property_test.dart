import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/bridge/node/node_reply.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/hostile_texts.dart';

const int _firstSeed = 6278000;

List<Object?> _randomNonObjects(Random random) {
  return <Object?>[
    null,
    randomHostileText(random),
    random.nextInt(1 << 31),
    random.nextBool(),
    <Object?>[randomArbitraryJson(random)],
  ];
}

void main() {
  test('test_read_node_reply_property_error_wins_over_ok', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomHostileText(random);
      final String replyJson = jsonEncode(<String, Object?>{
        successReplyField: randomArbitraryJson(random),
        errorReplyField: message,
      });

      expect(
        () => readNodeReply(replyJson),
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

  test('test_read_node_reply_property_only_objects_are_replies', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String replyJson = jsonEncode(
        pickOne(random, _randomNonObjects(random)),
      );

      expect(() => readNodeReply(replyJson), throwsFormatException);
    }
  });

  test('test_read_node_reply_property_error_must_be_text', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> nonTexts = <Object?>[
        null,
        random.nextInt(1 << 31),
        random.nextBool(),
        <Object?>[randomHostileText(random)],
        <String, Object?>{'message': randomHostileText(random)},
      ];
      final String replyJson = jsonEncode(<String, Object?>{
        errorReplyField: pickOne(random, nonTexts),
      });

      expect(() => readNodeReply(replyJson), throwsFormatException);
    }
  });

  test('test_read_node_reply_property_spacing_does_not_matter', () {
    final Random random = seededRandom(_firstSeed + 3);
    const JsonEncoder spacedEncoder = JsonEncoder.withIndent('  ');

    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? okValue = randomArbitraryJson(random);
      final String spacedReply = spacedEncoder.convert(<String, Object?>{
        successReplyField: okValue,
      });

      expect(readNodeReply('\n $spacedReply \t'), equals(okValue));
    }
  });
}
