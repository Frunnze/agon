import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_account_json.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../support/random_inputs.dart';

const int _largestStepCount = 12;
const int _largestGapSeconds = 600;
const Duration _retryInterval = Duration(seconds: 10);

node.StatusView _statusViewAt(
  Random random, {
  required String address,
  required bool isReachable,
}) {
  return node.StatusView.fromJson(<String, Object?>{
    ...randomStatusViewJson(random),
    'server_address': address,
    'server_reachable': isReachable,
  });
}

AppServerStatus _neverConnectedStatus(Random random) {
  return AppServerStatus(
    address: randomHostileText(random),
    state: AppServerState.unreachable,
    lastConnectedAt: null,
    retryInterval: _retryInterval,
  );
}

void main() {
  test(
    'test_map_app_server_status_from_node_property_first_failure_never_met',
    () {
      final Random random = seededRandom(74601);
      for (int i = 0; i < propertyIterations; i += 1) {
        final node.StatusView view = _statusViewAt(
          random,
          address: randomHostileText(random),
          isReachable: false,
        );
        final AppServerStatus? status = mapAppServerStatusFromNode(
          view,
          previous: random.nextBool() ? null : _neverConnectedStatus(random),
          observedAt: randomPreciseMoment(random),
          retryInterval: _retryInterval,
        );

        expect(status?.state, AppServerState.unreachable);
        expect(status?.lastConnectedAt, isNull);
      }
    },
  );

  test(
    'test_map_app_server_status_from_node_property_connection_only_when_seen',
    () {
      final Random random = seededRandom(74602);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String address = randomHostileText(random);
        DateTime moment = randomPreciseMoment(random);
        DateTime? lastSeenConnection;
        AppServerStatus? status;
        final int stepCount = 1 + random.nextInt(_largestStepCount);
        for (int step = 0; step < stepCount; step += 1) {
          moment = moment.add(
            Duration(seconds: random.nextInt(_largestGapSeconds)),
          );
          final bool isReachable = random.nextBool();
          final AppServerStatus? known = status;
          if (known == null || random.nextBool()) {
            status = mapAppServerStatusFromNode(
              _statusViewAt(
                random,
                address: address,
                isReachable: isReachable,
              ),
              previous: known,
              observedAt: moment,
              retryInterval: _retryInterval,
            );
          } else {
            status = applyServerHealthFromNode(
              known,
              node.ServerHealthView(
                reachable: isReachable,
                checkedAt: moment,
                problem: null,
              ),
            );
          }
          if (isReachable) {
            lastSeenConnection = moment;
          }

          expect(status?.lastConnectedAt, lastSeenConnection);
        }
      }
    },
  );

  test(
    'test_apply_server_health_from_node_property_failure_keeps_never_met',
    () {
      final Random random = seededRandom(74603);
      for (int i = 0; i < propertyIterations; i += 1) {
        final AppServerStatus previous = _neverConnectedStatus(random);
        final node.ServerHealthView health = node.ServerHealthView.fromJson(
          randomServerHealthJson(random),
        );
        final AppServerStatus next = applyServerHealthFromNode(
          previous,
          health,
        );

        if (health.reachable) {
          expect(next.lastConnectedAt, health.checkedAt);
        } else {
          expect(next.lastConnectedAt, isNull);
        }
        expect(next.address, previous.address);
      }
    },
  );
}
