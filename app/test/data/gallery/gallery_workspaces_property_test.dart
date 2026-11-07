import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import 'support/gallery_records.dart';

const String _gitHubHost = 'github.com';
const String _pathSeparator = '/';
const String _defaultBranch = 'main';
const int _addressPartCount = 3;

void main() {
  test('test_gallery_workspaces_property_names_and_ids_are_unique', () {
    final List<String> names = <String>[
      for (final Workspace workspace in galleryWorkspaces) workspace.name,
    ];

    for (final String name in names) {
      expect(describeNameProblem(name), isNull, reason: name);
    }
    expect(hasNoRepeats(names), isTrue);
    final List<WorkspaceId> identifiers = <WorkspaceId>[
      for (final Workspace workspace in galleryWorkspaces) workspace.id,
    ];
    expect(hasNoRepeats(identifiers), isTrue);
  });

  test('test_gallery_workspaces_property_reach_the_listed_app_server', () {
    for (final Workspace workspace in galleryWorkspaces) {
      final String address = workspace.appServerAddress;

      expect(describeServerAddressProblem(address), isNull);
      expect(address, galleryAppServerStatus.address);
    }
    expect(
      galleryAppServerStatus.lastConnectedAt.isAfter(galleryNow),
      isFalse,
    );
  });

  test('test_gallery_workspaces_property_protect_the_default_files', () {
    for (final Workspace workspace in galleryWorkspaces) {
      expect(
        workspace.protectedFiles,
        containsAll(galleryDefaultProtectedFiles),
      );
      expect(hasNoRepeats(workspace.protectedFiles), isTrue);
    }
    expect(hasNoRepeats(galleryDefaultProtectedFiles), isTrue);
  });

  test('test_gallery_projects_property_names_are_unique_in_a_workspace', () {
    final List<String> workspaceAndName = <String>[
      for (final Project project in galleryProjects)
        '${project.workspaceId.value} ${project.name}',
    ];

    for (final Project project in galleryProjects) {
      expect(describeNameProblem(project.name), isNull, reason: project.name);
      findGalleryWorkspace(project.workspaceId);
    }
    expect(hasNoRepeats(workspaceAndName), isTrue);
    final List<ProjectId> identifiers = <ProjectId>[
      for (final Project project in galleryProjects) project.id,
    ];
    expect(hasNoRepeats(identifiers), isTrue);
  });

  test('test_gallery_projects_property_repository_addresses_are_'
      'canonical', () {
    for (final Project project in galleryProjects) {
      final List<String> addresses = <String>[
        for (final Repository repository in project.repositories)
          repository.address,
      ];

      expect(addresses, isNotEmpty);
      expect(hasNoRepeats(addresses), isTrue);
      for (final Repository repository in project.repositories) {
        expect(parseRepositoryAddress(repository.address), repository.address);
        expect(repository.defaultBranch.trim(), isNotEmpty);
      }
    }
  });

  test('test_gallery_app_server_group_property_one_active_server', () {
    final List<AppServerMember> members = galleryAppServerGroup.members;
    final List<AppServerMember> activeMembers = <AppServerMember>[
      for (final AppServerMember member in members)
        if (member.standing == ServerStanding.active) member,
    ];

    final List<DeviceId> memberIds = <DeviceId>[
      for (final AppServerMember member in members) member.deviceId,
    ];

    expect(activeMembers.length, 1);
    expect(hasNoRepeats(memberIds), isTrue);
  });

  test('test_gallery_app_server_group_property_backups_hold_a_verified_'
      'copy', () {
    for (final AppServerMember member in galleryAppServerGroup.members) {
      final Device device = findGalleryDevice(member.deviceId);
      final BackupCopy? copy = member.copy;
      final bool isBackup = member.standing == ServerStanding.backup;

      expect(copy != null, isBackup, reason: device.name);
      if (copy == null) {
        continue;
      }
      expect(copy.changesBehind, greaterThanOrEqualTo(0));
      expect(copy.verifiedAt.isAfter(device.lastSeen), isFalse);
      expect(copy.verifiedAt.isBefore(device.pairedAt), isFalse);
    }
  });

  test('test_build_git_hub_repository_property_lives_on_github_with_a_'
      'default_branch', () {
    for (final Project project in galleryProjects) {
      for (final Repository repository in project.repositories) {
        final List<String> parts = repository.address.split(_pathSeparator);

        expect(parts.first, _gitHubHost, reason: repository.address);
        expect(parts.length, _addressPartCount);
        expect(repository.defaultBranch, _defaultBranch);
      }
    }
  });
}
