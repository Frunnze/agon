import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/arbitrary_json.dart';
import '../support/catalog_command_shapes.dart';
import '../support/decoding_outcome.dart';
import '../support/hostile_texts.dart';
import '../support/wire_contract_checks.dart';
import 'support/drafting_and_file_command_properties.dart';
import 'support/local_folder_command_rows.dart';

const int _firstSeed = 6065000;
const int _seedsPerRow = 10;
const String _addressField = 'address';
const String _branchField = 'default_branch';
const String _startedGitField = 'has_started_git';
const List<String> _textFields = <String>[_addressField, _branchField];
const List<Object?> _flagLookAlikes = <Object?>[
  'true',
  'false',
  1,
  0,
  '',
  <Object?>[],
];

void main() {
  for (int i = 0; i < localFolderCommandRows.length; i += 1) {
    final ModelledCommandRow row = localFolderCommandRows[i];
    _testDecodeReplyProperties(row, _firstSeed + i * _seedsPerRow);
  }
}

List<JsonObject> _randomBrokenReplies(Random random, JsonObject replyJson) {
  final List<JsonObject> brokenReplies = <JsonObject>[];
  for (final String field in replyJson.keys) {
    brokenReplies.add(withoutField(replyJson, field));
    brokenReplies.add(withFieldValue(replyJson, field, null));
  }
  final Object? flagLookAlike = pickOne(random, _flagLookAlikes);
  brokenReplies.add(
    withFieldValue(replyJson, _startedGitField, flagLookAlike),
  );
  final String textField = pickOne(random, _textFields);
  brokenReplies.add(
    withFieldValue(replyJson, textField, random.nextInt(1 << 31)),
  );
  brokenReplies.add(
    withFieldValue(replyJson, textField, <Object?>[replyJson[textField]]),
  );
  return brokenReplies;
}

void _testDecodeReplyProperties(ModelledCommandRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_decode_reply_property';

  test('${testPrefix}_keeps_every_reply_field', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.build(random).command;
      final JsonObject replyJson = randomCheckedLocalFolderJson(random);
      final Object? decodedReply = command.decodeReply(
        rereadThroughWire(replyJson),
      );

      expect(encodeCheckedLocalFolderReply(decodedReply), equals(replyJson));
    }
  });

  test('${testPrefix}_rejects_missing_null_or_wrong_kind_fields', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.build(random).command;
      final JsonObject replyJson = randomCheckedLocalFolderJson(random);
      final List<Object?> wrongKindReplies = <Object?>[
        null,
        randomHostileText(random),
        random.nextBool(),
        <Object?>[replyJson],
      ];

      for (final JsonObject brokenReply in _randomBrokenReplies(
        random,
        replyJson,
      )) {
        expect(
          () => command.decodeReply(brokenReply),
          throwsFormatException,
          reason: '$brokenReply',
        );
      }
      expect(
        () => command.decodeReply(pickOne(random, wrongKindReplies)),
        throwsFormatException,
      );
    }
  });

  test('${testPrefix}_hostile_replies_raise_only_format_errors', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = row.build(random).command;
      final Object? mutatedReply = mutateJson(
        random,
        randomCheckedLocalFolderJson(random),
      );

      final DecodingOutcome outcome = attemptDecoding(
        () => command.decodeReply(mutatedReply),
      );

      if (outcome == DecodingOutcome.decoded) {
        final JsonObject decodedFields = encodeCheckedLocalFolderReply(
          command.decodeReply(mutatedReply),
        );
        final JsonObject mutatedFields = mutatedReply! as JsonObject;
        for (final String field in decodedFields.keys) {
          expect(decodedFields[field], equals(mutatedFields[field]));
        }
      }
    }
  });

  test('${testPrefix}_ignores_the_command_fields', () {
    final Random random = seededRandom(seed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> first = row.build(random).command;
      final NodeCommand<Object?> second = row.build(random).command;
      final JsonObject replyJson = withUnknownFields(
        random,
        randomCheckedLocalFolderJson(random),
      );

      expect(
        encodeCheckedLocalFolderReply(second.decodeReply(replyJson)),
        equals(encodeCheckedLocalFolderReply(first.decodeReply(replyJson))),
      );
    }
  });
}
