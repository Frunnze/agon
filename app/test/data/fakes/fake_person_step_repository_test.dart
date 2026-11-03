import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/rules/person_answers.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

OpenPersonStep _randomOpenStep(Random random, int index) {
  final List<String> choices = List<String>.of(sampleOutcomes)
    ..shuffle(random);
  return OpenPersonStep(
    runId: RunId('run-$index'),
    taskId: const TaskId('task'),
    workspaceId: const WorkspaceId('workspace'),
    stepName: 'step-$index',
    question: randomWordPhrase(random),
    choices: choices.sublist(0, random.nextInt(3)),
    askedAt: null,
  );
}

void main() {
  test(
    'test_answer_person_step_property_only_matching_answers_close',
    () async {
      final Random random = seededRandom(9951);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<OpenPersonStep> openSteps = <OpenPersonStep>[
          for (int index = 0; index < 1 + random.nextInt(3); index += 1)
            _randomOpenStep(random, index),
        ];
        final FakePersonStepRepository repository = FakePersonStepRepository(
          openSteps: openSteps,
        );
        final OpenPersonStep asked = pickOne(random, openSteps);
        final String answer = random.nextBool() && asked.choices.isNotEmpty
            ? pickOne(random, asked.choices).toUpperCase()
            : 'something else';
        final bool isAccepted =
            asked.choices.isEmpty ||
            matchChoice(answer, asked.choices) != null;

        final Future<void> answering = repository.answerPersonStep(
          runId: asked.runId,
          stepName: asked.stepName,
          answer: answer,
        );
        if (isAccepted) {
          await answering;
        } else {
          await expectLater(answering, throwsStateError);
        }

        expect(repository.listOpenPersonSteps().contains(asked), !isAccepted);
        expect(
          repository.listOpenPersonSteps().length,
          openSteps.length - (isAccepted ? 1 : 0),
        );
      }
    },
  );
}
