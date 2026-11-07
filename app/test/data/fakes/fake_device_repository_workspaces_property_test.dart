import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';

final class _JoinWatcher {
  _JoinWatcher({required this.repository, required this.workspaceId});

  final FakeDeviceRepository repository;
  final WorkspaceId workspaceId;
  final List<bool> seenJoined = <bool>[];

  void record() {
    final Device current = repository.currentDevice();
    seenJoined.add(current.workspaces.contains(workspaceId));
  }
}

void main() {
  test('test_add_device_to_workspace_property_joins_once_and_keeps_other_'
      'workspaces', () async {
    final Random random = seededRandom(64307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device device = counted.repository.currentDevice();
      final List<WorkspaceId> outside = <WorkspaceId>[
        for (final WorkspaceId workspaceId in sampleDeviceWorkspaceIds)
          if (!device.workspaces.contains(workspaceId)) workspaceId,
      ];
      final WorkspaceId joined = pickOne(random, outside);

      final Device after = await counted.repository.addDeviceToWorkspace(
        device.id,
        joined,
      );

      expect(after.workspaces, <WorkspaceId>[...device.workspaces, joined]);
      expectOtherDevicesUnchanged(
        counted.seeds,
        counted.repository.listDevices(),
        changedId: device.id,
      );
      expect(counted.notifications.count, 1);
    }
  });

  test('test_add_device_to_workspace_property_a_member_is_refused_like_the_'
      'server', () async {
    final Random random = seededRandom(64308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device device = pickOne(random, counted.seeds);
      if (device.workspaces.isEmpty) {
        continue;
      }

      await expectLater(
        counted.repository.addDeviceToWorkspace(
          device.id,
          pickOne(random, device.workspaces),
        ),
        throwsStateError,
      );
      expect(counted.repository.findDevice(device.id), same(device));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_add_device_to_workspace_property_a_revoked_device_is_refused_'
      'like_the_server', () async {
    final Random random = seededRandom(64309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device? revoked = pickRevokedOtherDevice(random, counted.seeds);
      if (revoked == null) {
        continue;
      }
      final WorkspaceId workspaceId = pickOne(
        random,
        sampleDeviceWorkspaceIds,
      );

      await expectLater(
        counted.repository.addDeviceToWorkspace(revoked.id, workspaceId),
        throwsStateError,
      );
      expect(counted.repository.findDevice(revoked.id), same(revoked));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_remove_device_from_workspace_property_leaves_and_keeps_other_'
      'workspaces', () async {
    final Random random = seededRandom(64310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device device = pickOne(random, counted.seeds);
      if (device.workspaces.isEmpty) {
        continue;
      }
      final WorkspaceId left = pickOne(random, device.workspaces);

      final Device after = await counted.repository.removeDeviceFromWorkspace(
        device.id,
        left,
      );

      expect(after.workspaces, <WorkspaceId>[
        for (final WorkspaceId workspaceId in device.workspaces)
          if (workspaceId != left) workspaceId,
      ]);
      expect(after.revoked, device.revoked);
      expect(counted.notifications.count, 1);
    }
  });

  test('test_remove_device_from_workspace_property_a_non_member_is_refused_'
      'like_the_server', () async {
    final Random random = seededRandom(64311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device device = pickOne(random, counted.seeds);
      final WorkspaceId outsider = WorkspaceId(
        'outside-${randomText(random)}',
      );

      await expectLater(
        counted.repository.removeDeviceFromWorkspace(device.id, outsider),
        throwsA(isA<RecordNotFound>()),
      );
      expect(counted.repository.findDevice(device.id), same(device));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_remove_device_from_workspace_property_undoes_adding', () async {
    final Random random = seededRandom(64312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device device = counted.repository.currentDevice();
      final WorkspaceId fresh = WorkspaceId('fresh-${randomText(random)}');

      await counted.repository.addDeviceToWorkspace(device.id, fresh);
      final Device after = await counted.repository.removeDeviceFromWorkspace(
        device.id,
        fresh,
      );

      expect(after.workspaces, device.workspaces);
      expect(counted.notifications.count, 2);
    }
  });

  test('test_store_device_property_keeps_the_device_order', () async {
    final Random random = seededRandom(64313);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device? target = pickActiveOtherDevice(random, counted.seeds);
      if (target == null) {
        continue;
      }

      await counted.repository.revokeDevice(target.id);

      expect(
        describeDeviceIds(counted.repository.listDevices()),
        describeDeviceIds(counted.seeds),
      );
    }
  });

  test('test_store_device_property_listeners_see_the_stored_device', () async {
    final Random random = seededRandom(64314);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final WorkspaceId fresh = WorkspaceId('fresh-${randomText(random)}');
      final _JoinWatcher watcher = _JoinWatcher(
        repository: counted.repository,
        workspaceId: fresh,
      );
      counted.repository.addListener(watcher.record);

      await counted.repository.addDeviceToWorkspace(
        deviceTestThisDevice,
        fresh,
      );

      expect(watcher.seenJoined, <bool>[true]);
    }
  });

  test('test_store_device_property_returns_the_stored_device', () async {
    final Random random = seededRandom(64315);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final WorkspaceId fresh = WorkspaceId('fresh-${randomText(random)}');

      final Device joined = await counted.repository.addDeviceToWorkspace(
        deviceTestThisDevice,
        fresh,
      );

      expect(counted.repository.currentDevice(), same(joined));
    }
  });
}
