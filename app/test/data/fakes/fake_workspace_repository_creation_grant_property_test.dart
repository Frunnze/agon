import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_world_inputs.dart';

const String _typePrefix = 'test_fake_workspace_repository';

List<WorkspaceId> _membershipsOf(WorkspaceWorld world) {
  return world.deviceRepository.currentDevice().workspaces;
}

void main() {
  test('${_typePrefix}_create_workspace_property_linked_contents_grant_the_'
      'new_workspace_to_this_device', () async {
    final Random random = seededRandom(93101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      final List<WorkspaceId> before = _membershipsOf(world);

      final Workspace created = await world.workspaceRepository
          .createWorkspace(name: 'made-$i');

      expect(_membershipsOf(world), <WorkspaceId>[...before, created.id]);
    }
  });

  test('${_typePrefix}_create_workspace_property_an_unlinked_repository_'
      'grants_nothing', () async {
    final Random random = seededRandom(93102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      final FakeWorkspaceRepository unlinked = buildWorkspaceRepository(
        workspaces: world.workspaceRepository.listWorkspaces(),
        currentWorkspaceId: world.workspaceRepository.currentWorkspace().id,
        appServerGroup: randomAppServerGroup(random),
      );
      final List<Device> before = world.deviceRepository.listDevices();

      await unlinked.createWorkspace(name: 'made-$i');

      expect(world.deviceRepository.listDevices(), orderedEquals(before));
    }
  });

  test('${_typePrefix}_create_workspace_property_a_refused_name_grants_'
      'nothing', () async {
    final Random random = seededRandom(93103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      final List<Device> before = world.deviceRepository.listDevices();
      final String badName = pickOne(random, <String>['', '  ', 'n' * 41]);

      await expectLater(
        world.workspaceRepository.createWorkspace(name: badName),
        throwsArgumentError,
      );

      expect(world.deviceRepository.listDevices(), orderedEquals(before));
    }
  });
}
