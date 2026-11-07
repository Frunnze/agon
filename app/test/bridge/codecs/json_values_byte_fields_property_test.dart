import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_values.dart';

import '../../support/random_inputs.dart';
import '../support/node_shapes.dart' show NodeValueDecoder;
import '../support/random_account_json.dart';
import '../support/random_catalog_json.dart';
import '../support/random_run_json.dart';
import '../support/random_wire_counts.dart';
import '../support/random_work_json.dart';
import '../support/wire_json_edits.dart';

typedef _WireJsonBuilder = JsonObject Function(Random random);

const String _endpointKeyField = 'endpoint_public_key';
const int _longestWrongKeyLength = 2 * endpointPublicKeyLength;

final class _ByteListField {
  const _ByteListField(this.typeName, this.buildJson, this.decode, this.field);

  final String typeName;
  final _WireJsonBuilder buildJson;
  final NodeValueDecoder decode;
  final String field;
}

const List<_ByteListField> _byteListFields = <_ByteListField>[
  _ByteListField(
    'signed_decision',
    randomSignedDecisionJson,
    SignedDecision.fromJson,
    'signature',
  ),
  _ByteListField(
    'workflow_signature',
    randomWorkflowSignatureJson,
    WorkflowSignature.fromJson,
    'signature',
  ),
  _ByteListField(
    'device',
    randomDeviceJson,
    Device.fromJson,
    'signing_public_key',
  ),
  _ByteListField(
    'device',
    randomDeviceJson,
    Device.fromJson,
    'sealing_public_key',
  ),
  _ByteListField(
    'joining_device',
    randomJoiningDeviceJson,
    JoiningDevice.fromJson,
    'sealing_public_key',
  ),
  _ByteListField(
    'peer_address',
    randomPeerAddressJson,
    PeerAddress.fromJson,
    _endpointKeyField,
  ),
];

List<int> _readWireBytes(JsonObject wireJson, String field) {
  return decodeList(wireJson[field], decodeInteger);
}

List<int> _breakOneByte(Random random, List<int> bytes) {
  final List<int> broken = List<int>.of(bytes);
  final int outsideByte = randomWholeNumberOutsideAByte(random);
  if (broken.isEmpty) {
    broken.add(outsideByte);
    return broken;
  }
  broken[random.nextInt(broken.length)] = outsideByte;
  return broken;
}

int _randomWrongKeyLength(Random random) {
  final int length = random.nextInt(_longestWrongKeyLength);
  if (length == endpointPublicKeyLength) {
    return length + 1;
  }
  return length;
}

void _testRejectsByteOutsideRange(_ByteListField shape, int seed) {
  test('test_${shape.typeName}_from_json_property_'
      'rejects_a_byte_outside_0_to_255_in_${shape.field}', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = shape.buildJson(random);
      final List<int> bytes = _readWireBytes(wireJson, shape.field);
      final JsonObject brokenJson = replaceWireField(
        wireJson,
        shape.field,
        _breakOneByte(random, bytes),
      );

      expect(() => shape.decode(brokenJson), throwsFormatException);
    }
  });
}

void _testKeepsEveryByte(_ByteListField shape, int seed) {
  test('test_${shape.typeName}_from_json_property_'
      'keeps_every_${shape.field}_byte_in_order', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = shape.buildJson(random);

      final JsonEncodable decoded = shape.decode(wireJson);
      final JsonObject reencoded = decodeObject(reencodeAsJsonText(decoded));

      final List<int> sentBytes = _readWireBytes(wireJson, shape.field);

      expect(reencoded[shape.field], orderedEquals(sentBytes));
    }
  });
}

void main() {
  int seed = 77300;
  for (final _ByteListField shape in _byteListFields) {
    _testRejectsByteOutsideRange(shape, seed);
    _testKeepsEveryByte(shape, seed + 1);
    seed += 2;
  }

  test('test_peer_address_from_json_property_'
      'rejects_an_endpoint_public_key_not_32_bytes_long', () {
    final Random random = seededRandom(77350);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = _randomWrongKeyLength(random);
      final JsonObject brokenJson = replaceWireField(
        randomPeerAddressJson(random),
        _endpointKeyField,
        randomBytesOfLength(random, length),
      );

      expect(() => PeerAddress.fromJson(brokenJson), throwsFormatException);
    }
  });

  test('test_peer_address_from_json_property_'
      'keeps_any_32_byte_endpoint_public_key', () {
    final Random random = seededRandom(77351);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<int> key = randomEndpointPublicKey(random);
      final JsonObject wireJson = replaceWireField(
        randomPeerAddressJson(random),
        _endpointKeyField,
        key,
      );

      final PeerAddress address = PeerAddress.fromJson(wireJson);

      expect(address.endpointPublicKey, orderedEquals(key));
    }
  });
}
