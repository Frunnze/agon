import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import 'arbitrary_json.dart';
import 'command_shape.dart';
import 'hostile_texts.dart';

typedef TextArgumentCommandBuilder = NodeCommand<Object?> Function(
  String argumentText,
);

const List<Object?> nullLookAlikeReplies = <Object?>[
  '',
  'null',
  0,
  false,
  <Object?>[],
  <Object?>[null],
  <String, Object?>{},
  <String, Object?>{'ok': null},
];

const List<String> _terminalControlTexts = <String>[
  '\u0000',
  '\r',
  '\r\n',
  '\u0003',
  '\u0004',
  '\u001b[A',
  '\u007f',
  '\\u0000',
];

void testNothingReplyProperties({
  required String typeName,
  required int seed,
  required CommandBuilder buildCommand,
}) {
  test('test_${typeName}_decode_reply_property_accepts_a_null_reply', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = buildCommand(random);
      expect(command.decodeReply(null), isNull);
    }
  });

  test('test_${typeName}_decode_reply_property_rejects_any_reply_value', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = buildCommand(random);
      final Object? replyJson = randomArbitraryJson(random);
      if (replyJson == null) {
        continue;
      }

      expect(
        () => command.decodeReply(replyJson),
        throwsFormatException,
        reason: '$replyJson',
      );
    }
  });

  test('test_${typeName}_decode_reply_property_rejects_null_look_alikes', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = buildCommand(random);
      final Object? lookAlikeReply = pickOne(random, nullLookAlikeReplies);

      expect(
        () => command.decodeReply(lookAlikeReply),
        throwsFormatException,
        reason: '$lookAlikeReply',
      );
    }
  });
}

void testTextArgumentProperties({
  required String typeName,
  required int seed,
  required String field,
  required TextArgumentCommandBuilder buildCommand,
}) {
  test('test_${typeName}_arguments_property_sends_only_the_given_text', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String argumentText = randomArgumentText(random);
      final JsonObject arguments = buildCommand(argumentText).arguments;

      expect(arguments, equals(<String, Object?>{field: argumentText}));
    }
  });

  test('test_${typeName}_arguments_property_text_survives_the_wire', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String argumentText = randomArgumentText(random);
      final NodeCommand<Object?> command = buildCommand(argumentText);
      final String wireText = jsonEncode(encodeNodeCommand(command));
      final Object? rereadCommand = jsonDecode(wireText);

      expect(
        rereadCommand,
        equals(<String, Object?>{
          commandNameField: command.name,
          field: argumentText,
        }),
      );
    }
  });

  test(
    'test_${typeName}_arguments_property_different_texts_never_collide',
    () {
      final Random random = seededRandom(seed + 2);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String firstText = randomArgumentText(random);
        final String secondText = _randomNearbyText(random, firstText);
        final String firstWireText = jsonEncode(
          buildCommand(firstText).arguments,
        );
        final String secondWireText = jsonEncode(
          buildCommand(secondText).arguments,
        );

        expect(
          firstWireText == secondWireText,
          firstText == secondText,
          reason: '$firstText / $secondText',
        );
      }
    },
  );
}

String randomArgumentText(Random random) {
  if (random.nextInt(3) == 0) {
    final String controlText = pickOne(random, _terminalControlTexts);
    return '${randomHostileText(random)}$controlText';
  }
  return randomHostileText(random);
}

String _randomNearbyText(Random random, String text) {
  final List<String> nearbyTexts = <String>[
    text,
    '$text ',
    ' $text',
    text.toUpperCase(),
    text.trim(),
    randomArgumentText(random),
  ];
  return pickOne(random, nearbyTexts);
}
