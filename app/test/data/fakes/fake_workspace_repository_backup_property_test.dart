import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workspace_inputs.dart';

void main() {
  test('test_stop_server_backup_property_refuses_like_the_node', () async {
    final Random random = seededRandom(68113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      final FakeWorkspaceRepository repository = buildGroupWorkspaceRepository(
        group,
      );
      final String? problem = predictStopBackupProblem(group);

      if (problem == null) {
        final AppServerGroup stopped = await repository.stopServerBackup();
        expect(stopped.thisDeviceStanding, ThisDeviceStanding.none);
      } else {
        await expectLater(
          repository.stopServerBackup(),
          throwsRefusalWith(problem),
        );
      }
    }
  });

  test('test_stop_server_backup_property_removes_only_this_device', () async {
    final Random random = seededRandom(68114);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      if (predictStopBackupProblem(group) != null) {
        continue;
      }

      final AppServerGroup stopped = await buildGroupWorkspaceRepository(group)
          .stopServerBackup();

      final List<String> expected = <String>[
        for (final AppServerMember member in group.members)
          if (member.deviceId != thisWorkspaceDeviceId)
            '${member.deviceId.value} ${member.standing.name}',
      ];
      expect(describeServerMembers(stopped), orderedEquals(expected));
    }
  });

  test('test_stop_server_backup_property_undoes_a_start', () async {
    final Random random = seededRandom(68115);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      if (predictStartBackupProblem(group) != null) {
        continue;
      }
      final FakeWorkspaceRepository repository = buildGroupWorkspaceRepository(
        group,
      );

      await repository.startServerBackup();
      final AppServerGroup stopped = await repository.stopServerBackup();

      expect(describeServerMembers(stopped), describeServerMembers(group));
      expect(stopped.thisDeviceStanding, group.thisDeviceStanding);
    }
  });

  test('test_replace_app_server_group_property_notifies_once', () async {
    final Random random = seededRandom(68116);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      final FakeWorkspaceRepository repository = buildGroupWorkspaceRepository(
        group,
      );
      final NotificationCounter notifications = NotificationCounter();
      repository.addListener(notifications.record);
      final bool canStart = predictStartBackupProblem(group) == null;
      final bool canStop = predictStopBackupProblem(group) == null;

      if (canStart) {
        await repository.startServerBackup();
      } else if (canStop) {
        await repository.stopServerBackup();
      }

      expect(notifications.count, canStart || canStop ? 1 : 0);
    }
  });

  test('test_replace_app_server_group_property_members_frozen', () async {
    final Random random = seededRandom(68117);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      if (predictStopBackupProblem(group) != null) {
        continue;
      }

      final AppServerGroup stopped = await buildGroupWorkspaceRepository(group)
          .stopServerBackup();

      expect(stopped.members.clear, throwsUnsupportedError);
    }
  });

  test('test_replace_app_server_group_property_leaves_workspaces', () async {
    final Random random = seededRandom(68118);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      final FakeWorkspaceRepository repository = buildGroupWorkspaceRepository(
        group,
      );
      final Workspace current = repository.currentWorkspace();

      if (predictStartBackupProblem(group) == null) {
        await repository.startServerBackup();
      }
      if (predictStopBackupProblem(repository.findAppServerGroup()) == null) {
        await repository.stopServerBackup();
      }

      expect(repository.currentWorkspace(), same(current));
      expect(repository.listWorkspaces(), orderedEquals(galleryWorkspaces));
    }
  });
}
