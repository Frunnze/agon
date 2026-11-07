import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/workspace_membership.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import 'support/device_inputs.dart';
import 'support/membership_twin_world.dart';
import 'support/workspace_work_checks.dart';

const String _typePrefix = 'test_fake_project_repository';
const int _sequenceIterations = 25;
const int _longestSequence = 4;

Matcher _isOutsiderRefusal() {
  return isA<StateError>().having(
    (StateError error) => error.message,
    'message',
    outsiderDeviceProblem,
  );
}

ProjectId _pickProjectId(Random random, MembershipTwinWorld world) {
  final List<String> listed = listSimulatedProjectIds(world);
  if (listed.isEmpty || random.nextInt(6) == 0) {
    return const ProjectId('project-missing');
  }
  return ProjectId(pickOne(random, listed));
}

FakeDeviceRepository _buildDevices(Random random, List<WorkspaceId> joined) {
  final Device device = randomDeviceWithId(
    random,
    deviceTestThisDevice,
    isRevoked: false,
  ).withWorkspaces(joined);
  return buildDeviceRepository(<Device>[device]);
}

Project _randomProject(Random random) {
  return Project(
    id: ProjectId('project-${randomText(random)}'),
    workspaceId: WorkspaceId('workspace-${random.nextInt(3)}'),
    name: 'project',
    repositories: const <Repository>[],
    approvalPolicy: null,
  );
}

FakeProjectRepository _buildLonelyProjects(Project project) {
  return FakeProjectRepository(
    projects: <Project>[project],
    taskWork: buildEmptyTaskWork(),
  );
}

void main() {
  test('${_typePrefix}_delete_project_property_refuses_outsiders_like_the_'
      'node', () async {
    final Random random = seededRandom(78201);
    int refusedCount = 0;

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final MembershipTwinWorld world = await buildMembershipTwinWorld(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final ProjectId projectId = _pickProjectId(random, world);
        final bool isRefused = await expectSameRefusal(
          fakeStep: () => world.fakeProjects.deleteProject(projectId),
          nodeStep: () => world.nodeProjects.deleteProject(projectId),
          reason: projectId.value,
        );
        refusedCount += isRefused ? 1 : 0;

        expect(
          listFakeProjectIds(world),
          unorderedEquals(listSimulatedProjectIds(world)),
        );
      }
      await closeMembershipTwinWorld(world);
    }

    expect(refusedCount, greaterThan(0));
  });

  test('${_typePrefix}_delete_project_property_outsider_refusal_comes_'
      'first_and_changes_nothing', () async {
    final Random random = seededRandom(78202);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final MembershipTwinWorld world = await buildMembershipTwinWorld(random);
      final List<String> before = listFakeProjectIds(world);

      for (final Project project in world.seeds.projects) {
        if (!world.memberWorkspaceIds.contains(project.workspaceId)) {
          await expectLater(
            world.fakeProjects.deleteProject(project.id),
            throwsA(_isOutsiderRefusal()),
          );
        }
      }

      expect(listFakeProjectIds(world), before);
      await closeMembershipTwinWorld(world);
    }
  });

  test('${_typePrefix}_delete_project_property_members_delete_idle_'
      'projects', () async {
    final Random random = seededRandom(78203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = _randomProject(random);
      final FakeProjectRepository projects = _buildLonelyProjects(project);
      projects.linkDevices(
        _buildDevices(random, <WorkspaceId>[project.workspaceId]),
      );

      await projects.deleteProject(project.id);

      expect(projects.listProjects(project.workspaceId), isEmpty);
    }
  });

  test('${_typePrefix}_link_devices_property_unlinked_never_asks_for_'
      'membership', () async {
    final Random random = seededRandom(78204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = _randomProject(random);
      final FakeProjectRepository projects = _buildLonelyProjects(project);

      await projects.deleteProject(project.id);

      expect(projects.listProjects(project.workspaceId), isEmpty);
    }
  });

  test('${_typePrefix}_link_devices_property_follows_later_joins', () async {
    final Random random = seededRandom(78205);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = _randomProject(random);
      final FakeProjectRepository projects = _buildLonelyProjects(project);
      final FakeDeviceRepository devices = _buildDevices(
        random,
        const <WorkspaceId>[],
      );
      projects.linkDevices(devices);
      await expectLater(
        projects.deleteProject(project.id),
        throwsA(_isOutsiderRefusal()),
      );

      devices.grantWorkspaceToCurrentDevice(project.workspaceId);
      await projects.deleteProject(project.id);

      expect(projects.listProjects(project.workspaceId), isEmpty);
    }
  });

  test('${_typePrefix}_link_devices_property_latest_link_wins', () async {
    final Random random = seededRandom(78206);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = _randomProject(random);
      final FakeProjectRepository projects = _buildLonelyProjects(project);
      final bool isMemberAtLast = random.nextBool();
      projects.linkDevices(
        _buildDevices(random, <WorkspaceId>[
          if (!isMemberAtLast) project.workspaceId,
        ]),
      );
      projects.linkDevices(
        _buildDevices(random, <WorkspaceId>[
          if (isMemberAtLast) project.workspaceId,
        ]),
      );

      final Future<void> deleting = projects.deleteProject(project.id);

      if (isMemberAtLast) {
        await deleting;
        expect(projects.listProjects(project.workspaceId), isEmpty);
      } else {
        await expectLater(deleting, throwsA(_isOutsiderRefusal()));
      }
    }
  });
}
