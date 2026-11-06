import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_run_json.dart';
import '../support/wire_contract_checks.dart';
import '../support/wire_name_checks.dart';

const WireFields _logLineFields = WireFields(
  requiredFields: <String>['at', 'step_name', 'text', 'is_error'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields _chatMessageFields = WireFields(
  requiredFields: <String>[
    'at',
    'author',
    'text',
    'is_error',
    'waiting_to_send',
  ],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

LogLine _randomLocalLogLine(Random random) {
  return LogLine(
    at: randomLocalMoment(random),
    stepName: randomText(random),
    text: randomText(random),
    isError: random.nextBool(),
  );
}

ChatMessage _randomLocalChatMessage(Random random) {
  return ChatMessage(
    at: randomLocalMoment(random),
    author: pickOne(random, ChatAuthor.values),
    text: randomText(random),
    isError: random.nextBool(),
    waitingToSend: random.nextBool(),
  );
}

void main() {
  test('test_chat_author_decode_property_reads_every_wire_name', () {
    expectDecodesEveryWireName(ChatAuthor.values, ChatAuthor.decode);
  });

  test('test_chat_author_decode_property_rejects_near_misses', () {
    final Random random = seededRandom(52801);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsNearMissWireNames(
        random,
        ChatAuthor.values,
        ChatAuthor.decode,
      );
    }
  });

  test('test_chat_author_decode_property_rejects_non_text', () {
    final Random random = seededRandom(52802);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRejectsWireNamesOfAnotherKind(
        random,
        ChatAuthor.values,
        ChatAuthor.decode,
      );
    }
  });

  test('test_log_line_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(52803);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRequiredFieldsAreNeeded(
        randomLogLineJson(random),
        _logLineFields,
        LogLine.fromJson,
      );
    }
  });

  test('test_log_line_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(52804);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomLogLineJson(random),
        LogLine.fromJson,
      );
    }
  });

  test('test_log_line_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(52805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomLogLineJson(random);

      final LogLine line = LogLine.fromJson(withUnknownFields(random, json));

      expectSameMoment(line.at, json['at']);
      expect(line.stepName, json['step_name']);
      expect(line.text, json['text']);
      expect(line.isError, json['is_error']);
    }
  });

  test('test_log_line_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52806);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomLocalLogLine(random).toJson();

      expect(encoded.keys.toSet(), equals(_logLineFields.everyField));
    }
  });

  test('test_log_line_to_json_property_values_mirror_the_line_in_utc', () {
    final Random random = seededRandom(52807);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LogLine line = _randomLocalLogLine(random);

      final JsonObject encoded = line.toJson();

      expectUtcMomentText(encoded['at'], line.at);
      expect(encoded['step_name'], line.stepName);
      expect(encoded['text'], line.text);
      expect(encoded['is_error'], line.isError);
    }
  });

  test('test_log_line_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52808);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomLocalLogLine(random),
        LogLine.fromJson,
      );
    }
  });

  test('test_chat_message_from_json_property_missing_fields_follow_node', () {
    final Random random = seededRandom(52809);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectRequiredFieldsAreNeeded(
        randomChatMessageJson(random),
        _chatMessageFields,
        ChatMessage.fromJson,
      );
    }
  });

  test('test_chat_message_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(52810);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectWrongKindValuesAreRejected(
        random,
        randomChatMessageJson(random),
        ChatMessage.fromJson,
      );
    }
  });

  test('test_chat_message_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(52811);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomChatMessageJson(random);

      final ChatMessage message = ChatMessage.fromJson(
        withUnknownFields(random, json),
      );

      expectSameMoment(message.at, json['at']);
      expect(message.author.wireName, json['author']);
      expect(message.text, json['text']);
      expect(message.isError, json['is_error']);
      expect(message.waitingToSend, json['waiting_to_send']);
    }
  });

  test('test_chat_message_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52812);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomLocalChatMessage(random).toJson();

      expect(encoded.keys.toSet(), equals(_chatMessageFields.everyField));
    }
  });

  test('test_chat_message_to_json_property_values_mirror_message_in_utc', () {
    final Random random = seededRandom(52813);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatMessage message = _randomLocalChatMessage(random);

      final JsonObject encoded = message.toJson();

      expectUtcMomentText(encoded['at'], message.at);
      expect(encoded['author'], message.author.wireName);
      expect(encoded['text'], message.text);
      expect(encoded['is_error'], message.isError);
      expect(encoded['waiting_to_send'], message.waitingToSend);
    }
  });

  test('test_chat_message_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52814);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomLocalChatMessage(random),
        ChatMessage.fromJson,
      );
    }
  });
}
