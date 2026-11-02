import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/pairing_values.dart' as node;
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_account_json.dart';
import '../../bridge/support/random_catalog_json.dart';
import '../../support/random_inputs.dart';

List<node.DeviceView> _randomDeviceViews(Random random) {
  return <node.DeviceView>[
    for (final Object? json in randomListOf(random, randomDeviceViewJson))
      node.DeviceView.fromJson(json),
  ];
}

void main() {
  test('test_find_joined_device_property_matches_the_sealing_key', () {
    final Random random = seededRandom(9961);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DeviceView> devices = _randomDeviceViews(random);
      final node.JoiningDevice joining = node.JoiningDevice.fromJson(
        randomJoiningDeviceJson(random),
      );
      final List<node.DeviceView> matching = <node.DeviceView>[
        for (final node.DeviceView view in devices)
          if (listEquals(
            view.device.sealingPublicKey,
            joining.sealingPublicKey,
          ))
            view,
      ];
      if (matching.isEmpty) {
        expect(() => findJoinedDevice(devices, joining), throwsStateError);
        continue;
      }
      final Device device = findJoinedDevice(devices, joining);
      expect(device.id, matching.first.device.id);
      expect(device.sealingPublicKey, joining.sealingPublicKey);
    }
  });

  test('test_find_device_name_property_names_listed_devices_only', () {
    final Random random = seededRandom(9962);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<node.DeviceView> devices = _randomDeviceViews(random);
      for (final node.DeviceView view in devices) {
        final String name = findDeviceName(devices, view.device.id);
        expect(
          devices.any(
            (node.DeviceView candidate) =>
                candidate.device.id == view.device.id &&
                candidate.device.name == name,
          ),
          isTrue,
        );
      }
      expect(
        () => findDeviceName(devices, DeviceId('missing-$i')),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
