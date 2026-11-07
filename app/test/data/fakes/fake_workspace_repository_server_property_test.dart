import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workspace_inputs.dart';

void main() {
  test('test_find_app_server_status_property_returns_the_seed', () {
    final Random random = seededRandom(68101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);

      expect(
        seeded.repository.findAppServerStatus(),
        same(galleryAppServerStatus),
      );
    }
  });

  test('test_find_app_server_status_property_online_after_retry', () async {
    final Random random = seededRandom(68102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);

      final AppServerStatus retried = await seeded.repository.retryAppServer();

      expect(seeded.repository.findAppServerStatus(), same(retried));
      expect(retried.state, AppServerState.online);
    }
  });

  test('test_find_app_server_status_property_edits_leave_it', () async {
    final Random random = seededRandom(68103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final AppServerStatus before = seeded.repository.findAppServerStatus();

      await seeded.repository.createWorkspace(name: 'team-$i');
      await seeded.repository.switchWorkspace(
        pickOne(random, seeded.workspaces).id,
      );

      expect(seeded.repository.findAppServerStatus(), same(before));
    }
  });

  test('test_retry_app_server_property_keeps_address_and_pace', () async {
    final Random random = seededRandom(68104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final AppServerStatus before = seeded.repository.findAppServerStatus();

      final AppServerStatus retried = await seeded.repository.retryAppServer();

      expect(retried.address, before.address);
      expect(retried.retryInterval, before.retryInterval);
      expect(retried.lastConnectedAt, galleryNow);
    }
  });

  test('test_retry_app_server_property_retrying_is_idempotent', () async {
    final Random random = seededRandom(68105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);

      final AppServerStatus once = await seeded.repository.retryAppServer();
      final AppServerStatus twice = await seeded.repository.retryAppServer();

      expect(twice.state, once.state);
      expect(twice.address, once.address);
      expect(twice.lastConnectedAt, once.lastConnectedAt);
    }
  });

  test('test_retry_app_server_property_notifies_once', () async {
    final Random random = seededRandom(68106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);

      await seeded.repository.retryAppServer();

      expect(notifications.count, 1);
    }
  });

  test('test_find_app_server_group_property_returns_the_seed', () {
    final Random random = seededRandom(68107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);

      expect(
        buildGroupWorkspaceRepository(group).findAppServerGroup(),
        same(group),
      );
    }
  });

  test('test_find_app_server_group_property_refusals_keep_it', () async {
    final Random random = seededRandom(68108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      final FakeWorkspaceRepository repository = buildGroupWorkspaceRepository(
        group,
      );

      if (predictStartBackupProblem(group) != null) {
        await expectLater(repository.startServerBackup(), throwsStateError);
        expect(repository.findAppServerGroup(), same(group));
      }
      if (predictStopBackupProblem(group) != null) {
        await expectLater(repository.stopServerBackup(), throwsStateError);
        expect(repository.findAppServerGroup(), same(group));
      }
    }
  });

  test('test_find_app_server_group_property_shows_the_change', () async {
    final Random random = seededRandom(68109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      final FakeWorkspaceRepository repository = buildGroupWorkspaceRepository(
        group,
      );
      if (predictStartBackupProblem(group) != null) {
        continue;
      }

      final AppServerGroup started = await repository.startServerBackup();

      expect(repository.findAppServerGroup(), same(started));
    }
  });

  test('test_start_server_backup_property_refuses_like_the_node', () async {
    final Random random = seededRandom(68110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      final FakeWorkspaceRepository repository = buildGroupWorkspaceRepository(
        group,
      );
      final String? problem = predictStartBackupProblem(group);

      if (problem == null) {
        final AppServerGroup started = await repository.startServerBackup();
        expect(started.thisDeviceStanding, ThisDeviceStanding.backup);
      } else {
        await expectLater(
          repository.startServerBackup(),
          throwsRefusalWith(problem),
        );
      }
    }
  });

  test('test_start_server_backup_property_adds_this_device_once', () async {
    final Random random = seededRandom(68111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      if (predictStartBackupProblem(group) != null) {
        continue;
      }
      final FakeWorkspaceRepository repository = buildGroupWorkspaceRepository(
        group,
      );

      final AppServerGroup started = await repository.startServerBackup();

      expect(describeServerMembers(started), <String>[
        ...describeServerMembers(group),
        '${thisWorkspaceDeviceId.value} ${ServerStanding.backup.name}',
      ]);
      await expectLater(
        repository.startServerBackup(),
        throwsRefusalWith(alreadyKeepingServerProblem),
      );
    }
  });

  test('test_start_server_backup_property_keeps_client_choice', () async {
    final Random random = seededRandom(68112);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = randomAppServerGroup(random);
      if (predictStartBackupProblem(group) != null) {
        continue;
      }

      final AppServerGroup started = await buildGroupWorkspaceRepository(group)
          .startServerBackup();

      expect(started.canKeepBackup, group.canKeepBackup);
    }
  });
}
