import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';

import '../../support/random_inputs.dart';
import '../support/node_json_primitives.dart';
import '../support/random_account_json.dart';
import '../support/random_wire_values.dart';
import '../support/wire_contract_checks.dart';

const WireFields _joiningDeviceFields = WireFields(
  requiredFields: <String>[
    'name',
    'role',
    'kind',
    'key_kind',
    'sealing_public_key',
    'fingerprint_words',
  ],
  optionalFields: <String>[],
  defaultedListFields: <String>[],
);

JoiningDevice _buildJoiningDevice(
  Random random,
  List<int> sealingPublicKey,
  List<String> fingerprintWords,
) {
  return JoiningDevice(
    name: randomText(random),
    role: pickOne(random, DeviceRole.values),
    kind: pickOne(random, DeviceKind.values),
    keyKind: pickOne(random, HardwareKeyKind.values),
    sealingPublicKey: sealingPublicKey,
    fingerprintWords: fingerprintWords,
  );
}

JoiningDevice _randomJoiningDevice(Random random) {
  return _buildJoiningDevice(
    random,
    randomBytes(random),
    randomTextList(random),
  );
}

void main() {
  test('test_joining_device_property_keeps_key_and_words_in_order', () {
    final Random random = seededRandom(52001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> key = randomBytes(random);
      final List<String> words = randomTextList(random);

      final JoiningDevice device = _buildJoiningDevice(random, key, words);

      expect(device.sealingPublicKey, orderedEquals(key));
      expect(device.fingerprintWords, orderedEquals(words));
    }
  });

  test('test_joining_device_property_ignores_later_caller_changes', () {
    final Random random = seededRandom(52002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> key = randomBytes(random);
      final List<String> words = randomTextList(random);

      final JoiningDevice device = _buildJoiningDevice(random, key, words);

      expectListIgnoresCallerChanges(key, device.sealingPublicKey, 7);
      expectListIgnoresCallerChanges(words, device.fingerprintWords, 'word');
    }
  });

  test('test_joining_device_property_lists_refuse_changes', () {
    final Random random = seededRandom(52003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoiningDevice device = _randomJoiningDevice(random);

      expectListRefusesChanges(device.sealingPublicKey, 7);
      expectListRefusesChanges(device.fingerprintWords, 'word');
    }
  });

  test(
    'test_joining_device_from_json_property_missing_fields_follow_node',
    () {
      final Random random = seededRandom(52004);

      for (int i = 0; i < propertyIterations; i += 1) {
        final JsonObject json = randomJoiningDeviceJson(random);

        expectRequiredFieldsAreNeeded(
          json,
          _joiningDeviceFields,
          JoiningDevice.fromJson,
        );
      }
    },
  );

  test('test_joining_device_from_json_property_wrong_kinds_raise_format', () {
    final Random random = seededRandom(52005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomJoiningDeviceJson(random);

      expectWrongKindValuesAreRejected(random, json, JoiningDevice.fromJson);
    }
  });

  test('test_joining_device_from_json_property_reads_each_field_by_name', () {
    final Random random = seededRandom(52006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject json = randomJoiningDeviceJson(random);

      final JoiningDevice device = JoiningDevice.fromJson(
        withUnknownFields(random, json),
      );

      expect(device.name, json['name']);
      expect(device.role.wireName, json['role']);
      expect(device.keyKind.wireName, json['key_kind']);
      expect(
        device.sealingPublicKey,
        orderedEquals(json['sealing_public_key']! as List<Object?>),
      );
      expect(
        device.fingerprintWords,
        orderedEquals(json['fingerprint_words']! as List<Object?>),
      );
    }
  });

  test('test_joining_device_to_json_property_writes_exactly_node_fields', () {
    final Random random = seededRandom(52007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = _randomJoiningDevice(random).toJson();

      expect(encoded.keys.toSet(), equals(_joiningDeviceFields.everyField));
    }
  });

  test('test_joining_device_to_json_property_values_mirror_the_device', () {
    final Random random = seededRandom(52008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JoiningDevice device = _randomJoiningDevice(random);

      final JsonObject encoded = device.toJson();

      expect(encoded['name'], device.name);
      expect(encoded['role'], device.role.wireName);
      expect(encoded['key_kind'], device.keyKind.wireName);
      expect(
        encoded['sealing_public_key'],
        orderedEquals(device.sealingPublicKey),
      );
      expect(
        encoded['fingerprint_words'],
        orderedEquals(device.fingerprintWords),
      );
    }
  });

  test('test_joining_device_to_json_property_plain_json_decodes_back', () {
    final Random random = seededRandom(52009);

    for (int i = 0; i < propertyIterations; i += 1) {
      expectPlainJsonThatDecodesBack(
        _randomJoiningDevice(random),
        JoiningDevice.fromJson,
      );
    }
  });
}
