import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_account_json.dart';
import '../support/wire_contract_checks.dart';

const WireFields _pairingRequestScreenFields = WireFields(
  requiredFields: <String>['code', 'display_code', 'started_at', 'expires_at'],
  optionalFields: <String>['joining'],
  defaultedListFields: <String>[],
);

PairingRequestScreen _randomLocalPairingRequestScreen(Random random) {
  final bool hasJoining = random.nextBool();
  return PairingRequestScreen(
    code: randomText(random),
    displayCode: randomText(random),
    startedAt: randomLocalMoment(random),
    expiresAt: randomLocalMoment(random),
    joining: hasJoining
        ? JoiningDevice.fromJson(randomJoiningDeviceJson(random))
        : null,
  );
}

void main() {
  test(
    'test_pairing_request_screen_from_json_property_missing_fields_follow',
    () {
      final Random random = seededRandom(52010);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomPairingRequestScreenJson(random);

        expectRequiredFieldsAreNeeded(
          json,
          _pairingRequestScreenFields,
          PairingRequestScreen.fromJson,
        );
        expectOptionalFieldsMayBeLeftOut(
          random,
          json,
          _pairingRequestScreenFields,
          PairingRequestScreen.fromJson,
        );
      }
    },
  );

  test(
    'test_pairing_request_screen_from_json_property_wrong_kinds_raise_format',
    () {
      final Random random = seededRandom(52011);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectWrongKindValuesAreRejected(
          random,
          randomPairingRequestScreenJson(random),
          PairingRequestScreen.fromJson,
        );
      }
    },
  );

  test(
    'test_pairing_request_screen_from_json_property_reads_each_field_by_name',
    () {
      final Random random = seededRandom(52012);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomPairingRequestScreenJson(random);

        final PairingRequestScreen screen = PairingRequestScreen.fromJson(
          withUnknownFields(random, json),
        );

        expect(screen.code, json['code']);
        expect(screen.displayCode, json['display_code']);
        expectSameMoment(screen.startedAt, json['started_at']);
        expectSameMoment(screen.expiresAt, json['expires_at']);
        expect(screen.joining?.toJson(), json['joining']);
      }
    },
  );

  test(
    'test_pairing_request_screen_to_json_property_writes_exactly_node_fields',
    () {
      final Random random = seededRandom(52013);

      for (int i = 0; i < propertyIterations; i += 1) {
        final PairingRequestScreen screen = _randomLocalPairingRequestScreen(
          random,
        );

        final Set<String> fields = screen.toJson().keys.toSet();

        expect(fields, equals(_pairingRequestScreenFields.everyField));
      }
    },
  );

  test('test_pairing_request_screen_to_json_property_moments_are_utc', () {
    final Random random = seededRandom(52014);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingRequestScreen screen = _randomLocalPairingRequestScreen(
        random,
      );

      final JsonObject encoded = screen.toJson();

      expectUtcMomentText(encoded['started_at'], screen.startedAt);
      expectUtcMomentText(encoded['expires_at'], screen.expiresAt);
      expect(encoded['joining'], screen.joining?.toJson());
    }
  });

  test(
    'test_pairing_request_screen_to_json_property_plain_json_decodes_back',
    () {
      final Random random = seededRandom(52015);

      for (int i = 0; i < propertyIterations; i += 1) {
        expectPlainJsonThatDecodesBack(
          _randomLocalPairingRequestScreen(random),
          PairingRequestScreen.fromJson,
        );
      }
    },
  );
}
