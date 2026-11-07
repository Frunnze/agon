import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/server_group_values.dart'
    as node;
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/domain_model_properties.dart';

const int _largestChangesBehind = 1 << 53;
const int _largestRandomChangesBehind = 1 << 32;
const int _hugeCountSpread = 1 << 16;
const int _largestServerCount = 6;
const DeviceId _sampleDeviceId = DeviceId('server-device');

node.BackupCopyView? _randomNodeCopy(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return node.BackupCopyView(
    changesBehind: random.nextInt(_largestRandomChangesBehind),
    verifiedAt: randomPreciseMoment(random),
  );
}

node.AppServerView _randomNodeServer(Random random) {
  return node.AppServerView(
    deviceId: DeviceId(randomHostileText(random)),
    standing: pickOne(random, node.ServerStanding.values),
    copy: _randomNodeCopy(random),
  );
}

node.AppServersView _randomHostileNodeView(Random random) {
  final List<node.AppServerView> servers = <node.AppServerView>[];
  final int serverCount = random.nextInt(_largestServerCount);
  for (int i = 0; i < serverCount; i += 1) {
    servers.add(_randomNodeServer(random));
  }
  if (servers.isNotEmpty && random.nextBool()) {
    servers.add(servers.first);
  }
  return node.AppServersView(
    servers: servers,
    thisDevice: pickOne(random, node.ThisDeviceStanding.values),
    canKeepBackup: random.nextBool(),
  );
}

ServerStanding _mapStandingThroughGroup(node.ServerStanding standing) {
  final node.AppServersView view = node.AppServersView(
    servers: <node.AppServerView>[
      node.AppServerView(
        deviceId: _sampleDeviceId,
        standing: standing,
        copy: null,
      ),
    ],
    thisDevice: node.ThisDeviceStanding.none,
    canKeepBackup: false,
  );
  return mapAppServerGroupFromNode(view).members.single.standing;
}

ThisDeviceStanding _mapThisDeviceThroughGroup(
  node.ThisDeviceStanding standing,
) {
  final node.AppServersView view = node.AppServersView(
    servers: const <node.AppServerView>[],
    thisDevice: standing,
    canKeepBackup: false,
  );
  return mapAppServerGroupFromNode(view).thisDeviceStanding;
}

List<Object?> _describeNodeCopy(node.BackupCopyView? copy) {
  if (copy == null) {
    return const <Object?>[];
  }
  return <Object?>[copy.changesBehind, copy.verifiedAt];
}

List<Object?> _describeCopy(BackupCopy? copy) {
  if (copy == null) {
    return const <Object?>[];
  }
  return <Object?>[copy.changesBehind, copy.verifiedAt];
}

void main() {
  testNodeEnumMappingProperties(
    const NodeEnumMapping<ServerStanding, node.ServerStanding>(
      testNamePrefix: 'test_map_server_standing_from_node_property',
      choices: ServerStanding.values,
      nodeChoices: node.ServerStanding.values,
      mapFromNode: _mapStandingThroughGroup,
    ),
  );

  testNodeEnumMappingProperties(
    const NodeEnumMapping<ThisDeviceStanding, node.ThisDeviceStanding>(
      testNamePrefix: 'test_map_this_device_standing_from_node_property',
      choices: ThisDeviceStanding.values,
      nodeChoices: node.ThisDeviceStanding.values,
      mapFromNode: _mapThisDeviceThroughGroup,
    ),
  );

  test('test_map_backup_copy_from_node_property_absent_stays_absent', () {
    final Random random = seededRandom(73801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AppServersView view = _randomHostileNodeView(random);

      final AppServerGroup group = mapAppServerGroupFromNode(view);

      for (int index = 0; index < view.servers.length; index += 1) {
        final bool isCopyAbsent = view.servers[index].copy == null;
        expect(group.members[index].copy == null, isCopyAbsent);
      }
    }
  });

  test('test_map_backup_copy_from_node_property_keeps_huge_counts', () {
    final Random random = seededRandom(73802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.BackupCopyView copy = node.BackupCopyView(
        changesBehind:
            _largestChangesBehind - random.nextInt(_hugeCountSpread),
        verifiedAt: randomPreciseMoment(random),
      );
      final node.AppServersView view = node.AppServersView(
        servers: <node.AppServerView>[
          node.AppServerView(
            deviceId: _sampleDeviceId,
            standing: pickOne(random, node.ServerStanding.values),
            copy: copy,
          ),
        ],
        thisDevice: pickOne(random, node.ThisDeviceStanding.values),
        canKeepBackup: random.nextBool(),
      );

      final AppServerMember member = mapAppServerGroupFromNode(view)
          .members
          .single;

      expect(_describeCopy(member.copy), _describeNodeCopy(copy));
    }
  });

  test(
    'test_map_backup_copy_from_node_property_each_member_keeps_its_own',
    () {
      final Random random = seededRandom(73803);

      for (int i = 0; i < propertyIterations; i += 1) {
        final node.AppServersView view = _randomHostileNodeView(random);

        final AppServerGroup group = mapAppServerGroupFromNode(view);

        expect(
          <List<Object?>>[
            for (final AppServerMember member in group.members)
              _describeCopy(member.copy),
          ],
          <List<Object?>>[
            for (final node.AppServerView server in view.servers)
              _describeNodeCopy(server.copy),
          ],
        );
      }
    },
  );

  test('test_map_app_server_group_from_node_property_keeps_hostile_order', () {
    final Random random = seededRandom(73804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AppServersView view = _randomHostileNodeView(random);

      final AppServerGroup group = mapAppServerGroupFromNode(view);

      expect(
        <Object?>[
          for (final AppServerMember member in group.members)
            <Object?>[member.deviceId, member.standing.name],
        ],
        <Object?>[
          for (final node.AppServerView server in view.servers)
            <Object?>[server.deviceId, server.standing.name],
        ],
      );
      expect(group.thisDeviceStanding.name, view.thisDevice.name);
      expect(group.canKeepBackup, view.canKeepBackup);
    }
  });
}
