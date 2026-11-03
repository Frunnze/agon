import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/person_answers.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

List<String> _randomChoices(Random random) {
  final List<String> choices = List<String>.of(sampleOutcomes);
  choices.shuffle(random);
  return choices.sublist(0, random.nextInt(choices.length + 1));
}

String _changeCase(Random random, String text) {
  final StringBuffer buffer = StringBuffer();
  for (final String letter in text.split('')) {
    buffer.write(random.nextBool() ? letter.toUpperCase() : letter);
  }
  return buffer.toString();
}

void main() {
  test('test_match_choice_property_ignores_case_and_outer_spaces', () {
    final Random random = seededRandom(9901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> choices = _randomChoices(random);
      if (choices.isEmpty) {
        continue;
      }
      final String choice = pickOne(random, choices);
      final String answer = '  ${_changeCase(random, choice)} ';

      expect(matchChoice(answer, choices), choice);
    }
  });

  test('test_match_choice_property_only_ever_returns_a_choice', () {
    final Random random = seededRandom(9902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> choices = _randomChoices(random);
      final String answer = random.nextBool()
          ? randomText(random)
          : pickOne(random, <String>['approve', 'Approved', 'nope']);

      final String? match = matchChoice(answer, choices);

      if (match != null) {
        expect(choices, contains(match));
      }
    }
  });

  test('approve and approved pick whichever of the two is a choice', () {
    expect(
      matchChoice('approve', <String>['changes', 'approved']),
      'approved',
    );
    expect(matchChoice('Approved', <String>['approve', 'changes']), 'approve');
    expect(matchChoice('approve it', <String>['approved']), isNull);
    expect(matchChoice('ship', <String>['changes']), isNull);
  });

  test('test_describe_unmatched_answer_property_lists_every_choice', () {
    final Random random = seededRandom(9903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> choices = _randomChoices(random);

      final String problem = describeUnmatchedAnswer(choices);

      expect(problem, startsWith('the answer names none of the choices: '));
      expect(problem, endsWith(choices.join(', ')));
    }
  });
}
