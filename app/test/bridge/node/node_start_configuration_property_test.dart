import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/hostile_texts.dart';
import 'support/random_start_configurations.dart';

const int _firstSeed = 6276000;
const int _keyLengthSpread = 3;
const int _largestOutsidePortDistance = 1 << 31;
const String _keyAlphabet = '0123456789abcdefABCDEFg٣ \n';
const String _portField = 'app_server_port';
final RegExp _snakeCaseName = RegExp(r'^[a-z]+(_[a-z]+)*$');
const Map<PeerRelayChoice, String> _rustPeerRelayNames =
    <PeerRelayChoice, String>{
      PeerRelayChoice.defaultRelay: 'default',
      PeerRelayChoice.disabled: 'disabled',
    };

bool _isLowercaseHexadecimal(String text) {
  for (final String character in text.split('')) {
    if (!lowercaseHexadecimalDigits.contains(character)) {
      return false;
    }
  }
  return true;
}

String _randomKeyLikeText(Random random) {
  final int length =
      identityKeyHexadecimalLength -
      _keyLengthSpread +
      random.nextInt(2 * _keyLengthSpread + 1);
  final StringBuffer text = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    final bool usesLowercaseDigit = random.nextInt(8) != 0;
    final String alphabet = usesLowercaseDigit
        ? lowercaseHexadecimalDigits
        : _keyAlphabet;
    text.write(alphabet[random.nextInt(alphabet.length)]);
  }
  return text.toString();
}

int _randomPortOutsideRange(Random random) {
  final int distance = 1 + random.nextInt(_largestOutsidePortDistance);
  if (random.nextBool()) {
    return -distance;
  }
  return largestAppServerPort + distance;
}

NodeStartConfiguration _buildConfigurationIn(String folder) {
  return NodeStartConfiguration(
    dataDirectory: folder,
    identityStore: const FileIdentityStore(),
    runner: const NoRunner(),
    peerRelay: PeerRelayChoice.disabled,
  );
}

