import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../bridge/support/random_account_json.dart';
import '../../support/random_inputs.dart';

const Duration _retryInterval = Duration(seconds: 30);

AppServerStatus _randomServerStatus(Random random) {
  return AppServerStatus(
    address: randomText(random),
    state: pickOne(random, AppServerState.values),
    lastConnectedAt: randomUtcMoment(random),
    retryInterval: _retryInterval,
  );
}

void main() {
  test('test_is_change_in_areas_property_matches_only_listed_areas', () {
    final Random random = seededRandom(9501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Set<node.ChangeArea> areas = <node.ChangeArea>{
        for (final node.ChangeArea area in node.ChangeArea.values)
          if (random.nextBool()) area,
      };
      final node.ChangeArea changed = pickOne(random, node.ChangeArea.values);
      expect(
        isChangeInAreas(node.AreaChanged(area: changed), areas),
        areas.contains(changed),
      );
      expect(
        isChangeInAreas(node.RunChanged(runId: RunId('run-$i')), areas),
        isFalse,
      );
    }
  });

  test('test_map_app_server_status_from_node_property_follows_status', () {
    final Random random = seededRandom(9503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final node.StatusView status = node.StatusView.fromJson(
        randomStatusViewJson(random),
      );
      final AppServerStatus? previous = random.nextBool()
          ? null
          : _randomServerStatus(random);
      final DateTime observedAt = randomUtcMoment(random);
      final AppServerStatus? mapped = mapAppServerStatusFromNode(
        status,
        previous: previous,
        observedAt: observedAt,
        retryInterval: _retryInterval,
      );
      final String? address = status.serverAddress;
      if (address == null) {
        expect(mapped, isNull);
        continue;
      }
      expect(mapped?.address, address);
      expect(mapped?.retryInterval, _retryInterval);
      expect(
        mapped?.state,
        status.serverReachable
            ? AppServerState.online
            : AppServerState.unreachable,
      );
      final DateTime expectedConnection = status.serverReachable
          ? observedAt
          : previous?.lastConnectedAt ?? observedAt;
      expect(mapped?.lastConnectedAt, expectedConnection);
    }
  });

  test('test_apply_server_health_from_node_property_keeps_address', () {
    final Random random = seededRandom(9504);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerStatus previous = _randomServerStatus(random);
      final node.ServerHealthView health = node.ServerHealthView.fromJson(
        randomServerHealthJson(random),
      );
      final AppServerStatus next = applyServerHealthFromNode(previous, health);
      expect(next.address, previous.address);
      expect(next.retryInterval, previous.retryInterval);
      expect(next.state == AppServerState.online, health.reachable);
      expect(
        next.lastConnectedAt,
        health.reachable ? health.checkedAt : previous.lastConnectedAt,
      );
    }
  });
}
