import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';

import '../support/memory_start_at_login_choice_store.dart';
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
        final RecordedRunnerPresence recorded = RecordedRunnerPresence(
          isStartAtLoginChosen: true,
        );

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
        final RecordedRunnerPresence recorded = RecordedRunnerPresence(
          isStartAtLoginChosen: true,
        );
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
      final RecordedRunnerPresence recorded = RecordedRunnerPresence(
        isStartAtLoginChosen: true,
      );
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
          startAtLoginChoiceStore: MemoryStartAtLoginChoiceStore(
            isStartAtLoginChosen: true,
          ),
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
          startAtLoginChoiceStore: MemoryStartAtLoginChoiceStore(
            isStartAtLoginChosen: true,
          ),
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
        startAtLoginChoiceStore: MemoryStartAtLoginChoiceStore(
          isStartAtLoginChosen: true,
        ),
      );

      await expectLater(presence.remove(), throwsStateError);
      expect(tray.calls, <String>[leaveTrayCall]);
    },
  );

  test(
    'test_keep_for_role_property_login_item_follows_the_saved_choice',
    () async {
      final Random random = seededRandom(12104);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRole role = pickOne(random, DeviceRole.values);
        final bool isStartAtLoginChosen = random.nextBool();
        final RecordedRunnerPresence recorded = RecordedRunnerPresence(
          isStartAtLoginChosen: isStartAtLoginChosen,
        );

        await recorded.presence.keepForRole(role);

        final bool isExpectedAtLogin =
            roleRunsTasks(role) && isStartAtLoginChosen;
        expect(recorded.loginItem.isRegistered, isExpectedAtLogin);
        expect(recorded.trayPresence.isInTray, roleRunsTasks(role));
        expect(
          recorded.choiceStore.isStartAtLoginChosen,
          isStartAtLoginChosen,
        );
      }
    },
  );

  test(
    'test_start_at_login_property_the_last_switch_wins_and_is_kept',
    () async {
      final Random random = seededRandom(12105);
      for (int i = 0; i < propertyIterations; i += 1) {
        final RecordedRunnerPresence recorded = RecordedRunnerPresence(
          isStartAtLoginChosen: random.nextBool(),
        );
        final RunnerPresence presence = recorded.presence;
        final int switchCount = 1 + random.nextInt(_largestRoleChangeCount);
        bool isLastSwitchOn = false;

        for (int change = 0; change < switchCount; change += 1) {
          isLastSwitchOn = random.nextBool();
          if (isLastSwitchOn) {
            await presence.startAtLogin();
          } else {
            await presence.stopStartingAtLogin();
          }
        }

        expect(recorded.loginItem.isRegistered, isLastSwitchOn);
        expect(recorded.choiceStore.isStartAtLoginChosen, isLastSwitchOn);
        expect(recorded.trayPresence.calls, isEmpty);
      }
    },
  );

  test('test_stop_starting_at_login_property_next_start_stays_off', () async {
    for (final DeviceRole role in DeviceRole.values) {
      final RecordedRunnerPresence recorded = RecordedRunnerPresence(
        isStartAtLoginChosen: true,
      );
      final RunnerPresence presence = recorded.presence;

      await presence.keepForRole(role);
      await presence.stopStartingAtLogin();
      await presence.keepForRole(role);

      expect(recorded.loginItem.isRegistered, isFalse);
      expect(recorded.trayPresence.isInTray, roleRunsTasks(role));
    }
  });

  test(
    'test_start_at_login_property_a_refused_login_item_keeps_the_choice',
    () async {
      for (final bool isStartAtLoginChosen in <bool>[true, false]) {
        final MemoryStartAtLoginChoiceStore store =
            MemoryStartAtLoginChoiceStore(
              isStartAtLoginChosen: isStartAtLoginChosen,
            );
        final RunnerPresence presence = RunnerPresence(
          loginItem: RefusingLoginItem(),
          trayPresence: RecordingTrayPresence(),
          startAtLoginChoiceStore: store,
        );

        await expectLater(presence.startAtLogin(), throwsStateError);
        expect(store.isStartAtLoginChosen, isStartAtLoginChosen);
        await expectLater(presence.stopStartingAtLogin(), throwsStateError);
        expect(store.isStartAtLoginChosen, isStartAtLoginChosen);
      }
    },
  );
}
