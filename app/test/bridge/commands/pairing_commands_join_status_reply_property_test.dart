import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';
import 'package:agent_orchestration/bridge/commands/pairing_commands.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/hostile_texts.dart';
import '../support/random_account_json.dart';
import '../support/simple_command_properties.dart';
import '../support/wire_contract_checks.dart';

const int _firstSeed = 5917150;
const String _stateField = 'state';
const String _approvedState = 'approved';
const String _fingerprintWordsField = 'fingerprint_words';
const List<String> _accountFields = <String>['device', 'workspaces'];
const Map<String, Type> _viewTypesByState = <String, Type>{
  'waiting': JoinWaiting,
  _approvedState: JoinApproved,
  'rejected': JoinRejected,
  'expired': JoinExpired,
};

JoinStatusView _decodeJoinStatus(Object? replyJson) {
  return const JoinStatusCommand().decodeReply(replyJson);
}

String _randomStateTheNodeNeverSends(Random random) {
  final String knownState = pickOne(random, _viewTypesByState.keys.toList());
  final List<String> strangeStates = <String>[
    knownState.toUpperCase(),
    ' $knownState',
    '$knownState ',
    '${knownState}_',
    randomHostileText(random),
  ];
  return pickOne(random, strangeStates);
}

void main() {
  test('test_join_status_command_decode_reply_property_reads_json_text', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject replyJson = randomJoinStatusJson(random);
      final JoinStatusView view = _decodeJoinStatus(
        rereadThroughWire(replyJson),
      );

      expect(rereadThroughWire(view.toJson()), equals(replyJson));
      expect(
        view.fingerprintWords,
        orderedEquals(replyJson[_fingerprintWordsField]! as List<Object?>),
      );
    }
  });

  test('test_join_status_command_decode_reply_property_'
      'state_picks_the_view', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject replyJson = randomJoinStatusJson(random);
      final String state = replyJson[_stateField]! as String;
      final JoinStatusView view = _decodeJoinStatus(replyJson);

      expect(view.joinState, state);
      expect(view.runtimeType, _viewTypesByState[state]);
    }
  });

  test('test_join_status_command_decode_reply_property_'
      'rejects_odd_states', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String strangeState = _randomStateTheNodeNeverSends(random);
      final JsonObject replyJson = withFieldValue(
        randomJoinStatusJson(random),
        _stateField,
        strangeState,
      );

      expect(
        () => _decodeJoinStatus(replyJson),
        throwsFormatException,
        reason: strangeState,
      );
    }
  });

  test('test_join_status_command_decode_reply_property_'
      'needs_state_and_words', () {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject replyJson = randomJoinStatusJson(random);
      final String field = pickOne(random, <String>[
        _stateField,
        _fingerprintWordsField,
      ]);
      final Object? brokenReply = pickOne(random, nullLookAlikeReplies);

      expect(
        () => _decodeJoinStatus(withoutField(replyJson, field)),
        throwsFormatException,
        reason: field,
      );
      expect(
        () => _decodeJoinStatus(withFieldValue(replyJson, field, null)),
        throwsFormatException,
        reason: field,
      );
      expect(
        () => _decodeJoinStatus(brokenReply),
        throwsFormatException,
        reason: '$brokenReply',
      );
    }
  });

  test('test_join_status_command_decode_reply_property_'
      'approved_needs_the_account', () {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject approvedJson = withFieldValue(
        randomJoinStatusJson(random),
        _stateField,
        _approvedState,
      );
      final JsonObject withoutAccount = withoutField(<String, Object?>{
        ...approvedJson,
        ...randomAccountSummaryJson(random),
      }, pickOne(random, _accountFields));

      expect(
        () => _decodeJoinStatus(withoutAccount),
        throwsFormatException,
        reason: '$withoutAccount',
      );
    }
  });
}
