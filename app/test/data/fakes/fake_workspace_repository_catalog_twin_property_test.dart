import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/catalog_twin_checks.dart';
import 'support/catalog_twin_steps.dart';
import 'support/catalog_twin_world.dart';

const String _typePrefix = 'test_fake_workspace_repository';
const int _sequenceIterations = 25;
const int _longestSequence = 5;

WorkspaceId _pickWorkspaceId(Random random, CatalogTwinWorld world) {
  final List<Workspace> listed = world.nodeWorkspaces.listWorkspaces();
  return pickOne(random, listed).id;
}

bool _isMemberAnywhere(CatalogTwinWorld world, WorkspaceId workspaceId) {
  for (final Device device in world.fakeDevices.listDevices()) {
    if (device.workspaces.contains(workspaceId)) {
      return true;
    }
  }
  return false;
}

void main() {
  test('${_typePrefix}_delete_workspace_property_sequences_end_like_the_'
      'node', () async {
    final Random random = seededRandom(92201);
    int deletedCount = 0;

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final CatalogTwinWorld world = await buildCatalogTwinWorld(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        if (random.nextInt(3) == 0) {
          await stopRandomRunInBoth(random, world);
        } else {
          final bool isRefused = await deleteWorkspaceInBoth(
            world,
            _pickWorkspaceId(random, world),
          );
          deletedCount += isRefused ? 0 : 1;
        }
        await expectCatalogTwinsAgree(world);
      }
      closeCatalogTwinWorld(world);
    }

    expect(deletedCount, greaterThan(0));
  });

  test('${_typePrefix}_delete_workspace_property_withdraws_it_from_every_'
      'device', () async {
    final Random random = seededRandom(92202);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final CatalogTwinWorld world = await buildCatalogTwinWorld(random);
      await stopEveryRunInBoth(random, world);
      final WorkspaceId doomed = _pickWorkspaceId(random, world);
      final List<WorkspaceId> others = <WorkspaceId>[
        for (final WorkspaceId workspaceId in world.seeds.workspaceIds)
          if (workspaceId != doomed) workspaceId,
      ];

      final bool isRefused = await deleteWorkspaceInBoth(world, doomed);

      expect(isRefused, others.isEmpty);
      expect(_isMemberAnywhere(world, doomed), others.isEmpty);
      for (final WorkspaceId kept in others) {
        expect(_isMemberAnywhere(world, kept), isTrue);
      }
      await expectCatalogTwinsAgree(world);
      closeCatalogTwinWorld(world);
    }
  });

  test('${_typePrefix}_create_workspace_property_grants_it_to_this_device_'
      'so_it_can_add_members', () async {
    final Random random = seededRandom(92203);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final CatalogTwinWorld world = await buildCatalogTwinWorld(random);
      final Workspace created = await world.fakeWorkspaces.createWorkspace(
        name: 'made-$i',
      );

      final Device current = world.fakeDevices.currentDevice();
      final List<WorkspaceId> grants = <WorkspaceId>[
        for (final WorkspaceId joined in current.workspaces)
          if (joined == created.id) joined,
      ];
      expect(grants, <WorkspaceId>[created.id]);
      await world.fakeWorkspaces.deleteWorkspace(created.id);
      expect(_isMemberAnywhere(world, created.id), isFalse);
      closeCatalogTwinWorld(world);
    }
  });
}
