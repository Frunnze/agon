import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/data/models/device.dart';

import '../support/random_inputs.dart';
import '../support/recording_runner_presence.dart';

const int _mostCallsAtOnce = 6;
const List<DeviceRole> _taskRunningRoles = <DeviceRole>[
  DeviceRole.runner,
  DeviceRole.clientAndRunner,
];

enum _PresenceCall { keepForRole, startAtLogin, stopStartingAtLogin }

Future<void> _makeCall(
  RunnerPresence presence,
  _PresenceCall call,
  DeviceRole role,
) {
  switch (call) {
    case _PresenceCall.keepForRole:
      return presence.keepForRole(role);
    case _PresenceCall.startAtLogin:
      return presence.startAtLogin();
    case _PresenceCall.stopStartingAtLogin:
      return presence.stopStartingAtLogin();
  }
}

String _describeLoginCall(_PresenceCall call) {
  if (call == _PresenceCall.startAtLogin) {
    return registerCall;
  }
  return unregisterCall;
}

List<_PresenceCall> _randomCalls(Random random) {
  final int callCount = 2 + random.nextInt(_mostCallsAtOnce - 1);
  final List<_PresenceCall> calls = <_PresenceCall>[];
  for (int i = 0; i < callCount; i += 1) {
    calls.add(pickOne(random, _PresenceCall.values));
  }
  return calls;
}

void main() {
  test(
    'test_keep_for_role_property_overlapping_calls_keep_login_like_choice',
    () async {
      final Random random = seededRandom(9961);
      for (int i = 0; i < propertyIterations; i += 1) {
        final bool isChosen = random.nextBool();
        final RecordedRunnerPresence recorded = RecordedRunnerPresence(
          isStartAtLoginChosen: isChosen,
        );
        recorded.loginItem.isRegistered = isChosen;
        final RunnerPresence presence = recorded.presence;
        final DeviceRole role = pickOne(random, _taskRunningRoles);

        await Future.wait(<Future<void>>[
          for (final _PresenceCall call in _randomCalls(random))
            _makeCall(presence, call, role),
        ]);

        expect(
          recorded.loginItem.isRegistered,
          recorded.choiceStore.isStartAtLoginChosen,
        );
      }
    },
  );

  test('test_stop_starting_at_login_property_last_call_decides', () async {
    final Random random = seededRandom(9962);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordedRunnerPresence recorded = RecordedRunnerPresence(
        isStartAtLoginChosen: random.nextBool(),
      );
      final RunnerPresence presence = recorded.presence;
      final DeviceRole role = pickOne(random, _taskRunningRoles);
      final List<_PresenceCall> calls = <_PresenceCall>[
        ..._randomCalls(random),
        pickOne(random, <_PresenceCall>[
          _PresenceCall.startAtLogin,
          _PresenceCall.stopStartingAtLogin,
        ]),
      ];

      await Future.wait(<Future<void>>[
        for (final _PresenceCall call in calls)
          _makeCall(presence, call, role),
      ]);

      final bool isLastStart = calls.last == _PresenceCall.startAtLogin;
      expect(recorded.choiceStore.isStartAtLoginChosen, isLastStart);
      expect(recorded.loginItem.isRegistered, isLastStart);
    }
  });

  test('test_start_at_login_property_calls_run_in_the_order_made', () async {
    final Random random = seededRandom(9963);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordedRunnerPresence recorded = RecordedRunnerPresence(
        isStartAtLoginChosen: false,
      );
      final RunnerPresence presence = recorded.presence;
      final List<_PresenceCall> calls = <_PresenceCall>[
        for (int call = 0; call < 2 + random.nextInt(4); call += 1)
          pickOne(random, <_PresenceCall>[
            _PresenceCall.startAtLogin,
            _PresenceCall.stopStartingAtLogin,
          ]),
      ];

      await Future.wait(<Future<void>>[
        for (final _PresenceCall call in calls)
          _makeCall(presence, call, DeviceRole.runner),
      ]);

      final List<String> expectedLoginCalls = <String>[
        for (final _PresenceCall call in calls) _describeLoginCall(call),
      ];
      expect(recorded.loginItem.calls, expectedLoginCalls);
    }
  });
}
