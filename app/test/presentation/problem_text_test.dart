import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/confirmation.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';

import '../support/random_inputs.dart';

void main() {
  test('test_describe_problem_for_people_property_explained_text_wins', () {
    final Random random = seededRandom(9971);
    for (int i = 0; i < propertyIterations; i += 1) {
      final BiometricConfirmationUnavailable problem =
          BiometricConfirmationUnavailable(explanation: randomText(random));
      expect(describeProblemForPeople(problem), problem.explanation);
    }
  });

  test('test_describe_problem_for_people_property_refusals_keep_text', () {
    final Random random = seededRandom(9972);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String message = randomText(random);
      expect(describeProblemForPeople(StateError(message)), message);
      expect(
        describeProblemForPeople(ArgumentError.value(0, 'text', message)),
        contains(message),
      );
    }
  });

  test('test_describe_problem_for_people_property_missing_record_named', () {
    final Random random = seededRandom(9973);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordNotFound problem = RecordNotFound(
        kind: randomWordPhrase(random),
        identifier: randomText(random),
      );
      expect(describeProblemForPeople(problem), problem.toString());
    }
  });

  test('test_describe_problem_for_people_property_bugs_are_not_shown', () {
    final Random random = seededRandom(9974);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object> bugs = <Object>[
        RangeError(randomText(random)),
        TypeError(),
        FormatException(randomText(random)),
        randomText(random),
      ];
      expect(describeProblemForPeople(pickOne(random, bugs)), isNull);
    }
  });
}
