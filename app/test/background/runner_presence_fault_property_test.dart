import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';

import '../support/random_inputs.dart';
import 'support/logged_computer.dart';

List<String> _expectEventsOf({
  required PresenceChange change,
  required DeviceRole role,
  required bool isStartAtLoginChosen,
}) {
  switch (change) {
    case PresenceChange.keepForRole:
      if (!roleRunsTasks(role)) {
        return <String>[];
      }
      return <String>[
        stayInTrayEvent,
        readChoiceEvent,
        if (isStartAtLoginChosen) registerEvent,
      ];
    case PresenceChange.startAtLogin:
      return <String>[registerEvent, saveOnEvent];
    case PresenceChange.stopStartingAtLogin:
      return <String>[unregisterEvent, saveOffEvent];
    case PresenceChange.remove:
      return <String>[leaveTrayEvent, unregisterEvent];
  }
}

Future<void> _expectFailingStepStopsLaterSteps(
  PresenceChange change, {
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final LoggedComputer computer = LoggedComputer(
      isStartAtLoginChosen: random.nextBool(),
    );
    await applyRandomHistory(random, computer);
    final DeviceRole role = pickOne(random, DeviceRole.values);
    final String failingEvent = pickOne(random, presenceEvents);
    final List<String> expectedEvents = _expectEventsOf(
      change: change,
      role: role,
      isStartAtLoginChosen: computer.isStartAtLoginChosen,
    );
    computer.failingEvent = failingEvent;

    final Future<void> applied = applyPresenceChange(
      change: change,
      role: role,
      presence: computer.presence,
    );

    final int failingPlace = expectedEvents.indexOf(failingEvent);
    if (failingPlace < 0) {
      await applied;
      expect(computer.events, expectedEvents);
      continue;
    }
    await expectLater(
      applied,
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          failingEvent,
        ),
      ),
    );
    expect(computer.events, expectedEvents.sublist(0, failingPlace + 1));
  }
}

void main() {
  test(
    'test_keep_for_role_property_a_failing_step_stops_every_later_step',
    () => _expectFailingStepStopsLaterSteps(
      PresenceChange.keepForRole,
      seed: 48311,
    ),
  );

  test(
    'test_start_at_login_property_a_failing_step_stops_every_later_step',
    () => _expectFailingStepStopsLaterSteps(
      PresenceChange.startAtLogin,
      seed: 48312,
    ),
  );

  test(
    'test_stop_starting_at_login_property_a_failing_step_stops_later_steps',
    () => _expectFailingStepStopsLaterSteps(
      PresenceChange.stopStartingAtLogin,
      seed: 48313,
    ),
  );

  test(
    'test_remove_property_a_failing_step_stops_every_later_step',
    () =>
        _expectFailingStepStopsLaterSteps(PresenceChange.remove, seed: 48314),
  );
}
