import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/device_without_account.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

void main() {
  test(
    'test_device_without_account_constructor_property_keeps_the_message',
    () {
      final Random random = seededRandom(47641);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = randomHostileText(random);

        final DeviceWithoutAccount problem = DeviceWithoutAccount(message);

        expect(problem, isA<StateError>());
        expect(problem.message, message);
      }
    },
  );

  test(
    'test_device_without_account_to_string_property_reads_like_a_state_error',
    () {
      final Random random = seededRandom(47642);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = randomHostileText(random);

        expect(
          DeviceWithoutAccount(message).toString(),
          StateError(message).toString(),
        );
      }
    },
  );

  test(
    'test_device_without_account_constructor_property_people_see_the_message',
    () {
      final Random random = seededRandom(47643);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = randomHostileText(random);

        expect(
          describeProblemForPeople(DeviceWithoutAccount(message)),
          message,
        );
      }
    },
  );
}
