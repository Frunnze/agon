import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/device_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart';

import '../../support/random_inputs.dart';
import '../support/arbitrary_json.dart';
import '../support/node_wire_names.dart';
import '../support/random_account_json.dart';
import '../support/wire_json_edits.dart';

const String _kindField = 'kind';
const String _joiningField = 'joining';
const List<String> _nearMissKinds = <String>[
  'Phone',
  'COMPUTER',
  ' phone',
  'computer ',
  'tablet',
  'laptop',
  '',
];

JsonObject _randomScreenWithJoining(Random random, String kind) {
  final JsonObject joiningJson = replaceWireField(
    randomJoiningDeviceJson(random),
    _kindField,
    kind,
  );
  return replaceWireField(
    randomPairingRequestScreenJson(random),
    _joiningField,
    joiningJson,
  );
}

void main() {
  test('test_joining_device_from_json_property_keeps_the_node_kind', () {
    final Random random = seededRandom(63201);
    final Set<DeviceKind> reachedKinds = <DeviceKind>{};

    for (int i = 0; i < propertyIterations; i += 1) {
      final String nodeKind = pickOne(random, nodeDeviceKinds);
      final JsonObject wireJson = replaceWireField(
        randomJoiningDeviceJson(random),
        _kindField,
        nodeKind,
      );

      final JoiningDevice device = JoiningDevice.fromJson(wireJson);
      final Object? reencoded = reencodeAsJsonText(device);

      expect(device.kind.wireName, nodeKind);
      expect(reencoded, equals(wireJson));
      reachedKinds.add(device.kind);
    }

    expect(reachedKinds, equals(DeviceKind.values.toSet()));
  });

  test('test_joining_device_from_json_property_refuses_a_missing_or_'
      'unknown_kind', () {
    final Random random = seededRandom(63202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = randomJoiningDeviceJson(random);
      final Object? arbitraryKind = randomArbitraryJson(random);
      final List<JsonObject> brokenJsons = <JsonObject>[
        removeWireField(wireJson, _kindField),
        replaceWireField(wireJson, _kindField, null),
        replaceWireField(
          wireJson,
          _kindField,
          pickOne(random, _nearMissKinds),
        ),
      ];
      if (!nodeDeviceKinds.contains(arbitraryKind)) {
        brokenJsons.add(replaceWireField(wireJson, _kindField, arbitraryKind));
      }

      for (final JsonObject brokenJson in brokenJsons) {
        expect(
          () => JoiningDevice.fromJson(brokenJson),
          throwsFormatException,
          reason: '${brokenJson[_kindField]}',
        );
      }
    }
  });

  test('test_joining_device_to_json_property_kind_survives_the_'
      'pairing_request_screen', () {
    final Random random = seededRandom(63203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String nodeKind = pickOne(random, nodeDeviceKinds);
      final JsonObject screenJson = _randomScreenWithJoining(random, nodeKind);

      final PairingRequestScreen screen = PairingRequestScreen.fromJson(
        screenJson,
      );
      final PairingRequestScreen reread = PairingRequestScreen.fromJson(
        reencodeAsJsonText(screen),
      );
      final JsonObject rereadJoining = decodeObject(
        decodeObject(reencodeAsJsonText(reread))[_joiningField],
      );

      expect(screen.joining?.kind.wireName, nodeKind);
      expect(reread.joining?.kind, screen.joining?.kind);
      expect(rereadJoining[_kindField], nodeKind);
    }
  });
}
