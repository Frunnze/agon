import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';

import '../support/random_inputs.dart';
import 'support/logged_computer.dart';

PresenceState _expectPresenceAfter({
  required PresenceState before,
  required PresenceChange change,
  required DeviceRole role,
}) {
  switch (change) {
    case PresenceChange.keepForRole:
      final bool isRunner = roleRunsTasks(role);
      return (
        isRegistered:
            before.isRegistered || (isRunner && before.isStartAtLoginChosen),
        isInTray: before.isInTray || isRunner,
        isStartAtLoginChosen: before.isStartAtLoginChosen,
      );
    case PresenceChange.startAtLogin:
      return (
        isRegistered: true,
        isInTray: before.isInTray,
        isStartAtLoginChosen: true,
      );
    case PresenceChange.stopStartingAtLogin:
      return (
        isRegistered: false,
        isInTray: before.isInTray,
        isStartAtLoginChosen: false,
      );
    case PresenceChange.remove:
      return (
        isRegistered: false,
        isInTray: false,
        isStartAtLoginChosen: before.isStartAtLoginChosen,
      );
  }
}

void main() {
  test('test_remove_property_change_sequences_match_the_model', () async {
    final Random random = seededRandom(48301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LoggedComputer computer = LoggedComputer(
        isStartAtLoginChosen: random.nextBool(),
      );
      final RunnerPresence presence = computer.presence;
      PresenceState expected = computer.state;
      final int changeCount = 1 + random.nextInt(largestHistoryLength);

      for (int step = 0; step < changeCount; step += 1) {
        final PresenceChange change = pickOne(random, PresenceChange.values);
        final DeviceRole role = pickOne(random, DeviceRole.values);

        await applyPresenceChange(
          change: change,
          role: role,
          presence: presence,
        );
        expected = _expectPresenceAfter(
          before: expected,
          change: change,
          role: role,
        );

        expect(computer.state, expected, reason: '$change as $role');
      }
    }
  });

  test(
    'test_start_at_login_property_registers_before_saving_the_choice',
    () async {
      final Random random = seededRandom(48302);

      for (int i = 0; i < propertyIterations; i += 1) {
        final LoggedComputer computer = LoggedComputer(
          isStartAtLoginChosen: random.nextBool(),
        );
        await applyRandomHistory(random, computer);

        await computer.presence.startAtLogin();

        expect(computer.events, <String>[registerEvent, saveOnEvent]);
      }
    },
  );

  test(
    'test_stop_starting_at_login_property_unregisters_before_saving',
    () async {
      final Random random = seededRandom(48303);

      for (int i = 0; i < propertyIterations; i += 1) {
        final LoggedComputer computer = LoggedComputer(
          isStartAtLoginChosen: random.nextBool(),
        );
        await applyRandomHistory(random, computer);

        await computer.presence.stopStartingAtLogin();

        expect(computer.events, <String>[unregisterEvent, saveOffEvent]);
      }
    },
  );

  test(
    'test_stop_starting_at_login_property_later_starts_stay_off_until_on',
    () async {
      final Random random = seededRandom(48304);

      for (int i = 0; i < propertyIterations; i += 1) {
        final LoggedComputer computer = LoggedComputer(
          isStartAtLoginChosen: random.nextBool(),
        );
        await applyRandomHistory(random, computer);
        await computer.presence.stopStartingAtLogin();
        final int startCount = random.nextInt(largestHistoryLength);

        for (int start = 0; start < startCount; start += 1) {
          final DeviceRole role = pickOne(random, DeviceRole.values);
          await computer.presence.keepForRole(role);
          expect(computer.isRegistered, isFalse);
        }
        await computer.presence.startAtLogin();

        expect(computer.isRegistered, isTrue);
        expect(computer.isStartAtLoginChosen, isTrue);
      }
    },
  );
}
