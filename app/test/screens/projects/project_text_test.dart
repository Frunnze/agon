import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';

final ScopeCatalog _catalog = ScopeCatalog(
  workspaces: galleryWorkspaces,
  projects: galleryProjects,
);

void main() {
  test('test_describe_count_property_singular_only_for_one', () {
    final Random random = seededRandom(8501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(50);
      final String text = describeCount(
        count,
        singular: 'repo',
        plural: 'repos',
      );

      expect(text, count == 1 ? '1 repo' : '$count repos');
    }
  });

  test('test_describe_repository_place_property_host_and_path_rejoin', () {
    final Random random = seededRandom(8502);
    final DeviceNames deviceNames = DeviceNames(galleryDevices);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = pickOne(random, <String>['github.com', 'a.b.c']);
      final String path = pickOne(random, <String>['acme/app', 'x/y-z']);
      final String address = '$host/$path';

      expect(describeRepositoryPlace(address, deviceNames), host);
      expect(describeRepositoryPath(address), path);
    }
    expect(
      describeRepositoryPaths(galleryProjects.first),
      'acme/app, acme/api',
    );
  });

  test('test_describe_repository_place_property_names_the_folder_device', () {
    final Random random = seededRandom(8510);
    final DeviceNames deviceNames = DeviceNames(galleryDevices);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final String name = pickOne(random, <String>['billing-ui', 'a b']);
      final String address = renderLocalFolderAddress(
        deviceId: device.id,
        path: '/Users/someone/$name',
      );
      final Project project = Project(
        id: const ProjectId('folder-project'),
        workspaceId: GalleryWorkspaceIds.acme,
        name: 'billing',
        repositories: <Repository>[
          Repository(
            address: address,
            defaultBranch: 'main',
            agentAccess: AgentAccess.readOnly,
          ),
        ],
        approvalPolicy: null,
      );

      expect(
        describeRepositoryPlace(address, deviceNames),
        'on ${device.name}',
      );
      expect(describeRepositoryPaths(project), name);
    }
    final String unknownDevice = renderLocalFolderAddress(
      deviceId: const DeviceId('0123456789abcdef'),
      path: '/x',
    );
    expect(
      describeRepositoryPlace(unknownDevice, deviceNames),
      'on 0123…cdef',
    );
  });

  test('test_describe_run_age_property_days_counted_by_calendar', () {
    final Random random = seededRandom(8503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int days = random.nextInt(30);
      final DateTime moment = DateTime(2026, 10, 29 - days, 9);
      final String text = describeRunAge(moment, galleryNow);

      if (days == 0) {
        expect(text, 'Ran today');
      } else if (days == 1) {
        expect(text, 'Ran yesterday');
      } else {
        expect(text, 'Ran $days days ago');
      }
    }
  });

  test('test_build_project_activity_label_property_running_wins', () {
    final Random random = seededRandom(8504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int running = random.nextInt(4);
      final DateTime? lastRunAt = random.nextBool()
          ? galleryNow.subtract(Duration(hours: random.nextInt(100)))
          : null;
      final StatusLabel label = buildProjectActivityLabel(
        runningTaskCount: running,
        lastRunAt: lastRunAt,
        now: galleryNow,
      );

      if (running > 0) {
        expect(label.icon, AppIconKind.spinner);
        expect(label.text, endsWith('running'));
      } else if (lastRunAt != null) {
        expect(label.tone, StatusTone.muted);
        expect(label.text, startsWith('Ran '));
      } else {
        expect(label.text, 'No runs yet');
      }
    }
    expect(
      buildProjectActivityLabel(
        runningTaskCount: 2,
        lastRunAt: null,
        now: galleryNow,
      ).text,
      '2 tasks running',
    );
  });

  test('test_build_agent_access_label_property_push_needs_approval', () {
    for (final AgentAccess access in AgentAccess.values) {
      final StatusLabel label = buildAgentAccessLabel(access);
      final bool canPush = access == AgentAccess.pushAfterApproval;

      expect(label.icon, canPush ? AppIconKind.approval : AppIconKind.lock);
      expect(label.text, describeAgentAccess(access));
    }
    expect(
      describeAgentAccess(AgentAccess.pushAfterApproval),
      'Read and push',
    );
    expect(describeAgentAccess(AgentAccess.readOnly), 'Read only');
  });

  test('test_describe_workspace_contents_property_counts_both', () {
    final Random random = seededRandom(8505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int projects = random.nextInt(5);
      final int runners = random.nextInt(5);
      final String text = describeWorkspaceContents(
        projectCount: projects,
        runnerCount: runners,
      );

      expect(text.split(' · ').length, 2);
      expect(text, startsWith('$projects project'));
    }
    expect(
      describeWorkspaceContents(projectCount: 3, runnerCount: 4),
      '3 projects · 4 runners',
    );
  });

  test('test_describe_rule_reach_property_names_the_reach', () {
    final Project acmeApp = galleryProjects.first;

    expect(
      describeRuleReach(
        scope: const Scope.everywhere(),
        project: acmeApp,
        catalog: _catalog,
      ),
      'Everywhere',
    );
    expect(
      describeRuleReach(
        scope: Scope(
          workspaces: const AllWorkspaces(),
          projects: OnlyProjects(const <ProjectId>[GalleryProjectIds.acmeApp]),
        ),
        project: acmeApp,
        catalog: _catalog,
      ),
      'This project',
    );
    expect(
      describeRuleReach(
        scope: Scope(
          workspaces: OnlyWorkspaces(const <WorkspaceId>[
            GalleryWorkspaceIds.acme,
          ]),
          projects: const AllProjects(),
        ),
        project: acmeApp,
        catalog: _catalog,
      ),
      'All acme projects',
    );
    expect(
      describeRuleReach(
        scope: Scope(
          workspaces: const AllWorkspaces(),
          projects: OnlyProjects(const <ProjectId>[
            GalleryProjectIds.acmeApp,
            GalleryProjectIds.docs,
          ]),
        ),
        project: acmeApp,
        catalog: _catalog,
      ),
      'acme-app, docs',
    );
  });

  test('test_count_workspace_runners_property_only_workspace_devices', () {
    final Random random = seededRandom(8506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = <Runner>[
        for (final Runner runner in galleryRunners)
          if (random.nextBool()) runner,
      ];
      final int acmeCount = countWorkspaceRunners(
        workspaceId: GalleryWorkspaceIds.acme,
        runners: runners,
        devices: galleryDevices,
      );

      expect(acmeCount, runners.length);
    }
    expect(
      countWorkspaceRunners(
        workspaceId: GalleryWorkspaceIds.personal,
        runners: galleryRunners,
        devices: galleryDevices,
      ),
      1,
    );
  });
}
