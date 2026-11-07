import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';

const String _typePrefix = 'test_fake_device_repository';
const String _missingKeyProblem = 'this device holds no key for workspace';

List<WorkspaceId> _workspacesOutside(Device device) {
  return <WorkspaceId>[
    for (final WorkspaceId workspaceId in sampleDeviceWorkspaceIds)
      if (!device.workspaces.contains(workspaceId)) workspaceId,
  ];
}

int _countMemberships(Device device, WorkspaceId workspaceId) {
  int count = 0;
  for (final WorkspaceId joined in device.workspaces) {
    if (joined == workspaceId) {
      count += 1;
    }
  }
  return count;
}

void main() {
  test('${_typePrefix}_add_device_to_workspace_property_refuses_a_'
      'workspace_this_device_holds_no_key_for', () async {
    final Random random = seededRandom(92001);
    int refusedCount = 0;

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final List<WorkspaceId> outside = _workspacesOutside(
        counted.repository.currentDevice(),
      );
      if (outside.isEmpty) {
        continue;
      }
      final WorkspaceId foreign = pickOne(random, outside);
      final Device target = pickOne(random, counted.seeds);
      refusedCount += 1;

      await expectLater(
        counted.repository.addDeviceToWorkspace(target.id, foreign),
        throwsA(
          isA<StateError>().having(
            (StateError refusal) => refusal.message,
            'message',
            '$_missingKeyProblem ${foreign.value}',
          ),
        ),
      );

      expect(counted.repository.listDevices(), orderedEquals(counted.seeds));
      expect(counted.notifications.count, 0);
    }
    expect(refusedCount, greaterThan(0));
  });

  test('${_typePrefix}_add_device_to_workspace_property_an_unknown_device_'
      'is_missing_before_the_key_is_checked', () async {
    final Random random = seededRandom(92002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final DeviceId unknown = DeviceId('unknown-${randomText(random)}');

      await expectLater(
        counted.repository.addDeviceToWorkspace(
          unknown,
          pickOne(random, sampleDeviceWorkspaceIds),
        ),
        throwsA(isA<RecordNotFound>()),
      );
      expect(counted.repository.listDevices(), orderedEquals(counted.seeds));
    }
  });

  test('${_typePrefix}_add_device_to_workspace_property_joins_when_this_'
      'device_holds_the_key', () async {
    final Random random = seededRandom(92003);
    int joinedCount = 0;

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final List<WorkspaceId> keys = counted.repository
          .currentDevice()
          .workspaces;
      final Device target = pickOne(random, counted.seeds);
      final List<WorkspaceId> joinable = <WorkspaceId>[
        for (final WorkspaceId workspaceId in keys)
          if (!target.workspaces.contains(workspaceId)) workspaceId,
      ];
      if (target.revoked || joinable.isEmpty) {
        continue;
      }
      final WorkspaceId workspaceId = pickOne(random, joinable);

      final Device joined = await counted.repository.addDeviceToWorkspace(
        target.id,
        workspaceId,
      );

      joinedCount += 1;
      expect(_countMemberships(joined, workspaceId), 1);
      expect(counted.repository.findDevice(target.id), same(joined));
      expect(counted.notifications.count, 1);
    }
    expect(joinedCount, greaterThan(0));
  });

  test('${_typePrefix}_grant_workspace_to_current_device_property_makes_'
      'this_device_a_member_once', () {
    final Random random = seededRandom(92004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final WorkspaceId granted = WorkspaceId('created-${randomText(random)}');
      final int grantCount = 1 + random.nextInt(3);

      for (int step = 0; step < grantCount; step += 1) {
        counted.repository.grantWorkspaceToCurrentDevice(granted);
      }

      final Device current = counted.repository.currentDevice();
      expect(_countMemberships(current, granted), 1);
      final Device seededCurrent = counted.seeds.firstWhere(
        (Device seed) => seed.id == current.id,
      );
      expect(current.workspaces, <WorkspaceId>[
        ...seededCurrent.workspaces,
        granted,
      ]);
    }
  });

  test('${_typePrefix}_grant_workspace_to_current_device_property_leaves_'
      'other_devices_untouched_and_notifies', () {
    final Random random = seededRandom(92005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final List<Device> before = counted.repository.listDevices();

      counted.repository.grantWorkspaceToCurrentDevice(
        WorkspaceId('created-$i'),
      );

      expectOtherDevicesUnchanged(
        before,
        counted.repository.listDevices(),
        changedId: deviceTestThisDevice,
      );
      expect(counted.notifications.count, 1);
    }
  });

  test('${_typePrefix}_grant_workspace_to_current_device_property_lets_'
      'this_device_add_members_afterwards', () async {
    final Random random = seededRandom(92006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final WorkspaceId granted = WorkspaceId('created-$i');
      final Device? target = pickActiveOtherDevice(random, counted.seeds);
      if (target == null) {
        continue;
      }

      counted.repository.grantWorkspaceToCurrentDevice(granted);
      final Device joined = await counted.repository.addDeviceToWorkspace(
        target.id,
        granted,
      );

      expect(joined.workspaces, contains(granted));
    }
  });

  test('${_typePrefix}_withdraw_workspace_property_removes_it_from_every_'
      'device', () {
    final Random random = seededRandom(92007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final WorkspaceId withdrawn = pickOne(random, sampleDeviceWorkspaceIds);

      counted.repository.withdrawWorkspace(withdrawn);

      final List<Device> after = counted.repository.listDevices();
      expect(describeDeviceIds(after), describeDeviceIds(counted.seeds));
      for (int index = 0; index < after.length; index += 1) {
        expect(after[index].workspaces, <WorkspaceId>[
          for (final WorkspaceId joined in counted.seeds[index].workspaces)
            if (joined != withdrawn) joined,
        ]);
        expect(after[index].revoked, counted.seeds[index].revoked);
      }
    }
  });

  test('${_typePrefix}_withdraw_workspace_property_is_idempotent_and_'
      'notifies_each_call', () {
    final Random random = seededRandom(92008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final WorkspaceId withdrawn = pickOne(random, sampleDeviceWorkspaceIds);

      counted.repository.withdrawWorkspace(withdrawn);
      final List<Device> once = counted.repository.listDevices();
      counted.repository.withdrawWorkspace(withdrawn);

      final List<Device> twice = counted.repository.listDevices();
      for (int index = 0; index < once.length; index += 1) {
        expect(twice[index].workspaces, once[index].workspaces);
      }
      expect(counted.notifications.count, 2);
    }
  });

  test('${_typePrefix}_withdraw_workspace_property_then_adding_members_is_'
      'refused', () async {
    final Random random = seededRandom(92009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final WorkspaceId withdrawn = pickOne(random, sampleDeviceWorkspaceIds);
      final Device target = pickOne(random, counted.seeds);

      counted.repository.withdrawWorkspace(withdrawn);

      await expectLater(
        counted.repository.addDeviceToWorkspace(target.id, withdrawn),
        throwsStateError,
      );
    }
  });
}
