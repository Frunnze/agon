import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/presentation/server_group_text.dart';

import '../bridge/support/node_json_primitives.dart';
import '../support/random_inputs.dart';

const String _activeText =
    'Active server · relays messages and keeps the run queue. It sees only '
    'encrypted data.';
const String _backupText =
    'Backup · keeps a live copy and takes over when the active server is '
    'off.';
const String _thisDevicePrefix = 'This device · ';

AppServerMember _randomMember(Random random) {
  return AppServerMember(
    deviceId: DeviceId(randomDeviceIdText(random)),
    standing: pickOne(random, ServerStanding.values),
  );
}

List<AppServerMember> _randomMembers(Random random) {
  return <AppServerMember>[
    for (int index = 0; index < random.nextInt(6); index += 1)
      _randomMember(random),
  ];
}

void main() {
  test('test_order_app_server_members_property_actives_first_stable', () {
    final Random random = seededRandom(9441);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppServerMember> members = _randomMembers(random);

      final List<AppServerMember> ordered = orderAppServerMembers(members);

      expect(ordered.toSet(), members.toSet());
      expect(ordered.length, members.length);
      final List<AppServerMember> actives = <AppServerMember>[
        for (final AppServerMember member in members)
          if (member.standing == ServerStanding.active) member,
      ];
      final List<AppServerMember> backups = <AppServerMember>[
        for (final AppServerMember member in members)
          if (member.standing == ServerStanding.backup) member,
      ];
      expect(ordered, <AppServerMember>[...actives, ...backups]);
    }
  });

  test('test_describe_app_server_member_property_marks_this_device', () {
    final Random random = seededRandom(9442);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerMember member = _randomMember(random);
      final DeviceId otherDeviceId = DeviceId(randomDeviceIdText(random));
      final String standingText = member.standing == ServerStanding.active
          ? _activeText
          : _backupText;

      expect(
        describeAppServerMember(member, currentDeviceId: member.deviceId),
        '$_thisDevicePrefix$standingText',
      );
      if (otherDeviceId != member.deviceId) {
        expect(
          describeAppServerMember(member, currentDeviceId: otherDeviceId),
          standingText,
        );
      }
    }
  });

  test('test_describe_server_backup_hint_property_active_explains_lock', () {
    for (final ThisDeviceStanding standing in ThisDeviceStanding.values) {
      final String hint = describeServerBackupHint(standing);

      expect(hint, endsWith('.'));
      expect(
        hint == 'This computer is the active server.',
        standing == ThisDeviceStanding.active,
      );
    }
    expect(
      describeServerBackupHint(ThisDeviceStanding.none),
      'This computer keeps a live copy and takes over when the server is '
      'off.',
    );
  });
}
