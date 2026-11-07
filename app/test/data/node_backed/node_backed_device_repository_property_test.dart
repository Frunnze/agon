import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/device_repository_rig.dart';

const int _largestReloadCount = 4;

void main() {
  test(
    'test_node_backed_device_repository_constructor_property_starts_empty',
    () {
      final Random random = seededRandom(76701);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig rig = buildDeviceRig(random);

        expect(rig.repository.listDevices(), isEmpty);
        expect(rig.repository.findPeerAddressProblem(), isNull);
        expect(rig.repository.currentDevice, throwsStateError);
        expect(rig.node.receivedCommands, isEmpty);
      }
    },
  );

  test(
    'test_node_backed_device_repository_constructor_property_own_channel',
    () async {
      final Random random = seededRandom(76702);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig loaded = buildDeviceRig(random);
        final DeviceRig untouched = buildDeviceRig(random);

        await loaded.repository.load();

        expectRepositoryMirrorsNode(loaded);
        expect(untouched.node.receivedCommands, isEmpty);
        expect(untouched.repository.listDevices(), isEmpty);
      }
    },
  );

  test(
    'test_node_backed_device_repository_constructor_property_shares_nothing',
    () async {
      final Random random = seededRandom(76703);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig rig = buildDeviceRig(random);
        final DeviceRig twin = buildDeviceRig(random);

        await rig.repository.load();
        await twin.repository.load();

        expectRepositoryMirrorsNode(rig);
        expectRepositoryMirrorsNode(twin);
        expect(rig.repository.findPeerAddressProblem(), isNull);
      }
    },
  );

  test('test_list_devices_property_keeps_the_node_order', () async {
    final Random random = seededRandom(76704);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);

      await rig.repository.load();

      expectRepositoryMirrorsNode(rig);
    }
  });

  test('test_list_devices_property_cannot_be_changed_by_callers', () async {
    final Random random = seededRandom(76705);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      await rig.repository.load();
      final List<Device> listed = rig.repository.listDevices();

      expect(() => listed.add(listed.first), throwsUnsupportedError);
      expect(listed.clear, throwsUnsupportedError);
      expectRepositoryMirrorsNode(rig);
    }
  });

  test(
    'test_list_devices_property_an_earlier_listing_never_changes',
    () async {
      final Random random = seededRandom(76706);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig rig = buildDeviceRig(random);
        await rig.repository.load();
        final List<Device> earlier = rig.repository.listDevices();
        final List<Object?> earlierDescription = describeListedDevices(
          earlier,
        );

        for (int j = 0; j < 1 + random.nextInt(_largestReloadCount); j += 1) {
          addUnrevokedDeviceFromElsewhere(random, rig.node);
          await rig.repository.load();
        }

        expect(describeListedDevices(earlier), earlierDescription);
        expectRepositoryMirrorsNode(rig);
      }
    },
  );

  test('test_find_device_property_finds_every_listed_device', () async {
    final Random random = seededRandom(76707);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      await rig.repository.load();

      for (final Device device in rig.repository.listDevices()) {
        expect(rig.repository.findDevice(device.id), same(device));
      }
    }
  });

  test('test_find_device_property_unknown_ids_name_the_missing_id', () async {
    final Random random = seededRandom(76708);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      await rig.repository.load();
      final String unknown = 'unknown-${randomHostileText(random)}';

      expect(
        () => rig.repository.findDevice(DeviceId(unknown)),
        throwsA(
          isA<RecordNotFound>()
              .having(
                (RecordNotFound missing) => missing.kind,
                'kind',
                'device',
              )
              .having(
                (RecordNotFound missing) => missing.identifier,
                'identifier',
                unknown,
              ),
        ),
      );
    }
  });

  test('test_current_device_property_follows_the_node_mark', () async {
    final Random random = seededRandom(76709);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      final bool isThisDeviceListed = random.nextBool();
      if (!isThisDeviceListed) {
        rig.node.devices.remove(rigThisDeviceId);
      }

      await rig.repository.load();

      if (isThisDeviceListed) {
        final Device current = rig.repository.currentDevice();
        expect(current.id.value, rigThisDeviceId);
        expect(current, same(rig.repository.findDevice(current.id)));
      } else {
        expect(rig.repository.currentDevice, throwsStateError);
      }
    }
  });

  test('test_find_peer_address_problem_property_follows_each_load', () async {
    final Random random = seededRandom(76710);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      for (int j = 0; j < 1 + random.nextInt(_largestReloadCount); j += 1) {
        final String? problem = random.nextBool()
            ? 'relay ${randomHostileText(random)}'
            : null;
        rig.node.peerProblem = problem;

        await rig.repository.load();

        expect(rig.repository.findPeerAddressProblem(), problem);
      }
    }
  });

  test('test_find_peer_address_problem_property_keeps_hostile_text', () async {
    final Random random = seededRandom(76711);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      final String problem = randomHostileText(random);
      rig.node.peerProblem = problem;
      await rig.repository.load();
      rig.node.peerProblem = 'changed later';

      expect(rig.repository.findPeerAddressProblem(), problem);
      expect(rig.repository.findPeerAddressProblem(), problem);
    }
  });
}
