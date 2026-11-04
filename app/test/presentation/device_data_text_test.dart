import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/device_data_text.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

const String _unreachableText = "Not syncing: can't reach the app server";
const String _neverCopiedText =
    'Not syncing: no copy since the server started';
const Duration _freshCopyAge = Duration(seconds: 59);

BackupCopy _randomFreshCopy(Random random) {
  return BackupCopy(
    changesBehind: random.nextInt(5000),
    verifiedAt: galleryNow.subtract(
      Duration(seconds: random.nextInt(_freshCopyAge.inSeconds + 1)),
    ),
  );
}

BackupCopy? _randomOptionalCopy(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return BackupCopy(
    changesBehind: random.nextInt(5000),
    verifiedAt: galleryNow.subtract(Duration(minutes: random.nextInt(9000))),
  );
}

AppServerMember? _randomServerMember(Random random, DeviceId deviceId) {
  if (random.nextBool()) {
    return null;
  }
  return AppServerMember(
    deviceId: deviceId,
    standing: pickOne(random, ServerStanding.values),
    copy: _randomOptionalCopy(random),
  );
}

void main() {
  test('test_describe_backup_copy_property_unreachable_is_not_syncing', () {
    final Random random = seededRandom(12001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = describeBackupCopy(
        copy: _randomOptionalCopy(random),
        serverState: AppServerState.unreachable,
        now: galleryNow,
      );

      expect(text, _unreachableText);
    }
  });

  test('test_describe_backup_copy_property_fresh_copy_counts_changes', () {
    final Random random = seededRandom(12002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final BackupCopy copy = _randomFreshCopy(random);

      final String text = describeBackupCopy(
        copy: copy,
        serverState: AppServerState.online,
        now: galleryNow,
      );

      final int behind = copy.changesBehind;
      final String expected = switch (behind) {
        0 => 'Up to date',
        1 => '1 change behind',
        _ => '$behind changes behind',
      };
      expect(text, expected);
    }
  });

  test('test_describe_backup_copy_property_stale_copy_names_its_age', () {
    final Random random = seededRandom(12003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime verifiedAt = galleryNow.subtract(
        Duration(minutes: 1 + random.nextInt(9000)),
      );
      final BackupCopy copy = BackupCopy(
        changesBehind: random.nextInt(5000),
        verifiedAt: verifiedAt,
      );

      final String text = describeBackupCopy(
        copy: copy,
        serverState: AppServerState.online,
        now: galleryNow,
      );

      final String age = describeTimeSince(verifiedAt, galleryNow);
      expect(text, 'Last copied ${age.toLowerCase()}');
    }
  });

  test('test_describe_backup_copy_property_missing_copy_is_not_syncing', () {
    final String text = describeBackupCopy(
      copy: null,
      serverState: AppServerState.online,
      now: galleryNow,
    );

    expect(text, _neverCopiedText);
  });

  test('test_find_app_server_member_property_finds_only_listed_devices', () {
    final Random random = seededRandom(12004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppServerMember> members = <AppServerMember>[
        for (final Device device in galleryDevices)
          if (random.nextBool())
            AppServerMember(
              deviceId: device.id,
              standing: pickOne(random, ServerStanding.values),
              copy: null,
            ),
      ];
      final AppServerGroup group = AppServerGroup(
        members: members,
        thisDeviceStanding: ThisDeviceStanding.none,
        canKeepBackup: random.nextBool(),
      );
      final Device device = pickOne(random, galleryDevices);

      final AppServerMember? found = findAppServerMember(
        group: group,
        deviceId: device.id,
      );

      final bool isListed = members.any(
        (AppServerMember member) => member.deviceId == device.id,
      );
      expect(found != null, isListed);
      expect(found?.deviceId ?? device.id, device.id);
    }
  });

  test('test_describe_device_role_property_server_standing_wins', () {
    final Random random = seededRandom(12005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final AppServerMember? member = _randomServerMember(random, device.id);

      final String role = describeDeviceRole(
        role: device.role,
        serverMember: member,
      );

      final String expected = switch (member?.standing) {
        null => device.role.label,
        ServerStanding.active => 'App server',
        ServerStanding.backup => 'Backup server',
      };
      expect(role, expected);
    }
  });

  test('test_describe_device_data_property_only_servers_hold_data', () {
    final Random random = seededRandom(12006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final AppServerMember? member = _randomServerMember(random, device.id);
      final AppServerState serverState = pickOne(
        random,
        AppServerState.values,
      );

      final String data = describeDeviceData(
        serverMember: member,
        serverState: serverState,
        now: galleryNow,
      );

      if (member == null) {
        expect(data, 'No copy');
        continue;
      }
      switch (member.standing) {
        case ServerStanding.active:
          expect(data, 'Holds the data');
        case ServerStanding.backup:
          final String copyText = describeBackupCopy(
            copy: member.copy,
            serverState: serverState,
            now: galleryNow,
          );
          expect(data, 'Has a copy · $copyText');
      }
    }
  });

  test('test_describe_device_presence_property_online_within_a_minute', () {
    final Random random = seededRandom(12007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final Device thisDevice = pickOne(random, galleryDevices);
      final DateTime now = galleryNow.add(
        Duration(seconds: random.nextInt(400000)),
      );

      final String presence = describeDevicePresence(
        device: device,
        thisDeviceId: thisDevice.id,
        now: now,
      );

      final bool isOnline =
          device.id == thisDevice.id ||
          now.difference(device.lastSeen) < const Duration(minutes: 1);
      if (isOnline) {
        expect(presence, 'Online');
      } else {
        final String age = describeLastSeen(device.lastSeen, now);
        expect(presence, 'Last seen ${age.toLowerCase()}');
      }
    }
  });

  test('test_describe_device_kind_line_property_marks_this_device', () {
    final Random random = seededRandom(12008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = pickOne(random, galleryDevices);
      final Device thisDevice = pickOne(random, galleryDevices);

      final String line = describeDeviceKindLine(
        device: device,
        thisDeviceId: thisDevice.id,
      );

      final String expected = device.id == thisDevice.id
          ? 'This device · ${device.kind.label}'
          : device.kind.label;
      expect(line, expected);
    }
  });

  test('test_gallery_devices_property_only_the_phone_is_a_phone', () {
    for (final Device device in galleryDevices) {
      final DeviceKind expected = device.name == 'pixel-phone'
          ? DeviceKind.phone
          : DeviceKind.computer;
      expect(device.kind, expected, reason: device.name);
    }
  });
}
