import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/skill_names.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/skill_inputs.dart';

void main() {
  test('test_require_valid_skill_name_property_accepts_well_formed', () {
    final Random random = seededRandom(66701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomValidSkillName(random);

      expect(() => requireValidSkillName(name), returnsNormally, reason: name);
    }
  });

  test('test_require_valid_skill_name_property_refuses_badly_formed', () {
    final Random random = seededRandom(66702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomInvalidSkillName(random);

      expect(
        () => requireValidSkillName(name),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.invalidValue,
            'invalidValue',
            name,
          ),
        ),
      );
    }
  });

  test('test_require_valid_skill_name_property_agrees_with_the_name_rule', () {
    final Random random = seededRandom(66703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = random.nextBool()
          ? randomText(random)
          : randomValidSkillName(random);

      final Matcher expected = describeNameProblem(name) == null
          ? returnsNormally
          : throwsArgumentError;
      expect(() => requireValidSkillName(name), expected, reason: name);
    }
  });
}
