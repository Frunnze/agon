import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';

Device buildNewDevice(Random random, int index) {
  return Device(
    id: DeviceId('new-device-$index'),
    name: 'new-device-$index',
    role: pickOne(random, DeviceRole.values),
    keyKind: pickOne(random, HardwareKeyKind.values),
    signingPublicKey: const <int>[0],
    sealingPublicKey: const <int>[0],
    workspaces: const <WorkspaceId>[GalleryWorkspaceIds.acme],
    pairedAt: galleryNow,
    approvedBy: GalleryDeviceIds.airLaptop,
    lastSeen: galleryNow,
    revoked: false,
  );
}

void main() {
  test('test_add_paired_device_property_appends_once_and_notifies', () async {
    final Random random = seededRandom(9721);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository repository = FakeDeviceRepository(
        devices: galleryDevices,
        currentDeviceId: GalleryDeviceIds.airLaptop,
        peerAddressProblem: null,
      );
      int notifications = 0;
      repository.addListener(() => notifications += 1);
      final Device device = buildNewDevice(random, i);

      await repository.addPairedDevice(device);

      expect(repository.listDevices().last, same(device));
      expect(repository.listDevices().length, galleryDevices.length + 1);
      expect(notifications, 1);
      await expectLater(
        repository.addPairedDevice(device),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('test_add_paired_device_fuzz_property_known_ids_fail', () async {
    final Random random = seededRandom(9722);
    final FakeDeviceRepository repository = FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      peerAddressProblem: null,
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device known = pickOne(random, galleryDevices);

      await expectLater(
        repository.addPairedDevice(known),
        throwsA(isA<StateError>()),
      );
    }
    expect(repository.listDevices().length, galleryDevices.length);
  });
}
