import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';

const String _workspaceMemberKind = 'workspace member';

WorkspaceId _randomFreshWorkspace(Random random) {
  return WorkspaceId('fresh-${randomText(random)}');
}

DeviceId _randomUnknownDevice(Random random) {
  return DeviceId('unknown-${randomText(random)}');
}

void main() {
  test('test_revoke_device_property_revoking_twice_is_refused_as_a_'
      'conflict', () async {
    final Random random = seededRandom(71301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device? target = pickActiveOtherDevice(random, counted.seeds);
      if (target == null) {
        continue;
      }

      final Device revoked = await counted.repository.revokeDevice(target.id);
      await expectLater(
        counted.repository.revokeDevice(target.id),
        throwsStateError,
      );

      expect(counted.repository.findDevice(target.id), same(revoked));
      expect(counted.notifications.count, 1);
    }
  });

  test('test_revoke_device_property_keeps_the_workspace_'
      'memberships', () async {
    final Random random = seededRandom(71302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device? target = pickActiveOtherDevice(random, counted.seeds);
      if (target == null) {
        continue;
      }

      final Device revoked = await counted.repository.revokeDevice(target.id);

      expect(revoked.revoked, isTrue);
      expect(revoked.workspaces, orderedEquals(target.workspaces));
    }
  });

  test('test_revoke_device_property_a_refused_revoke_changes_'
      'nothing', () async {
    final Random random = seededRandom(71303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device? revokedOther = pickRevokedOtherDevice(
        random,
        counted.seeds,
      );

      await expectLater(
        counted.repository.revokeDevice(deviceTestThisDevice),
        throwsStateError,
      );
      await expectLater(
        counted.repository.revokeDevice(_randomUnknownDevice(random)),
        throwsA(isA<RecordNotFound>()),
      );
      if (revokedOther != null) {
        await expectLater(
          counted.repository.revokeDevice(revokedOther.id),
          throwsStateError,
        );
      }

      expect(counted.repository.listDevices(), orderedEquals(counted.seeds));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_add_device_to_workspace_property_adding_twice_is_refused_as_a_'
      'conflict', () async {
    final Random random = seededRandom(71304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final WorkspaceId fresh = _randomFreshWorkspace(random);

      await counted.repository.addDeviceToWorkspace(
        deviceTestThisDevice,
        fresh,
      );
      await expectLater(
        counted.repository.addDeviceToWorkspace(deviceTestThisDevice, fresh),
        throwsStateError,
      );

      final List<WorkspaceId> joined = counted.repository
          .currentDevice()
          .workspaces;
      final Iterable<WorkspaceId> freshEntries = joined.where(
        (WorkspaceId joinedId) => joinedId == fresh,
      );
      expect(freshEntries, hasLength(1));
      expect(counted.notifications.count, 1);
    }
  });

  test('test_add_device_to_workspace_property_an_unknown_device_is_not_'
      'found', () async {
    final Random random = seededRandom(71305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final DeviceId unknown = _randomUnknownDevice(random);

      await expectLater(
        counted.repository.addDeviceToWorkspace(
          unknown,
          pickOne(random, sampleDeviceWorkspaceIds),
        ),
        throwsA(
          isA<RecordNotFound>().having(
            (RecordNotFound refusal) => refusal.identifier,
            'identifier',
            unknown.value,
          ),
        ),
      );
      expect(counted.repository.listDevices(), orderedEquals(counted.seeds));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_add_device_to_workspace_property_a_device_revoked_after_joining_'
      'cannot_join_again', () async {
    final Random random = seededRandom(71306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device? target = pickActiveOtherDevice(random, counted.seeds);
      if (target == null) {
        continue;
      }
      final WorkspaceId first = _randomFreshWorkspace(random);
      final WorkspaceId second = WorkspaceId('${first.value}-second');

      await counted.repository.addDeviceToWorkspace(target.id, first);
      final Device revoked = await counted.repository.revokeDevice(target.id);
      await expectLater(
        counted.repository.addDeviceToWorkspace(target.id, second),
        throwsStateError,
      );
      await expectLater(
        counted.repository.addDeviceToWorkspace(target.id, first),
        throwsStateError,
      );

      expect(counted.repository.findDevice(target.id), same(revoked));
      expect(revoked.workspaces, contains(first));
    }
  });

  test('test_remove_device_from_workspace_property_a_non_member_is_a_missing_'
      'workspace_member', () async {
    final Random random = seededRandom(71307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device device = pickOne(random, counted.seeds);

      await expectLater(
        counted.repository.removeDeviceFromWorkspace(
          device.id,
          _randomFreshWorkspace(random),
        ),
        throwsA(
          isA<RecordNotFound>()
              .having(
                (RecordNotFound refusal) => refusal.kind,
                'kind',
                _workspaceMemberKind,
              )
              .having(
                (RecordNotFound refusal) => refusal.identifier,
                'identifier',
                device.id.value,
              ),
        ),
      );
      expect(counted.repository.listDevices(), orderedEquals(counted.seeds));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_remove_device_from_workspace_property_removing_twice_is_not_'
      'found_the_second_time', () async {
    final Random random = seededRandom(71308);

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
      await expectLater(
        counted.repository.removeDeviceFromWorkspace(device.id, left),
        throwsA(isA<RecordNotFound>()),
      );

      expect(counted.repository.findDevice(device.id), same(after));
      expect(counted.notifications.count, 1);
    }
  });

  test('test_remove_device_from_workspace_property_an_unknown_device_is_not_'
      'found', () async {
    final Random random = seededRandom(71309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);

      await expectLater(
        counted.repository.removeDeviceFromWorkspace(
          _randomUnknownDevice(random),
          pickOne(random, sampleDeviceWorkspaceIds),
        ),
        throwsA(isA<RecordNotFound>()),
      );
      expect(counted.repository.listDevices(), orderedEquals(counted.seeds));
      expect(counted.notifications.count, 0);
    }
  });

  test('test_remove_device_from_workspace_property_a_revoked_member_can_'
      'still_leave', () async {
    final Random random = seededRandom(71310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CountedDevices counted = buildCountedDeviceRepository(random);
      final Device? revoked = pickRevokedOtherDevice(random, counted.seeds);
      if (revoked == null || revoked.workspaces.isEmpty) {
        continue;
      }
      final WorkspaceId left = pickOne(random, revoked.workspaces);

      final Device after = await counted.repository.removeDeviceFromWorkspace(
        revoked.id,
        left,
      );

      expect(after.workspaces, isNot(contains(left)));
      expect(after.revoked, isTrue);
      expect(counted.notifications.count, 1);
    }
  });
}
