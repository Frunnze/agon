import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart' as node;
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_account_json.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../support/random_inputs.dart';

const int _largestRetrySeconds = 3600;

Duration _randomRetryInterval(Random random) {
  return Duration(seconds: 1 + random.nextInt(_largestRetrySeconds));
}

AppServerStatus _randomStatus(Random random) {
  return AppServerStatus(
    address: randomHostileText(random),
    state: pickOne(random, AppServerState.values),
    lastConnectedAt: randomPreciseMoment(random),
    retryInterval: _randomRetryInterval(random),
  );
}

node.StatusView _randomStatusView(
  Random random, {
  required String? serverAddress,
  required bool isReachable,
}) {
  final Map<String, Object?> json = <String, Object?>{
    ...randomStatusViewJson(random),
    'server_address': serverAddress,
    'server_reachable': isReachable,
  };
  return node.StatusView.fromJson(json);
}

node.ServerHealthView _randomHealth(Random random, {required bool reachable}) {
  return node.ServerHealthView(
    reachable: reachable,
    checkedAt: randomPreciseMoment(random),
    problem: random.nextBool() ? null : randomHostileText(random),
  );
}

List<Object?> _describeStatus(AppServerStatus? status) {
  if (status == null) {
    return const <Object?>[];
  }
  return <Object?>[
    status.address,
    status.state,
    status.lastConnectedAt,
    status.retryInterval,
  ];
}

AppServerState _expectedState({required bool isReachable}) {
  if (isReachable) {
    return AppServerState.online;
  }
  return AppServerState.unreachable;
}

void main() {
  test('test_describe_reachability_property_status_state_follows_flag', () {
    final Random random = seededRandom(73901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isReachable = random.nextBool();
      final node.StatusView view = _randomStatusView(
        random,
        serverAddress: randomHostileText(random),
        isReachable: isReachable,
      );

      final AppServerStatus? status = mapAppServerStatusFromNode(
        view,
        previous: random.nextBool() ? null : _randomStatus(random),
        observedAt: randomPreciseMoment(random),
        retryInterval: _randomRetryInterval(random),
      );

      expect(status?.state, _expectedState(isReachable: isReachable));
    }
  });

  test('test_describe_reachability_property_health_state_follows_flag', () {
    final Random random = seededRandom(73902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isReachable = random.nextBool();
      final AppServerStatus previous = _randomStatus(random);

      final AppServerStatus next = applyServerHealthFromNode(
        previous,
        _randomHealth(random, reachable: isReachable),
      );

      expect(next.state, _expectedState(isReachable: isReachable));
    }
  });

  test(
    'test_describe_reachability_property_both_entries_reach_all_states',
    () {
      final Random random = seededRandom(73903);
      final Set<AppServerState> statusStates = <AppServerState>{};
      final Set<AppServerState> healthStates = <AppServerState>{};

      for (final bool isReachable in <bool>[true, false]) {
        final AppServerStatus? status = mapAppServerStatusFromNode(
          _randomStatusView(
            random,
            serverAddress: randomHostileText(random),
            isReachable: isReachable,
          ),
          previous: null,
          observedAt: randomPreciseMoment(random),
          retryInterval: _randomRetryInterval(random),
        );
        final AppServerStatus next = applyServerHealthFromNode(
          _randomStatus(random),
          _randomHealth(random, reachable: isReachable),
        );
        statusStates.add(status!.state);
        healthStates.add(next.state);
      }

      expect(statusStates, AppServerState.values.toSet());
      expect(healthStates, statusStates);
    },
  );

  test(
    'test_map_app_server_status_from_node_property_no_address_no_status',
    () {
      final Random random = seededRandom(73904);

      for (int i = 0; i < propertyIterations; i += 1) {
        final node.StatusView view = _randomStatusView(
          random,
          serverAddress: null,
          isReachable: random.nextBool(),
        );

        final AppServerStatus? status = mapAppServerStatusFromNode(
          view,
          previous: random.nextBool() ? null : _randomStatus(random),
          observedAt: randomPreciseMoment(random),
          retryInterval: _randomRetryInterval(random),
        );

        expect(status, isNull);
      }
    },
  );

  test(
    'test_map_app_server_status_from_node_property_remapping_is_stable',
    () {
      final Random random = seededRandom(73905);

      for (int i = 0; i < propertyIterations; i += 1) {
        final node.StatusView view = _randomStatusView(
          random,
          serverAddress: randomHostileText(random),
          isReachable: random.nextBool(),
        );
        final DateTime observedAt = randomPreciseMoment(random);
        final Duration retryInterval = _randomRetryInterval(random);

        final AppServerStatus? first = mapAppServerStatusFromNode(
          view,
          previous: random.nextBool() ? null : _randomStatus(random),
          observedAt: observedAt,
          retryInterval: retryInterval,
        );
        final AppServerStatus? second = mapAppServerStatusFromNode(
          view,
          previous: first,
          observedAt: observedAt,
          retryInterval: retryInterval,
        );

        expect(_describeStatus(second), _describeStatus(first));
      }
    },
  );

  test('test_apply_server_health_from_node_property_is_idempotent', () {
    final Random random = seededRandom(73906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerStatus previous = _randomStatus(random);
      final node.ServerHealthView health = _randomHealth(
        random,
        reachable: random.nextBool(),
      );

      final AppServerStatus once = applyServerHealthFromNode(previous, health);
      final AppServerStatus twice = applyServerHealthFromNode(once, health);

      expect(_describeStatus(twice), _describeStatus(once));
    }
  });

  test(
    'test_apply_server_health_from_node_property_failure_keeps_history',
    () {
      final Random random = seededRandom(73907);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AppServerStatus previous = _randomStatus(random);

        final AppServerStatus next = applyServerHealthFromNode(
          previous,
          _randomHealth(random, reachable: false),
        );

        expect(_describeStatus(next), <Object?>[
          previous.address,
          AppServerState.unreachable,
          previous.lastConnectedAt,
          previous.retryInterval,
        ]);
      }
    },
  );
}
