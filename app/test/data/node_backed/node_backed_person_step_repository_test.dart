import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/person_answers.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_person_step_node.dart';

const int _sequenceIterations = 25;
const int _stepsPerSequence = 8;

void _expectMirrorsNode(
  SimulatedPersonStepNode simulated,
  NodeBackedPersonStepRepository repository,
) {
  final List<OpenPersonStep> listed = repository.listOpenPersonSteps();
  expect(
    <String>[for (final OpenPersonStep step in listed) step.stepName],
    <Object?>[
      for (final Map<String, Object?> step in simulated.openSteps)
        step['step_name'],
    ],
  );
}

List<String> _listMatchingChoices(OpenPersonStep openStep) {
  final List<String> matching = <String>[];
  for (final String choice in openStep.choices) {
    final bool isBlank = trimUnicodeWhiteSpace(choice).isEmpty;
    if (!isBlank && matchChoice(choice, openStep.choices) == choice) {
      matching.add(choice);
    }
  }
  return matching;
}

List<OpenPersonStep> _listAnswerable(List<OpenPersonStep> listed) {
  final List<OpenPersonStep> answerable = <OpenPersonStep>[];
  for (final OpenPersonStep openStep in listed) {
    final bool hasChoice = _listMatchingChoices(openStep).isNotEmpty;
    if (openStep.choices.isEmpty || hasChoice) {
      answerable.add(openStep);
    }
  }
  return answerable;
}

void main() {
  test(
    'test_answer_person_step_property_open_steps_mirror_the_node',
    () async {
      final Random random = seededRandom(9941);

      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SimulatedPersonStepNode simulated = SimulatedPersonStepNode();
        final NodeBackedPersonStepRepository repository =
            NodeBackedPersonStepRepository(
              channel: buildSimulatedChannel(simulated.answer),
            );
        await repository.load();

        for (int step = 0; step < _stepsPerSequence; step += 1) {
          final List<OpenPersonStep> answerable = _listAnswerable(
            repository.listOpenPersonSteps(),
          );
          if (answerable.isNotEmpty && random.nextBool()) {
            final OpenPersonStep answered = pickOne(random, answerable);
            final String answer = answered.choices.isEmpty
                ? 'approved'
                : pickOne(random, _listMatchingChoices(answered));
            await repository.answerPersonStep(
              runId: answered.runId,
              stepName: answered.stepName,
              answer: answer,
            );
          } else {
            simulated.askFromElsewhere(random);
            await repository.applyChange(
              node.RunChanged(runId: RunId(randomText(random))),
            );
          }
          _expectMirrorsNode(simulated, repository);
        }
      }
    },
  );

  test('other areas leave the open steps alone', () async {
    final SimulatedPersonStepNode simulated = SimulatedPersonStepNode();
    final NodeBackedPersonStepRepository repository =
        NodeBackedPersonStepRepository(
          channel: buildSimulatedChannel(simulated.answer),
        );
    simulated.askFromElsewhere(seededRandom(9942));

    await repository.applyChange(
      const node.AreaChanged(area: node.ChangeArea.skills),
    );

    expect(repository.listOpenPersonSteps(), isEmpty);
  });

  test('answering a step the node no longer has fails as not found', () async {
    final SimulatedPersonStepNode simulated = SimulatedPersonStepNode();
    final NodeBackedPersonStepRepository repository =
        NodeBackedPersonStepRepository(
          channel: buildSimulatedChannel(simulated.answer),
        );

    expect(
      () => repository.answerPersonStep(
        runId: const RunId('missing'),
        stepName: 'review',
        answer: 'approved',
      ),
      throwsA(isA<RecordNotFound>()),
    );
  });
}
