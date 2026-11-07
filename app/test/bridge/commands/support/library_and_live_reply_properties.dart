import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../../support/random_inputs.dart';
import '../../codecs/support/codec_rows.dart';
import '../../support/arbitrary_json.dart';
import '../../support/command_shape.dart';
import '../../support/decoding_outcome.dart';
import '../../support/hostile_texts.dart';
import '../../support/wire_contract_checks.dart';
import 'drafting_and_file_command_properties.dart';

typedef ReplyObjectBuilder = JsonObject Function(Random random);

const int _seedsPerReplyRow = 10;
const int _largestReplyLength = 6;
const int _wholeNumberSpan = 1 << 31;
const String _wrappingField = 'items';

final class ReplyRow {
  const ReplyRow({
    required this.typeName,
    required this.commandName,
    required this.buildObjectJson,
    required this.requiredFields,
  });

  final String typeName;
  final String commandName;
  final ReplyObjectBuilder buildObjectJson;
  final List<String> requiredFields;
}

void testObjectReplyRows(List<ReplyRow> rows, int firstSeed) {
  for (int i = 0; i < rows.length; i += 1) {
    _testObjectReplyProperties(rows[i], firstSeed + i * _seedsPerReplyRow);
  }
}

void testListReplyRows(List<ReplyRow> rows, int firstSeed) {
  for (int i = 0; i < rows.length; i += 1) {
    _testListReplyProperties(rows[i], firstSeed + i * _seedsPerReplyRow);
  }
}

List<Object?> _randomRepliesOfAnotherKind(Random random, Object? replyJson) {
  return <Object?>[
    null,
    randomHostileText(random),
    random.nextInt(_wholeNumberSpan),
    random.nextDouble(),
    random.nextBool(),
    <Object?>[replyJson],
    <String, Object?>{_wrappingField: replyJson},
  ];
}

Object? _reencodeReply({
  required CommandShape shape,
  required NodeCommand<Object?> command,
  required Object? replyJson,
}) {
  final Object? decodedReply = command.decodeReply(replyJson);
  return rereadThroughWire(shape.encodeReply(decodedReply));
}

void _testObjectReplyProperties(ReplyRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_decode_reply_property';
  final CommandShape shape = findCommandShape(row.commandName);

  test('${testPrefix}_round_trips_the_node_reply', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = row.buildObjectJson(random);
      final Object? decodedReply = command.decodeReply(
        rereadThroughWire(replyJson),
      );

      expect(
        rereadThroughWire(shape.encodeReply(decodedReply)),
        equals(replyJson),
      );
    }
  });

  test('${testPrefix}_rejects_a_missing_or_wrong_kind_reply', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = row.buildObjectJson(random);
      final Object? wrongKindReply = pickOne(
        random,
        _randomRepliesOfAnotherKind(random, replyJson),
      );

      for (final String field in row.requiredFields) {
        final JsonObject trimmed = withoutField(replyJson, field);
        final JsonObject nulled = withFieldValue(replyJson, field, null);
        expect(() => command.decodeReply(trimmed), throwsFormatException);
        expect(() => command.decodeReply(nulled), throwsFormatException);
      }
      expect(
        () => command.decodeReply(wrongKindReply),
        throwsFormatException,
        reason: '$wrongKindReply',
      );
    }
  });

  test('${testPrefix}_hostile_replies_raise_only_format_errors', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final Object? mutatedReply = mutateJson(
        random,
        row.buildObjectJson(random),
      );

      final DecodingOutcome outcome = attemptDecoding(
        () => command.decodeReply(mutatedReply),
      );

      if (outcome == DecodingOutcome.decoded) {
        final Object? encodedOnce = _reencodeReply(
          shape: shape,
          command: command,
          replyJson: mutatedReply,
        );
        final Object? encodedTwice = _reencodeReply(
          shape: shape,
          command: shape.buildCommand(random),
          replyJson: encodedOnce,
        );
        expect(encodedTwice, equals(encodedOnce));
      }
    }
  });
}

List<Object?> _randomElementJsons(Random random, ReplyRow row) {
  final int elementCount = random.nextInt(_largestReplyLength);
  final List<Object?> elementJsons = <Object?>[];
  for (int i = 0; i < elementCount; i += 1) {
    elementJsons.add(row.buildObjectJson(random));
  }
  if (elementJsons.isNotEmpty && random.nextBool()) {
    final Object? repeatedElement = pickOne(random, elementJsons);
    elementJsons.insert(random.nextInt(elementCount + 1), repeatedElement);
  }
  return elementJsons;
}

void _testListReplyProperties(ReplyRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_decode_reply_property';
  final CommandShape shape = findCommandShape(row.commandName);

  test('${testPrefix}_keeps_every_element_in_order', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final List<Object?> replyJson = _randomElementJsons(random, row);
      final Object? decodedReply = command.decodeReply(
        rereadThroughWire(replyJson),
      );

      expect(
        rereadThroughWire(shape.encodeReply(decodedReply)),
        equals(replyJson),
      );
    }
  });

  test('${testPrefix}_rejects_one_broken_element', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final List<Object?> replyJson = <Object?>[
        row.buildObjectJson(random),
        ..._randomElementJsons(random, row),
      ];
      final JsonObject brokenElement = withoutField(
        row.buildObjectJson(random),
        pickOne(random, row.requiredFields),
      );
      final List<Object?> brokenElements = <Object?>[brokenElement, null];
      final int brokenIndex = random.nextInt(replyJson.length);
      replyJson[brokenIndex] = pickOne(random, brokenElements);

      expect(() => command.decodeReply(replyJson), throwsFormatException);
    }
  });

  test('${testPrefix}_rejects_replies_that_are_not_lists', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject elementJson = row.buildObjectJson(random);
      final List<Object?> notLists = <Object?>[elementJson];
      for (final Object? reply in _randomRepliesOfAnotherKind(
        random,
        elementJson,
      )) {
        if (reply is! List<Object?>) {
          notLists.add(reply);
        }
      }
      final Object? replyJson = pickOne(random, notLists);

      expect(
        () => command.decodeReply(replyJson),
        throwsFormatException,
        reason: '$replyJson',
      );
    }
  });

  test('${testPrefix}_cannot_be_changed', () {
    final Random random = seededRandom(seed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final List<Object?> replyJson = _randomElementJsons(random, row);
      final Object? decodedReply = command.decodeReply(replyJson);
      final List<Object?> decodedElements = decodedReply! as List<Object?>;
      final Object? extraReply = command.decodeReply(<Object?>[
        row.buildObjectJson(random),
      ]);
      final List<Object?> extraElements = extraReply! as List<Object?>;

      expect(
        () => decodedElements.add(extraElements.single),
        throwsUnsupportedError,
      );
      expect(decodedElements.clear, throwsUnsupportedError);
      expect(decodedElements, hasLength(replyJson.length));
    }
  });
}
