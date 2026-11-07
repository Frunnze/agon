import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import 'support/random_start_configurations.dart';

const int _firstSeed = 6275000;
const String _rustKeychainName = 'keychain';
const String _rustFileName = 'file';
const String _rustEncryptedFileName = 'encrypted_file';
const String _keyField = 'key';
const String _foreignCharacters = 'ABCDEFGHghxyz ٣\n-+';

typedef _PlainStoreRow = ({
  String typeName,
  IdentityStoreSettings store,
  String wireName,
  String rustName,
});

const List<_PlainStoreRow> _plainStoreRows = <_PlainStoreRow>[
  (
    typeName: 'keychain_identity_store',
    store: KeychainIdentityStore(),
    wireName: KeychainIdentityStore.wireName,
    rustName: _rustKeychainName,
  ),
  (
    typeName: 'file_identity_store',
    store: FileIdentityStore(),
    wireName: FileIdentityStore.wireName,
    rustName: _rustFileName,
  ),
];

String _randomBrokenKey(Random random) {
  final List<String> digits = randomIdentityKeyOfLength(
    random,
    identityKeyHexadecimalLength,
  ).split('');
  final int position = random.nextInt(digits.length);
  digits[position] = pickOne(random, _foreignCharacters.split(''));
  return digits.join();
}

void _testPlainStoreRow(_PlainStoreRow row) {
  test('test_${row.typeName}_constructor_property_is_one_constant', () {
    expect(row.store, isA<IdentityStoreSettings>());
    expect(row.store.toJson(), row.store.toJson());
  });

  test('test_${row.typeName}_constructor_property_unlike_other_stores', () {
    for (final _PlainStoreRow otherRow in _plainStoreRows) {
      final bool isSameRow = identical(otherRow.store, row.store);
      expect(otherRow.store.toJson() == row.store.toJson(), isSameRow);
    }
  });

  test('test_${row.typeName}_constructor_property_not_encrypted', () {
    expect(row.store, isNot(isA<EncryptedFileIdentityStore>()));
  });

  test('test_${row.typeName}_to_json_property_is_the_wire_name', () {
    expect(row.store.toJson(), row.wireName);
  });

  test('test_${row.typeName}_to_json_property_survives_the_wire', () {
    expect(rereadThroughWire(row.store.toJson()), row.store.toJson());
  });

  test('test_${row.typeName}_to_json_property_matches_rust', () {
    expect(row.store.toJson(), row.rustName);
  });

  test('test_${row.typeName}_wire_name_property_matches_rust', () {
    expect(row.wireName, row.rustName);
  });

  test('test_${row.typeName}_wire_name_property_is_unique', () {
    final List<String> wireNames = <String>[
      KeychainIdentityStore.wireName,
      FileIdentityStore.wireName,
      EncryptedFileIdentityStore.wireName,
    ];

    expect(
      wireNames.where((String name) => name == row.wireName),
      hasLength(1),
    );
  });

  test('test_${row.typeName}_wire_name_property_is_not_blank', () {
    expect(row.wireName.trim(), row.wireName);
    expect(row.wireName, isNotEmpty);
  });
}

void main() {
  for (final _PlainStoreRow row in _plainStoreRows) {
    _testPlainStoreRow(row);
  }

  test(
    'test_encrypted_file_identity_store_constructor_property_keeps_key',
    () {
      final Random random = seededRandom(_firstSeed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String key = randomIdentityKeyOfLength(
          random,
          identityKeyHexadecimalLength,
        );

        expect(EncryptedFileIdentityStore(key: key).key, key);
      }
    },
  );

  test('test_encrypted_file_identity_store_constructor_property_'
      'never_reveals_the_key', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String brokenKey = _randomBrokenKey(random);

      expect(
        () => EncryptedFileIdentityStore(key: brokenKey),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.toString(),
            'description',
            isNot(contains(brokenKey)),
          ),
        ),
      );
    }
  });

  test('test_encrypted_file_identity_store_constructor_property_'
      'rejects_one_foreign_digit', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String brokenKey = _randomBrokenKey(random);

      expect(
        () => EncryptedFileIdentityStore(key: brokenKey),
        throwsArgumentError,
        reason: brokenKey,
      );
    }
  });

  test('test_encrypted_file_identity_store_to_json_property_nests_key', () {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String key = randomIdentityKeyOfLength(
        random,
        identityKeyHexadecimalLength,
      );

      expect(EncryptedFileIdentityStore(key: key).toJson(), <String, Object?>{
        _rustEncryptedFileName: <String, Object?>{_keyField: key},
      });
    }
  });

  test('test_encrypted_file_identity_store_to_json_property_survives', () {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject encoded = EncryptedFileIdentityStore(
        key: randomIdentityKeyOfLength(random, identityKeyHexadecimalLength),
      ).toJson();

      expect(rereadThroughWire(encoded), equals(encoded));
    }
  });

  test('test_encrypted_file_identity_store_to_json_property_fresh_map', () {
    final Random random = seededRandom(_firstSeed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String key = randomIdentityKeyOfLength(
        random,
        identityKeyHexadecimalLength,
      );
      final EncryptedFileIdentityStore store = EncryptedFileIdentityStore(
        key: key,
      );

      store.toJson().clear();

      expect(
        decodeObject(store.toJson()[_rustEncryptedFileName]),
        <String, Object?>{_keyField: key},
      );
    }
  });

  test(
    'test_encrypted_file_identity_store_wire_name_property_matches_rust',
    () {
      expect(EncryptedFileIdentityStore.wireName, _rustEncryptedFileName);
    },
  );

  test('test_encrypted_file_identity_store_wire_name_property_leads_json', () {
    final Random random = seededRandom(_firstSeed + 6);
    final EncryptedFileIdentityStore store = EncryptedFileIdentityStore(
      key: randomIdentityKeyOfLength(random, identityKeyHexadecimalLength),
    );

    expect(store.toJson().keys, <String>[EncryptedFileIdentityStore.wireName]);
  });

  test('test_encrypted_file_identity_store_wire_name_property_is_unique', () {
    expect(<String>[
      KeychainIdentityStore.wireName,
      FileIdentityStore.wireName,
    ], isNot(contains(EncryptedFileIdentityStore.wireName)));
  });
}
