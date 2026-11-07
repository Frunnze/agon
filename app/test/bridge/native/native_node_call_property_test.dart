import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';
import 'package:agent_orchestration/bridge/native/native_node_call.dart';
import 'package:agent_orchestration/bridge/native/node_entry_point.dart';
import 'package:agent_orchestration/bridge/node/node_reply.dart';

import '../../support/random_inputs.dart';
import '../support/all_command_shapes.dart';
import '../support/arbitrary_json.dart';
import '../support/command_shape.dart';
import '../support/hostile_texts.dart';
import 'support/bundled_node_library.dart';

const int _firstSeed = 6269000;
const int _sequenceLength = 30;
const int _shortestLongText = 10000;
const int _longTextSpan = 90000;
const int _longTextIterations = 8;
const String _echoAlphabet =
    'abcxyzABCXYZ0123456789 .,:;!?-_()[]{}<>@#%&*+=~'
    'éüßñЖжΩπ中文字😀🎉🚀';

enum _NodeCall { command, badStart, stop }

String _callNode(NodeEntryPoint entryPoint, String inputJson) {
  return callNodeEntryPoint(
    source: bundledLibraryFile(),
    entryPoint: entryPoint,
    inputJson: inputJson,
  );
}

JsonObject _readReplyObject(String replyJson) {
  return decodeObject(jsonDecode(replyJson));
}

String _readErrorMessage(String replyJson) {
  final JsonObject reply = _readReplyObject(replyJson);
  expect(reply.keys, <String>[errorReplyField]);
  return reply[errorReplyField]! as String;
}

String _randomCommandInput(Random random) {
  if (random.nextBool()) {
    return randomHostileText(random);
  }
  final CommandShape shape = pickOne(random, allCommandShapes);
  return jsonEncode(encodeNodeCommand(shape.buildCommand(random)));
}

String _randomBadConfiguration(Random random) {
  final List<String> configurations = <String>[
    jsonEncode(<Object?>[randomArbitraryJson(random)]),
    jsonEncode(randomHostileText(random)),
    randomHostileText(random),
  ];
  return pickOne(random, configurations);
}

String _randomEchoText(Random random, int length) {
  final List<int> runes = _echoAlphabet.runes.toList();
  final StringBuffer text = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    text.writeCharCode(pickOne(random, runes));
  }
  return text.toString();
}

void _expectStoppedReply(_NodeCall call, String replyJson) {
  switch (call) {
    case _NodeCall.command:
      expect(
        _readErrorMessage(replyJson),
        startsWith(notStartedMessagePrefix),
      );
    case _NodeCall.badStart:
      expect(
        _readErrorMessage(replyJson),
        contains(invalidConfigurationMessage),
      );
    case _NodeCall.stop:
      expect(_readReplyObject(replyJson), <String, Object?>{
        successReplyField: null,
      });
  }
}

String _makeCall(Random random, _NodeCall call) {
  return switch (call) {
    _NodeCall.command => _callNode(
      NodeEntryPoint.handleCommand,
      _randomCommandInput(random),
    ),
    _NodeCall.badStart => _callNode(
      NodeEntryPoint.start,
      _randomBadConfiguration(random),
    ),
    _NodeCall.stop => callNodeStop(bundledLibraryFile()),
  };
}

void main() {
  final String? skipReason = readBundledLibrarySkipReason();

  test('test_call_node_entry_point_property_refuses_before_start', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      _expectStoppedReply(
        _NodeCall.command,
        _makeCall(random, _NodeCall.command),
      );
    }
  }, skip: skipReason);

  test('test_call_node_entry_point_property_refuses_bad_configurations', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String startReply = _makeCall(random, _NodeCall.badStart);
      final String commandReply = _makeCall(random, _NodeCall.command);

      _expectStoppedReply(_NodeCall.badStart, startReply);
      _expectStoppedReply(_NodeCall.command, commandReply);
    }
  }, skip: skipReason);

  test('test_call_node_entry_point_property_reply_has_one_field', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeEntryPoint entryPoint = pickOne(random, NodeEntryPoint.values);
      final JsonObject reply = _readReplyObject(
        _callNode(entryPoint, _randomCommandInput(random)),
      );

      expect(reply, hasLength(1));
      expect(<String>[
        successReplyField,
        errorReplyField,
      ], contains(reply.keys.single));
    }
  }, skip: skipReason);

  test('test_call_node_stop_property_replies_ok_null_every_time', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      _expectStoppedReply(_NodeCall.stop, callNodeStop(bundledLibraryFile()));
    }
  }, skip: skipReason);

  test('test_call_node_stop_property_stopped_node_stays_stopped', () {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_NodeCall> calls = <_NodeCall>[];
      for (int j = 0; j < _sequenceLength; j += 1) {
        calls.add(pickOne(random, _NodeCall.values));
      }

      for (final _NodeCall call in calls) {
        _expectStoppedReply(call, _makeCall(random, call));
      }
    }
  }, skip: skipReason);

  test('test_call_node_stop_property_reply_reads_as_nothing', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object? okValue = readNodeReply(
        callNodeStop(bundledLibraryFile()),
      );

      expect(okValue, isNull);
      expect(() => decodeNothing(okValue), returnsNormally);
    }
  }, skip: skipReason);

  test('test_take_reply_property_keeps_multibyte_text_intact', () {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String echoText = _randomEchoText(random, 1 + random.nextInt(60));
      final String reply = _callNode(
        NodeEntryPoint.start,
        jsonEncode(echoText),
      );

      expect(_readErrorMessage(reply), contains(echoText));
    }
  }, skip: skipReason);

  test('test_take_reply_property_long_replies_arrive_whole', () {
    final Random random = seededRandom(_firstSeed + 5);

    for (int i = 0; i < _longTextIterations; i += 1) {
      final int length = _shortestLongText + random.nextInt(_longTextSpan);
      final String echoText = _randomEchoText(random, length);
      final String reply = _callNode(
        NodeEntryPoint.start,
        jsonEncode(echoText),
      );

      expect(_readErrorMessage(reply), contains(echoText));
    }
  }, skip: skipReason);

  test('test_take_reply_property_each_reply_is_its_own', () {
    final Random random = seededRandom(_firstSeed + 6);
    String previousText = '';

    for (int i = 0; i < propertyIterations; i += 1) {
      final String echoText = '$i:${_randomEchoText(random, 12)}';
      final String reply = _callNode(
        NodeEntryPoint.start,
        jsonEncode(echoText),
      );
      final String message = _readErrorMessage(reply);

      expect(message, contains(echoText));
      if (previousText.isNotEmpty) {
        expect(message, isNot(contains(previousText)));
      }
      previousText = echoText;
    }
  }, skip: skipReason);
}
