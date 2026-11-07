import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/person_answers.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';

const String _blankAnswerProblem = 'Write an answer first';

bool _isRefused(String answer) {
  final Matcher refusal = throwsA(isA<ArgumentError>());
  return refusal.matches(
    () => refuseBlankAnswer(answer),
    <Object?, Object?>{},
  );
}

String _randomAnswer(Random random, RuleTitleWhiteSpaceTable table) {
  return pickOne(random, <String>[
    table.randomWhiteSpaceRun(random),
    table.randomExoticTitle(random),
    randomText(random),
    randomWordPhrase(random),
  ]);
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('test_refuse_blank_answer_property_refuses_exactly_rust_white_'
      'space', () {
    final Random random = seededRandom(79001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String answer = _randomAnswer(random, table);

      expect(
        _isRefused(answer),
        table.trimByModel(answer).isEmpty,
        reason: answer.runes.toList().toString(),
      );
    }
  });

  test('test_refuse_blank_answer_property_refusal_names_the_answer', () {
    final Random random = seededRandom(79002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String answer = table.randomWhiteSpaceRun(random);

      expect(
        () => refuseBlankAnswer(answer),
        throwsA(
          isA<ArgumentError>()
              .having((ArgumentError error) => error.name, 'name', 'answer')
              .having(
                (ArgumentError error) => error.invalidValue,
                'invalidValue',
                answer,
              )
              .having(
                (ArgumentError error) => error.message,
                'message',
                _blankAnswerProblem,
              ),
        ),
      );
    }
  });

  test('test_refuse_blank_answer_property_padding_never_changes_the_'
      'verdict', () {
    final Random random = seededRandom(79003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String answer = _randomAnswer(random, table);
      final String padded =
          '${table.randomWhiteSpaceRun(random)}$answer'
          '${table.randomWhiteSpaceRun(random)}';

      expect(_isRefused(padded), _isRefused(answer));
    }
  });
}
