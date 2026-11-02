import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/server_group_values.dart'
    as node;
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/random_account_json.dart';
import '../../support/random_inputs.dart';

void main() {
  test('test_map_app_server_group_from_node_property_keeps_members', () {
    final Random random = seededRandom(9701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final node.AppServersView view = node.AppServersView.fromJson(
        randomAppServersJson(random),
      );

      final AppServerGroup group = mapAppServerGroupFromNode(view);

      expect(group.members.length, view.servers.length);
      for (int index = 0; index < view.servers.length; index += 1) {
        final node.AppServerView server = view.servers[index];
        final AppServerMember member = group.members[index];
        expect(member.deviceId, server.deviceId);
        expect(member.standing.name, server.standing.name);
      }
      expect(group.thisDeviceStanding.name, view.thisDevice.name);
      expect(group.canKeepBackup, view.canKeepBackup);
    }
  });

  test('test_map_app_server_group_from_node_property_members_frozen', () {
    final Random random = seededRandom(9702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerGroup group = mapAppServerGroupFromNode(
        node.AppServersView.fromJson(randomAppServersJson(random)),
      );
      const AppServerMember extra = AppServerMember(
        deviceId: DeviceId('extra-server'),
        standing: ServerStanding.backup,
      );

      expect(() => group.members.add(extra), throwsUnsupportedError);
    }
  });
}
