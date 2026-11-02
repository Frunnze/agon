import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

import '../bridge/support/node_json_primitives.dart';
import '../support/random_inputs.dart';

void main() {
  test('test_find_name_property_known_devices_match_name_of', () {
    final Random random = seededRandom(9431);
    final DeviceNames names = DeviceNames(galleryDevices);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);

      expect(names.findName(device.id), device.name);
      expect(names.findName(device.id), names.nameOf(device.id));
    }
  });

  test('test_find_name_fuzz_property_unknown_devices_have_no_name', () {
    final Random random = seededRandom(9432);
    final DeviceNames names = DeviceNames(galleryDevices);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId unknown = DeviceId(
        'unknown-${randomDeviceIdText(random)}',
      );

      expect(names.findName(unknown), isNull);
      expect(() => names.nameOf(unknown), throwsA(isA<RecordNotFound>()));
    }
  });

  test('test_describe_device_property_name_or_short_identifier', () {
    final Random random = seededRandom(9417);
    final DeviceNames names = DeviceNames(galleryDevices);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device known = pickOne(random, galleryDevices);
      final DeviceId unknown = DeviceId(randomDeviceIdText(random));

      expect(names.describeDevice(known.id), known.name);
      expect(names.describeDevice(unknown), shortenIdentifier(unknown.value));
    }
  });
}
