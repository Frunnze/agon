import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_account_json.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';
import '../support/wire_name_checks.dart';

const String _stateField = 'state';
const String _wordsField = 'fingerprint_words';
const List<String> _joinStates = <String>[
  'waiting',
  'approved',
  'rejected',
  'expired',
];

const WireFields _joinStatusFields = WireFields(
  requiredFields: <String>[_stateField, _wordsField],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

const WireFields _joinApprovedFields = WireFields(
  requiredFields: <String>[_stateField, _wordsField, 'device', 'workspaces'],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

WireFields _readJoinStatusFields(JsonObject json) {
  if (json[_stateField] == JoinApproved.state) {
    return _joinApprovedFields;
  }
  return _joinStatusFields;
}

JoinStatusView _buildJoinStatus(Random random, List<String> words) {
  final List<JoinStatusView> statuses = <JoinStatusView>[
    JoinWaiting(fingerprintWords: words),
    JoinApproved(
      fingerprintWords: words,
      account: AccountSummary.fromJson(randomAccountSummaryJson(random)),
    ),
    JoinRejected(fingerprintWords: words),
    JoinExpired(fingerprintWords: words),
  ];
  return pickOne(random, statuses);
}

JoinApproved _randomJoinApproved(Random random) {
  return JoinApproved(
    fingerprintWords: randomTextList(random),
    account: AccountSummary.fromJson(randomAccountSummaryJson(random)),
  );
}

String _readExpectedState(JoinStatusView status) {
  return switch (status) {
    JoinWaiting() => 'waiting',
    JoinApproved() => 'approved',
    JoinRejected() => 'rejected',
    JoinExpired() => 'expired',
  };
}

void main() {
  test('test_join_status_view_property_keeps_words_in_order', () {
    final Random random = seededRandom(52101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> words = randomTextList(random);

      final JoinStatusView status = _buildJoinStatus(random, words);

      expect(status.fingerprintWords, orderedEquals(words));
    }
  });

  test('test_join_status_view_property_ignores_later_caller_changes', () {
    final Random random = seededRandom(52102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> words = randomTextList(random);

      final JoinStatusView status = _buildJoinStatus(random, words);

      expectListIgnoresCallerChanges(words, status.fingerprintWords, 'word');
    }
  });

  test('test_join_status_view_property_words_refuse_changes', () {
    final Random random = seededRandom(52103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinStatusView status = _buildJoinStatus(
        random,
        randomTextList(random),
      );

      expectListRefusesChanges(status.fingerprintWords, 'word');
    }
  });

  test('test_join_status_view_from_json_property_state_picks_the_variant', () {
    final Random random = seededRandom(52104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomJoinStatusJson(random);

      final JoinStatusView status = JoinStatusView.fromJson(
        withUnknownFields(random, json),
      );

      expect(_readExpectedState(status), json[_stateField]);
      expect(status.joinState, json[_stateField]);
      expect(
        status.fingerprintWords,
        orderedEquals(json[_wordsField]! as List<Object?>),
      );
      if (status is JoinApproved) {
        final AccountSummary account = AccountSummary.fromJson(json);
        expect(status.account.toJson(), equals(account.toJson()));
      }
    }
  });

  test('test_join_status_view_from_json_property_unknown_states_raise', () {
    final Random random = seededRandom(52105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomJoinStatusJson(random);
      final String state = json[_stateField]!.toString();

      for (final String nearMiss in nearMissWireNames(random, state, 'Join')) {
        if (_joinStates.contains(nearMiss)) {
          continue;
        }
        final JsonObject renamed = withFieldValue(json, _stateField, nearMiss);
        expect(() => JoinStatusView.fromJson(renamed), throwsFormatException);
      }
    }
  });

  test(
    'test_join_status_view_from_json_property_missing_fields_follow_node',
    () {
      final Random random = seededRandom(52106);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomJoinStatusJson(random);

        expectRequiredFieldsAreNeeded(
          json,
          _readJoinStatusFields(json),
          JoinStatusView.fromJson,
        );
      }
    },
  );

  test(
    'test_join_status_view_from_json_property_wrong_kinds_raise_format',
    () {
      final Random random = seededRandom(52107);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectWrongKindValuesAreRejected(
          random,
          randomJoinStatusJson(random),
          JoinStatusView.fromJson,
        );
      }
    },
  );

  test(
    'test_join_status_view_to_json_property_writes_exactly_node_fields',
    () {
      final Random random = seededRandom(52108);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JoinStatusView status = _buildJoinStatus(
          random,
          randomTextList(random),
        );

        final JsonObject encoded = status.toJson();
        final WireFields fields = _readJoinStatusFields(encoded);

        expect(encoded.keys.toSet(), equals(fields.everyField));
      }
    },
  );

  test('test_join_status_view_to_json_property_state_names_the_variant', () {
    final Random random = seededRandom(52109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinStatusView status = _buildJoinStatus(
        random,
        randomTextList(random),
      );

      final JsonObject encoded = status.toJson();

      expect(encoded[_stateField], _readExpectedState(status));
      expect(encoded[_wordsField], orderedEquals(status.fingerprintWords));
    }
  });

  test('test_join_status_view_to_json_property_decodes_back_to_same_kind', () {
    final Random random = seededRandom(52110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinStatusView status = _buildJoinStatus(
        random,
        randomTextList(random),
      );

      final JoinStatusView reread = JoinStatusView.fromJson(
        reencodeThroughText(status),
      );

      expect(reread.runtimeType, status.runtimeType);
      expectPlainJsonThatDecodesBack(status, JoinStatusView.fromJson);
    }
  });

  test('test_join_approved_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomJoinApproved(random).toJson();

      expect(encoded.keys.toSet(), equals(_joinApprovedFields.everyField));
    }
  });

  test('test_join_approved_to_json_property_account_never_hides_state', () {
    final Random random = seededRandom(52112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinApproved status = _randomJoinApproved(random);

      final JsonObject encoded = status.toJson();
      final JsonObject accountJson = status.account.toJson();

      expect(encoded[_stateField], JoinApproved.state);
      expect(encoded[_wordsField], orderedEquals(status.fingerprintWords));
      for (final String accountField in accountJson.keys) {
        expect(encoded[accountField], equals(accountJson[accountField]));
      }
    }
  });

  test('test_join_approved_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoinApproved status = _randomJoinApproved(random);

      final JoinStatusView reread = JoinStatusView.fromJson(
        reencodeThroughText(status),
      );

      expect(reread, isA<JoinApproved>());
      expectPlainJsonThatDecodesBack(status, JoinStatusView.fromJson);
    }
  });
}
