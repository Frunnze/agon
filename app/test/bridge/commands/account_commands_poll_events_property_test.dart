import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/commands/account_commands.dart';

import '../../support/random_inputs.dart';
import '../support/random_wire_counts.dart';
import '../support/random_wire_values.dart';

const int _smallestWholeNumber = -0x7FFFFFFFFFFFFFFF - 1;
const int _extremeOdds = 8;
const int _nearZeroSpan = 4;

int _randomNegativeAfter(Random random) {
  if (random.nextInt(_extremeOdds) == 0) {
    return _smallestWholeNumber;
  }
  return randomNegativeWholeNumber(random);
}

void main() {
  test('test_poll_events_command_constructor_property_'
      'rejects_a_negative_after', () {
    final Random random = seededRandom(77401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int after = _randomNegativeAfter(random);

      expect(() => PollEventsCommand(after: after), throwsArgumentError);
    }
  });

  test('test_poll_events_command_constructor_property_'
      'keeps_every_non_negative_after', () {
    final Random random = seededRandom(77402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int after = randomWholeNumber(random);

      final PollEventsCommand command = PollEventsCommand(after: after);

      expect(command.after, after);
      expect(command.arguments['after'], after);
    }
  });

  test('test_poll_events_command_constructor_property_'
      'accepts_exactly_the_sequences_from_zero', () {
    final Random random = seededRandom(77403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int after = random.nextInt(2 * _nearZeroSpan) - _nearZeroSpan;

      if (after >= 0) {
        expect(PollEventsCommand(after: after).after, after);
      } else {
        expect(() => PollEventsCommand(after: after), throwsArgumentError);
      }
    }
  });
}