void main() {
  test('test_is_identity_key_property_matches_the_hexadecimal_model', () {
    final Random random = seededRandom(_firstSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = _randomKeyLikeText(random);
      final bool isModelKey =
          text.length == identityKeyHexadecimalLength &&
          _isLowercaseHexadecimal(text);

      expect(isIdentityKey(text), isModelKey, reason: text);
    }
  });

  test('test_is_identity_key_property_rejects_surrounding_whitespace', () {
    final Random random = seededRandom(_firstSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String key = randomIdentityKeyOfLength(
        random,
        identityKeyHexadecimalLength,
      );
      final List<String> paddedKeys = <String>['$key\n', '\n$key', ' $key'];

      expect(isIdentityKey(key), isTrue);
      expect(isIdentityKey(pickOne(random, paddedKeys)), isFalse);
    }
  });

  test('test_is_identity_key_property_rejects_uppercase_and_doubles', () {
    final Random random = seededRandom(_firstSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String key = randomIdentityKeyOfLength(
        random,
        identityKeyHexadecimalLength,
      );
      final String uppercaseKey = key.toUpperCase();

      expect(isIdentityKey(uppercaseKey), uppercaseKey == key);
      expect(isIdentityKey('$key$key'), isFalse);
      expect(isIdentityKey(key.substring(1)), isFalse);
    }
  });

  test('test_peer_relay_choice_constructor_property_matches_rust_names', () {
    expect(PeerRelayChoice.values.toSet(), _rustPeerRelayNames.keys.toSet());
    for (final PeerRelayChoice choice in PeerRelayChoice.values) {
      expect(choice.wireName, _rustPeerRelayNames[choice]);
    }
  });

  test('test_peer_relay_choice_constructor_property_only_rust_names', () {
    final Random random = seededRandom(_firstSeed + 9);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String wireName = randomHostileText(random);
      if (_rustPeerRelayNames.containsValue(wireName)) {
        continue;
      }

      expect(
        () => decodeWireName(PeerRelayChoice.values, wireName),
        throwsFormatException,
      );
    }
  });

  test('test_peer_relay_choice_constructor_property_found_by_name', () {
    for (final PeerRelayChoice choice in PeerRelayChoice.values) {
      expect(PeerRelayChoice.values.byName(choice.name), choice);
    }
  });

  test('test_peer_relay_choice_wire_name_property_is_unique', () {
    final Set<String> wireNames = <String>{};
    for (final PeerRelayChoice choice in PeerRelayChoice.values) {
      expect(wireNames.add(choice.wireName), isTrue);
    }
  });

  test('test_peer_relay_choice_wire_name_property_decodes_back', () {
    for (final PeerRelayChoice choice in PeerRelayChoice.values) {
      expect(decodeWireName(PeerRelayChoice.values, choice.wireName), choice);
    }
  });

  test('test_peer_relay_choice_wire_name_property_is_snake_case', () {
    for (final PeerRelayChoice choice in PeerRelayChoice.values) {
      expect(_snakeCaseName.hasMatch(choice.wireName), isTrue);
    }
  });

  test('test_node_start_configuration_constructor_property_keeps_fields', () {
    final Random random = seededRandom(_firstSeed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String dataDirectory = ' ${randomDataDirectory(random)} ';
      final IdentityStoreSettings store = randomIdentityStore(random);
      final PeerRelayChoice peerRelay = pickOne(
        random,
        PeerRelayChoice.values,
      );
      final int? port = randomOptionalPort(random);

      final NodeStartConfiguration configuration = NodeStartConfiguration(
        dataDirectory: dataDirectory,
        identityStore: store,
        runner: randomRunnerChoice(random),
        peerRelay: peerRelay,
        appServerPort: port,
      );

      expect(configuration.dataDirectory, dataDirectory);
      expect(identical(configuration.identityStore, store), isTrue);
      expect(configuration.peerRelay, peerRelay);
      expect(configuration.appServerPort, port);
    }
  });

  test('test_node_start_configuration_constructor_property_'
      'rejects_ports_outside_the_rust_range', () {
    final Random random = seededRandom(_firstSeed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int port = _randomPortOutsideRange(random);

      expect(
        () => NodeStartConfiguration(
          dataDirectory: randomDataDirectory(random),
          identityStore: randomIdentityStore(random),
          runner: randomRunnerChoice(random),
          peerRelay: pickOne(random, PeerRelayChoice.values),
          appServerPort: port,
        ),
        throwsArgumentError,
        reason: '$port',
      );
    }
  });

  test('test_node_start_configuration_constructor_property_'
      'accepts_any_non_blank_folder', () {
    final Random random = seededRandom(_firstSeed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String folder = randomHostileText(random);
      final bool isBlank = folder.trim().isEmpty;

      if (isBlank) {
        expect(() => _buildConfigurationIn(folder), throwsArgumentError);
        continue;
      }
      expect(_buildConfigurationIn(folder).dataDirectory, folder);
    }
  });

  test('test_node_start_configuration_to_json_property_port_when_given', () {
    final Random random = seededRandom(_firstSeed + 6);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeStartConfiguration configuration = randomStartConfiguration(
        random,
      );
      final JsonObject encoded = configuration.toJson();

      expect(
        encoded.containsKey(_portField),
        configuration.appServerPort != null,
      );
      expect(encoded[_portField], configuration.appServerPort);
    }
  });

  test('test_node_start_configuration_to_json_property_fresh_each_read', () {
    final Random random = seededRandom(_firstSeed + 7);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeStartConfiguration configuration = randomStartConfiguration(
        random,
      );
      final Object? firstText = rereadThroughWire(configuration.toJson());

      configuration.toJson().clear();

      expect(rereadThroughWire(configuration.toJson()), equals(firstText));
    }
  });

  test('test_node_start_configuration_to_json_property_survives_wire', () {
    final Random random = seededRandom(_firstSeed + 8);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeStartConfiguration configuration = randomStartConfiguration(
        random,
      );
      final JsonObject encoded = configuration.toJson();

      expect(rereadThroughWire(encoded), equals(encoded));
      expect(encoded['identity_store'], configuration.identityStore.toJson());
      expect(encoded['peer_relay'], configuration.peerRelay.wireName);
    }
  });
}
