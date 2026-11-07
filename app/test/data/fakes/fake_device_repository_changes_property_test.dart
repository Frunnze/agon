import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';

const int _largestPairingCount = 4;

void main() {
  test('test_add_paired_device_property_appends_the_device_and_notifies_'
      'once', () async {
    final Random random = seededRandom(64301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final int pairingCount = 1 + random.nextInt(_largestPairingCount);

      for (int pairing = 0; pairing < pairingCount; pairing += 1) {
        final Device paired = randomDeviceWithId(
          random,
          DeviceId('paired-$pairing'),
          isRevoked: false,
        );
        expect(await counted.repository.addPairedDevice(paired), same(paired));
        expect(counted.repository.listDevices().last, same(paired));
      }

      expect(
        counted.repository.listDevices().length,
        counted.seeds.length + pairingCount,
      );
      expect(counted.notifications.count, pairingCount);
    }
  });

  test('test_add_paired_device_property_known_ids_are_refused_without_'
      'notifying', () async {
    final Random random = seededRandom(64302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device known = pickOne(random, counted.seeds);
      final Device impostor = randomDeviceWithId(
        random,
        known.id,
        isRevoked: false,
      );

      await expectLater(
        counted.repository.addPairedDevice(impostor),
        throwsStateError,
      );
      expect(counted.repository.listDevices(), orderedEquals(counted.seeds));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_add_paired_device_property_a_paired_device_can_then_be_'
      'revoked', () async {
    final Random random = seededRandom(64303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device paired = randomDeviceWithId(
        random,
        DeviceId('paired-${randomText(random)}'),
        isRevoked: false,
      );
      await counted.repository.addPairedDevice(paired);

      final Device revoked = await counted.repository.revokeDevice(paired.id);

      expect(revoked.revoked, isTrue);
      expect(counted.repository.findDevice(paired.id), same(revoked));
    }
  });

  test('test_revoke_device_property_marks_only_that_device', () async {
    final Random random = seededRandom(64304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device? target = pickActiveOtherDevice(random, counted.seeds);
      if (target == null) {
        continue;
      }

      final Device revoked = await counted.repository.revokeDevice(target.id);

      expect(revoked.revoked, isTrue);
      expect(revoked.workspaces, target.workspaces);
      expect(revoked.name, target.name);
      expectOtherDevicesUnchanged(
        counted.seeds,
        counted.repository.listDevices(),
        changedId: target.id,
      );
      expect(counted.notifications.count, 1);
    }
  });

  test('test_revoke_device_property_a_revoked_device_is_refused_like_the_'
      'server', () async {
    final Random random = seededRandom(64305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device? target = pickRevokedOtherDevice(random, counted.seeds);
      if (target == null) {
        continue;
      }

      await expectLater(
        counted.repository.revokeDevice(target.id),
        throwsStateError,
      );
      expect(counted.repository.listDevices(), orderedEquals(counted.seeds));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_revoke_device_property_this_and_unknown_devices_are_'
      'refused', () async {
    final Random random = seededRandom(64306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);

      await expectLater(
        counted.repository.revokeDevice(deviceTestThisDevice),
        throwsStateError,
      );
      await expectLater(
        counted.repository.revokeDevice(DeviceId(randomText(random))),
        throwsA(isA<RecordNotFound>()),
      );
      expect(counted.repository.listDevices(), orderedEquals(counted.seeds));
      expect(counted.notifications.count, 0);
    }
  });
}
