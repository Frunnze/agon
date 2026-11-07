import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workspace_world_inputs.dart';

const String _typePrefix = 'test_fake_workspace_contents';

List<WorkspaceId> _membershipsOf(WorkspaceWorld world) {
  return world.deviceRepository.currentDevice().workspaces;
}

Set<SkillId> _storedSkillIds(WorkspaceWorld world) {
  return <SkillId>{for (final Skill skill in world.skills) skill.id};
}

Future<Set<SkillId>> _listSkillIdsEverywhere(WorkspaceWorld world) async {
  final Set<SkillId> listed = <SkillId>{};
  for (final WorkspaceId workspaceId in listWorldWorkspaceIds(
    world.workspaceRepository,
  )) {
    await world.workspaceRepository.switchWorkspace(workspaceId);
    for (final Skill skill in world.skillRepository.listSkills()) {
      listed.add(skill.id);
    }
  }
  return listed;
}

void main() {
  test('${_typePrefix}_remove_contents_property_withdraws_the_workspace_'
      'from_every_device', () async {
    final Random random = seededRandom(92601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);
      final WorkspaceWorld world = picked.world;
      final List<WorkspaceId> before = _membershipsOf(world);

      await world.contents.removeContents(
        deletedWorkspaceId: picked.idle.id,
        remainingWorkspaceIds: listOtherWorkspaceIds(world, picked.idle.id),
      );

      expect(_membershipsOf(world), <WorkspaceId>[
        for (final WorkspaceId workspaceId in before)
          if (workspaceId != picked.idle.id) workspaceId,
      ]);
    }
  });

  test('${_typePrefix}_remove_contents_property_drops_removed_skills_from_'
      'the_remaining_tasks', () async {
    final Random random = seededRandom(92602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);
      final WorkspaceWorld world = picked.world;

      await world.contents.removeContents(
        deletedWorkspaceId: picked.idle.id,
        remainingWorkspaceIds: listOtherWorkspaceIds(world, picked.idle.id),
      );

      final Set<SkillId> kept = await _listSkillIdsEverywhere(world);
      final Set<SkillId> removed = _storedSkillIds(world).difference(kept);
      for (final Task task in world.taskRepository.listTasksAndJobs()) {
        expect(task.skills.any(removed.contains), isFalse);
      }
    }
  });

  test('${_typePrefix}_constructor_property_wires_the_device_repository_'
      'that_receives_the_withdrawal', () async {
    final Random random = seededRandom(92603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorldWithIdle picked = buildWorldWithIdleWorkspace(random);
      final WorkspaceWorld world = picked.world;
      final NotificationCounter notifications = NotificationCounter();
      world.deviceRepository.addListener(notifications.record);

      await world.contents.removeContents(
        deletedWorkspaceId: picked.idle.id,
        remainingWorkspaceIds: listOtherWorkspaceIds(world, picked.idle.id),
      );

      expect(notifications.count, 1);
    }
  });

  test('${_typePrefix}_grant_created_workspace_property_makes_this_device_'
      'a_member', () {
    final Random random = seededRandom(92604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      final WorkspaceId created = WorkspaceId('created-${randomText(random)}');
      final List<WorkspaceId> before = _membershipsOf(world);

      world.contents.grantCreatedWorkspace(created);

      expect(_membershipsOf(world), <WorkspaceId>[...before, created]);
    }
  });

  test('${_typePrefix}_grant_created_workspace_property_is_idempotent', () {
    final Random random = seededRandom(92605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      final WorkspaceId created = WorkspaceId('created-$i');

      world.contents.grantCreatedWorkspace(created);
      final List<WorkspaceId> once = _membershipsOf(world);
      world.contents.grantCreatedWorkspace(created);

      expect(_membershipsOf(world), once);
    }
  });

  test('${_typePrefix}_grant_created_workspace_property_leaves_projects_'
      'library_and_work_untouched', () {
    final Random random = seededRandom(92606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceWorld world = buildWorkspaceWorld(random);
      final List<Device> devicesBefore = world.deviceRepository.listDevices();

      world.contents.grantCreatedWorkspace(WorkspaceId('created-$i'));

      for (final Project project in world.projects) {
        expect(world.projectRepository.findProject(project.id), same(project));
      }
      expect(
        world.taskRepository.listTasksAndJobs(),
        hasLength(world.work.tasks.length),
      );
      expect(world.deviceRepository.listDevices(), hasLength(1));
      expect(devicesBefore, hasLength(1));
    }
  });
}
