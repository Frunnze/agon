import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';

const DeviceId _thisDeviceId = GalleryDeviceIds.airLaptop;
const List<DeviceId> _otherServerIds = <DeviceId>[
  GalleryDeviceIds.mainMac,
  GalleryDeviceIds.oldMacbook,
  DeviceId('unknown-server'),
];

AppServerGroup _randomGroup(Random random) {
  final List<AppServerMember> members = <AppServerMember>[];
  for (final DeviceId deviceId in _otherServerIds) {
    if (random.nextBool()) {
      final ServerStanding standing = members.isEmpty
          ? ServerStanding.active
          : ServerStanding.backup;
      members.add(AppServerMember(deviceId: deviceId, standing: standing));
    }
  }
  return AppServerGroup(
    members: members,
    thisDeviceStanding: ThisDeviceStanding.none,
    canKeepBackup: random.nextBool(),
  );
}

FakeWorkspaceRepository _buildRepository(AppServerGroup group) {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: GalleryWorkspaceIds.acme,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: group,
    currentDeviceId: _thisDeviceId,
    clock: FixedClock(galleryNow),
  );
}

List<String> _describeMembers(AppServerGroup group) {
  return <String>[
    for (final AppServerMember member in group.members)
      '${member.deviceId.value} ${member.standing.name}',
  ];
}

void main() {
  test('test_start_server_backup_property_adds_this_device_once', () async {
    final Random random = seededRandom(5101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = _randomGroup(random);
      final FakeWorkspaceRepository repository = _buildRepository(group);
      final bool isAllowed = group.canKeepBackup && group.members.isNotEmpty;

      if (!isAllowed) {
        await expectLater(repository.startServerBackup(), throwsStateError);
        expect(repository.findAppServerGroup(), same(group));
        continue;
      }

      final AppServerGroup started = await repository.startServerBackup();
      expect(_describeMembers(started), <String>[
        ..._describeMembers(group),
        '${_thisDeviceId.value} backup',
      ]);
      expect(started.thisDeviceStanding, ThisDeviceStanding.backup);
      expect(repository.findAppServerGroup(), same(started));
      await expectLater(repository.startServerBackup(), throwsStateError);
      expect(repository.findAppServerGroup(), same(started));
    }
  });

  test('test_stop_server_backup_property_undoes_start', () async {
    final Random random = seededRandom(5102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = AppServerGroup(
        members: _randomGroup(random).members,
        thisDeviceStanding: ThisDeviceStanding.none,
        canKeepBackup: true,
      );
      if (group.members.isEmpty) {
        continue;
      }
      final FakeWorkspaceRepository repository = _buildRepository(group);
      int notifications = 0;
      repository.addListener(() => notifications += 1);

      await repository.startServerBackup();
      final AppServerGroup stopped = await repository.stopServerBackup();

      expect(_describeMembers(stopped), _describeMembers(group));
      expect(stopped.thisDeviceStanding, ThisDeviceStanding.none);
      expect(notifications, 2);
    }
  });

  test('test_stop_server_backup_property_refused_while_active', () async {
    final Random random = seededRandom(5103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = AppServerGroup(
        members: <AppServerMember>[
          const AppServerMember(
            deviceId: _thisDeviceId,
            standing: ServerStanding.active,
          ),
          ..._randomGroup(random).members,
        ],
        thisDeviceStanding: ThisDeviceStanding.active,
        canKeepBackup: true,
      );
      final FakeWorkspaceRepository repository = _buildRepository(group);

      await expectLater(repository.stopServerBackup(), throwsStateError);
      await expectLater(repository.startServerBackup(), throwsStateError);
      expect(repository.findAppServerGroup(), same(group));
    }
  });

  test('test_gallery_app_server_group_property_members_are_clients', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppServerGroup group = dependencies.workspaceRepository
        .findAppServerGroup();
    int activeCount = 0;

    for (final AppServerMember member in group.members) {
      final Device device = dependencies.deviceRepository.findDevice(
        member.deviceId,
      );
      expect(device.role, isNot(DeviceRole.runner));
      if (member.standing == ServerStanding.active) {
        activeCount += 1;
      }
    }
    expect(activeCount, 1);
    expect(group.thisDeviceStanding, ThisDeviceStanding.none);
    expect(group.canKeepBackup, isTrue);
  });
}
