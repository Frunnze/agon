import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_account_json.dart';
import '../support/random_wire_counts.dart';
import '../support/wire_json_edits.dart';

const String _endpointKeyField = 'endpoint_public_key';
const int _smallestByte = 0;
const int _largestByte = 255;
const int _byteValueCount = 256;
const int _longestWrongKeyLength = 3 * endpointPublicKeyLength;

const List<Object?> _notAByteList = <Object?>[
  null,
  true,
  7,
  1.5,
  '',
  'endpoint key',
  <String, Object?>{},
  <String, Object?>{'bytes': <int>[]},
];

const List<Object?> _notAByte = <Object?>[
  null,
  false,
  2.5,
  '7',
  <Object?>[],
  <String, Object?>{},
];

int _randomBoundaryByte(Random random) {
  return pickOne<int>(random, <int>[
    _smallestByte,
    _largestByte,
    random.nextInt(_byteValueCount),
  ]);
}

List<int> _randomBoundaryKey(Random random) {
  return <int>[
    for (int i = 0; i < endpointPublicKeyLength; i += 1)
      _randomBoundaryByte(random),
  ];
}

int _randomWrongKeyLength(Random random) {
  final int length = pickOne<int>(random, <int>[
    0,
    endpointPublicKeyLength - 1,
    endpointPublicKeyLength + 1,
    random.nextInt(_longestWrongKeyLength),
  ]);
  if (length == endpointPublicKeyLength) {
    return length + 1;
  }
  return length;
}

Object? _randomBrokenKey(Random random) {
  if (random.nextBool()) {
    return pickOne<Object?>(random, _notAByteList);
  }

  final List<Object?> key = List<Object?>.of(randomEndpointPublicKey(random));
  key[random.nextInt(key.length)] = pickOne<Object?>(random, _notAByte);
  return key;
}

PeerAddress _decodeThroughJsonText(PeerAddress address) {
  final String jsonText = jsonEncode(address.toJson());
  return PeerAddress.fromJson(jsonDecode(jsonText));
}

void main() {
  test('test_decode_endpoint_public_key_property_'
      'keeps_32_bytes_at_the_byte_bounds_through_json_text', () {
    final Random random = seededRandom(91410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> key = _randomBoundaryKey(random);
      final JsonObject wireJson = replaceWireField(
        randomPeerAddressJson(random),
        _endpointKeyField,
        key,
      );

      final PeerAddress address = PeerAddress.fromJson(wireJson);
      final PeerAddress readAgain = _decodeThroughJsonText(address);

      expect(address.endpointPublicKey, orderedEquals(key));
      expect(readAgain.endpointPublicKey, orderedEquals(key));
    }
  });

  test('test_decode_endpoint_public_key_property_'
      'rejects_every_length_but_32_including_one_off', () {
    final Random random = seededRandom(91411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = _randomWrongKeyLength(random);
      final JsonObject brokenJson = replaceWireField(
        randomPeerAddressJson(random),
        _endpointKeyField,
        randomBytesOfLength(random, length),
      );

      expect(
        () => PeerAddress.fromJson(brokenJson),
        throwsFormatException,
        reason: 'a key of $length bytes',
      );
    }
  });

  test('test_decode_endpoint_public_key_property_'
      'rejects_missing_keys_and_values_that_are_not_byte_lists', () {
    final Random random = seededRandom(91412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomPeerAddressJson(random);
      final Object? brokenKey = _randomBrokenKey(random);
      final JsonObject brokenJson = replaceWireField(
        wireJson,
        _endpointKeyField,
        brokenKey,
      );
      final JsonObject keylessJson = removeWireField(
        wireJson,
        _endpointKeyField,
      );

      expect(
        () => PeerAddress.fromJson(brokenJson),
        throwsFormatException,
        reason: 'the key $brokenKey',
      );
      expect(() => PeerAddress.fromJson(keylessJson), throwsFormatException);
    }
  });

  test('test_decode_endpoint_public_key_property_'
      'decoded_key_ignores_later_edits_to_the_sent_list', () {
    final Random random = seededRandom(91413);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> sentKey = randomEndpointPublicKey(random);
      final List<int> keptCopy = List<int>.of(sentKey);
      final JsonObject wireJson = replaceWireField(
        randomPeerAddressJson(random),
        _endpointKeyField,
        sentKey,
      );

      final PeerAddress address = PeerAddress.fromJson(wireJson);
      sentKey[random.nextInt(sentKey.length)] += 1;
      sentKey.add(random.nextInt(_byteValueCount));

      expect(address.endpointPublicKey, orderedEquals(keptCopy));
      expect(
        () => address.endpointPublicKey.add(_smallestByte),
        throwsUnsupportedError,
      );
    }
  });
}
