import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/workspace_membership.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';
import 'support/membership_twin_world.dart';
import 'support/workspace_work_checks.dart';

const String _typePrefix = 'test_fake_workspace_repository';
const int _sequenceIterations = 25;
const int _longestSequence = 4;

WorkspaceId _pickWorkspaceId(Random random, MembershipTwinWorld world) {
  final List<Workspace> listed = world.nodeWorkspaces.listWorkspaces();
  return pickOne(random, listed).id;
}

Matcher _isOutsiderRefusal() {
  return isA<StateError>().having(
    (StateError error) => error.message,
    'message',
    outsiderDeviceProblem,
  );
}

FakeDeviceRepository _buildDevices(Random random, List<WorkspaceId> joined) {
  final Device device = randomDeviceWithId(
    random,
    deviceTestThisDevice,
    isRevoked: false,
  ).withWorkspaces(joined);
  return buildDeviceRepository(<Device>[device]);
}

void main() {
  test('${_typePrefix}_delete_workspace_property_refuses_outsiders_like_'
      'the_node', () async {
    final Random random = seededRandom(77501);
    int refusedCount = 0;

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final MembershipTwinWorld world = await buildMembershipTwinWorld(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final WorkspaceId workspaceId = _pickWorkspaceId(random, world);
        final bool isRefused = await expectSameRefusal(
          fakeStep: () => world.fakeWorkspaces.deleteWorkspace(workspaceId),
          nodeStep: () => world.nodeWorkspaces.deleteWorkspace(workspaceId),
          reason: workspaceId.value,
        );
        refusedCount += isRefused ? 1 : 0;

        expect(<String>[
          for (final Workspace workspace
              in world.fakeWorkspaces.listWorkspaces())
            workspace.id.value,
        ], listTwinWorkspaceIds(world));
        expect(
          listFakeProjectIds(world),
          unorderedEquals(listSimulatedProjectIds(world)),
        );
      }
      await closeMembershipTwinWorld(world);
    }

    expect(refusedCount, greaterThan(0));
  });

  test('${_typePrefix}_delete_workspace_property_outsider_changes_'
      'nothing', () async {
    final Random random = seededRandom(77502);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final MembershipTwinWorld world = await buildMembershipTwinWorld(random);
      final List<String> projectsBefore = listFakeProjectIds(world);
      final List<Workspace> before = world.fakeWorkspaces.listWorkspaces();

      for (final Workspace workspace in before) {
        if (!world.memberWorkspaceIds.contains(workspace.id)) {
          await expectLater(
            world.fakeWorkspaces.deleteWorkspace(workspace.id),
            throwsA(_isOutsiderRefusal()),
          );
        }
      }

      expect(world.fakeWorkspaces.listWorkspaces(), before);
      expect(listFakeProjectIds(world), projectsBefore);
      await closeMembershipTwinWorld(world);
    }
  });

  test('${_typePrefix}_delete_workspace_property_outsider_is_refused_'
      'before_the_last_workspace_rule', () async {
    final Random random = seededRandom(77503);
    int lastOutsiderCount = 0;
    for (int i = 0; i < _sequenceIterations * 4; i += 1) {
      final MembershipTwinWorld world = await buildMembershipTwinWorld(random);
      final List<Workspace> listed = world.fakeWorkspaces.listWorkspaces();
      final Workspace only = listed.first;
      final bool isMember = world.memberWorkspaceIds.contains(only.id);

      if (listed.length == 1) {
        final Matcher refusal = isMember
            ? throwsA(isA<StateError>())
            : throwsA(_isOutsiderRefusal());
        await expectLater(
          world.fakeWorkspaces.deleteWorkspace(only.id),
          refusal,
        );
        lastOutsiderCount += isMember ? 0 : 1;
      }
      await closeMembershipTwinWorld(world);
    }
    expect(lastOutsiderCount, greaterThan(0));
  });

  test('test_fake_workspace_contents_refuse_outsider_device_property_refuses_'
      'exactly_outsiders', () async {
    final Random random = seededRandom(77504);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final MembershipTwinWorld world = await buildMembershipTwinWorld(random);
      for (final WorkspaceId workspaceId in world.seeds.workspaceIds) {
        final bool isMember = world.memberWorkspaceIds.contains(workspaceId);
        if (isMember) {
          world.fakeContents.refuseOutsiderDevice(workspaceId);
        } else {
          expect(
            () => world.fakeContents.refuseOutsiderDevice(workspaceId),
            throwsA(_isOutsiderRefusal()),
          );
        }
      }
      await closeMembershipTwinWorld(world);
    }
  });

  test('test_fake_workspace_contents_refuse_outsider_device_property_unknown_'
      'workspaces_are_refused', () async {
    final Random random = seededRandom(77505);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final MembershipTwinWorld world = await buildMembershipTwinWorld(random);
      final WorkspaceId unknown = WorkspaceId('never-${randomText(random)}');

      expect(
        () => world.fakeContents.refuseOutsiderDevice(unknown),
        throwsA(_isOutsiderRefusal()),
      );
      await closeMembershipTwinWorld(world);
    }
  });

  test('test_fake_workspace_contents_refuse_outsider_device_property_follows_'
      'membership_changes', () async {
    final Random random = seededRandom(77506);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final MembershipTwinWorld world = await buildMembershipTwinWorld(random);
      final WorkspaceId workspaceId = pickOne(
        random,
        world.seeds.workspaceIds,
      );

      world.fakeDevices.grantWorkspaceToCurrentDevice(workspaceId);
      world.fakeContents.refuseOutsiderDevice(workspaceId);
      world.fakeDevices.withdrawWorkspace(workspaceId);

      expect(
        () => world.fakeContents.refuseOutsiderDevice(workspaceId),
        throwsA(_isOutsiderRefusal()),
      );
      await closeMembershipTwinWorld(world);
    }
  });

  test('test_refuse_device_outside_workspace_property_refuses_iff_not_'
      'joined', () {
    final Random random = seededRandom(77507);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkspaceId> joined = randomDeviceWorkspaces(random);
      final FakeDeviceRepository devices = _buildDevices(random, joined);
      final WorkspaceId asked = random.nextBool() && joined.isNotEmpty
          ? pickOne(random, joined)
          : WorkspaceId(randomText(random));

      if (joined.contains(asked)) {
        refuseDeviceOutsideWorkspace(devices, asked);
      } else {
        expect(
          () => refuseDeviceOutsideWorkspace(devices, asked),
          throwsA(_isOutsiderRefusal()),
        );
      }
    }
  });

  test('test_refuse_device_outside_workspace_property_names_the_server_'
      'reason', () {
    expect(outsiderDeviceProblem, 'the device is not in that workspace');
    final Random random = seededRandom(77508);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository devices = _buildDevices(
        random,
        const <WorkspaceId>[],
      );
      expect(
        () => refuseDeviceOutsideWorkspace(
          devices,
          WorkspaceId(randomText(random)),
        ),
        throwsA(_isOutsiderRefusal()),
      );
    }
  });

  test('test_refuse_device_outside_workspace_property_changes_no_'
      'device', () {
    final Random random = seededRandom(77509);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkspaceId> joined = randomDeviceWorkspaces(random);
      final FakeDeviceRepository devices = _buildDevices(random, joined);
      final List<Device> before = devices.listDevices();

      expect(
        () => refuseDeviceOutsideWorkspace(
          devices,
          WorkspaceId('never-${randomText(random)}'),
        ),
        throwsA(_isOutsiderRefusal()),
      );

      expect(identical(devices.listDevices(), before), isTrue);
    }
  });
}
