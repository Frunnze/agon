import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';

import '../support/random_inputs.dart';
import '../support/recording_runner_presence.dart';

const int _largestRoleChangeCount = 6;

void main() {
  test(
    'test_keep_for_role_property_only_task_running_roles_stay_behind',
    () async {
      final Random random = seededRandom(12101);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRole role = pickOne(random, DeviceRole.values);
        final RecordedRunnerPresence recorded = RecordedRunnerPresence();

        await recorded.presence.keepForRole(role);

        expect(recorded.loginItem.isRegistered, roleRunsTasks(role));
        expect(recorded.trayPresence.isInTray, roleRunsTasks(role));
        expect(recorded.isUntouched, !roleRunsTasks(role));
      }
    },
  );

  test(
    'test_keep_for_role_property_registered_until_the_device_is_forgotten',
    () async {
      final Random random = seededRandom(12102);
      for (int i = 0; i < propertyIterations; i += 1) {
        final RecordedRunnerPresence recorded = RecordedRunnerPresence();
        final RunnerPresence presence = recorded.presence;
        bool isExpectedInBackground = false;
        final int changeCount = random.nextInt(_largestRoleChangeCount);

        for (int change = 0; change < changeCount; change += 1) {
          final bool forgetsTheDevice = random.nextInt(3) == 0;
          if (forgetsTheDevice) {
            await presence.remove();
            isExpectedInBackground = false;
          } else {
            final DeviceRole role = pickOne(random, DeviceRole.values);
            await presence.keepForRole(role);
            isExpectedInBackground =
                isExpectedInBackground || roleRunsTasks(role);
          }

          expect(recorded.loginItem.isRegistered, isExpectedInBackground);
          expect(recorded.trayPresence.isInTray, isExpectedInBackground);
        }
      }
    },
  );

  test('test_remove_property_leaves_nothing_behind_for_any_role', () async {
    final Random random = seededRandom(12103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordedRunnerPresence recorded = RecordedRunnerPresence();
      final RunnerPresence presence = recorded.presence;
      final DeviceRole role = pickOne(random, DeviceRole.values);
      final int removalCount = 1 + random.nextInt(3);

      await presence.keepForRole(role);
      for (int removal = 0; removal < removalCount; removal += 1) {
        await presence.remove();
      }

      expect(recorded.loginItem.isRegistered, isFalse);
      expect(recorded.trayPresence.isInTray, isFalse);
      expect(recorded.loginItem.calls.last, unregisterCall);
      expect(recorded.trayPresence.calls.last, leaveTrayCall);
    }
  });

  test(
    'test_keep_for_role_property_tray_stays_when_the_login_item_fails',
    () async {
      for (final DeviceRole role in DeviceRole.values) {
        final RecordingTrayPresence tray = RecordingTrayPresence();
        final RunnerPresence presence = RunnerPresence(
          loginItem: RefusingLoginItem(),
          trayPresence: tray,
        );

        if (!roleRunsTasks(role)) {
          await presence.keepForRole(role);
          expect(tray.calls, isEmpty);
          continue;
        }
        await expectLater(
          presence.keepForRole(role),
          throwsA(
            isA<StateError>().having(
              (StateError problem) => problem.message,
              'message',
              refusedLoginItemMessage,
            ),
          ),
        );
        expect(tray.isInTray, isTrue);
      }
    },
  );

  test(
    'test_keep_for_role_property_failing_tray_stops_before_login_item',
    () async {
      for (final DeviceRole role in DeviceRole.values) {
        final RecordingLoginItem loginItem = RecordingLoginItem();
        final RunnerPresence presence = RunnerPresence(
          loginItem: loginItem,
          trayPresence: RefusingTrayPresence(),
        );

        if (roleRunsTasks(role)) {
          await expectLater(presence.keepForRole(role), throwsStateError);
        } else {
          await presence.keepForRole(role);
        }
        expect(loginItem.calls, isEmpty);
      }
    },
  );

  test(
    'test_remove_property_tray_is_left_before_a_failing_login_item',
    () async {
      final RecordingTrayPresence tray = RecordingTrayPresence();
      final RunnerPresence presence = RunnerPresence(
        loginItem: RefusingLoginItem(),
        trayPresence: tray,
      );

      await expectLater(presence.remove(), throwsStateError);
      expect(tray.calls, <String>[leaveTrayCall]);
    },
  );
}
