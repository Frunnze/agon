import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/person_answers.dart';

import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';
import '../../support/rule_title_white_space_table.dart';
import 'support/person_step_inputs.dart';
import 'support/refusals.dart';

const String _typePrefix = 'test_fake_person_step_repository';

bool _isAnswerRefusal(Object error) {
  return error is ArgumentError ||
      error is StateError ||
      error is RecordNotFound;
}

String _randomAnswer(
  Random random,
  RuleTitleWhiteSpaceTable table,
  List<String> choices,
) {
  final List<String> bases = <String>[
    ...choices,
    ...rustApprovalWords,
    table.randomExoticTitle(random),
    randomText(random),
  ];
  final String base = scrambleLetterCase(random, pickOne(random, bases));
  if (random.nextBool()) {
    return padWithRustWhiteSpace(random, table, base);
  }
  return '﻿$base';
}

OpenPersonStep _withoutChoices(OpenPersonStep openStep) {
  return OpenPersonStep(
    runId: openStep.runId,
    taskId: openStep.taskId,
    workspaceId: openStep.workspaceId,
    stepName: openStep.stepName,
    question: openStep.question,
    choices: const <String>[],
    askedAt: openStep.askedAt,
  );
}

Future<bool> _answer(
  CountedPersonSteps counted,
  OpenPersonStep asked,
  String answer,
) {
  return isRefused(
    () => counted.repository.answerPersonStep(
      runId: asked.runId,
      stepName: asked.stepName,
      answer: answer,
    ),
    isRefusal: _isAnswerRefusal,
  );
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('${_typePrefix}_answer_person_step_property_blank_means_rust_'
      'white_space_only', () async {
    final Random random = seededRandom(65401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final OpenPersonStep asked = _withoutChoices(randomOpenStep(random, 0));
      final CountedPersonSteps counted = buildCountedPersonSteps(
        <OpenPersonStep>[asked],
      );
      final String answer = table.randomExoticTitle(random);
      final bool isBlank = table.trimByModel(answer).isEmpty;

      final bool wasRefused = await _answer(counted, asked, answer);

      expect(wasRefused, isBlank, reason: answer.runes.toString());
      expect(counted.repository.listOpenPersonSteps().isEmpty, !isBlank);
    }
  });

  test('${_typePrefix}_answer_person_step_property_choices_match_like_'
      'rust', () async {
    final Random random = seededRandom(65402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      if (seeded.isEmpty) {
        continue;
      }
      final CountedPersonSteps counted = buildCountedPersonSteps(seeded);
      final OpenPersonStep asked = pickOne(random, seeded);
      final String answer = _randomAnswer(random, table, asked.choices);
      final bool isAccepted = isAcceptedLikeRust(
        table: table,
        answer: answer,
        choices: asked.choices,
      );

      final bool wasRefused = await _answer(counted, asked, answer);

      expect(wasRefused, !isAccepted, reason: answer.runes.toString());
      expect(
        counted.repository.listOpenPersonSteps().contains(asked),
        !isAccepted,
      );
      expect(counted.notifications.count, isAccepted ? 1 : 0);
    }
  });

  test('${_typePrefix}_answer_person_step_property_unmatched_answers_name_'
      'the_choices', () async {
    final Random random = seededRandom(65403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final OpenPersonStep asked = randomOpenStep(random, 0);
      if (asked.choices.isEmpty) {
        continue;
      }
      final CountedPersonSteps counted = buildCountedPersonSteps(
        <OpenPersonStep>[asked],
      );
      final String answer = 'none of them ${randomText(random)}';

      await expectLater(
        counted.repository.answerPersonStep(
          runId: asked.runId,
          stepName: asked.stepName,
          answer: answer,
        ),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            describeUnmatchedAnswer(asked.choices),
          ),
        ),
      );
      expect(counted.repository.listOpenPersonSteps(), <OpenPersonStep>[
        asked,
      ]);
    }
  });

  test('${_typePrefix}_answer_person_step_property_unknown_steps_are_not_'
      'found', () async {
    final Random random = seededRandom(65404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final CountedPersonSteps counted = buildCountedPersonSteps(seeded);
      final String stepName = seeded.isNotEmpty && random.nextBool()
          ? pickOne(random, seeded).stepName
          : 'missing-${randomText(random)}';
      final RunId runId = RunId('run-elsewhere-${randomText(random)}');

      await expectLater(
        counted.repository.answerPersonStep(
          runId: runId,
          stepName: stepName,
          answer: 'approved',
        ),
        throwsA(isA<RecordNotFound>()),
      );
      expect(counted.repository.listOpenPersonSteps(), seeded);
      expect(counted.notifications.count, 0);
    }
  });
}
