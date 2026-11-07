import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_harness.dart';
import '../node_backed/support/simulated_person_step_node.dart';
import 'support/person_step_inputs.dart';
import 'support/person_step_runs.dart';

const String _typePrefix = 'test_fake_person_step_repository';
const int _sequenceIterations = 40;
const int _largestNodeStepCount = 6;
const int _longestSequence = 8;
const String _anyAnswer = 'approved';

typedef _Pair = ({
  FakePersonStepRepository fake,
  NodeBackedPersonStepRepository nodeBacked,
});

typedef _StepKey = ({RunId runId, String stepName});

typedef _AskedAnswer = ({_StepKey asked, String answer});

List<_StepKey> _describeSteps(List<OpenPersonStep> openSteps) {
  return <_StepKey>[
    for (final OpenPersonStep openStep in openSteps)
      (runId: openStep.runId, stepName: openStep.stepName),
  ];
}

Future<_Pair> _buildPair(Random random) async {
  final SimulatedPersonStepNode simulated = SimulatedPersonStepNode();
  final int count = random.nextInt(_largestNodeStepCount);
  for (int i = 0; i < count; i += 1) {
    simulated.askFromElsewhere(random);
    simulated.openSteps.last['choices'] = randomStepChoices(random);
  }
  final NodeBackedPersonStepRepository nodeBacked =
      NodeBackedPersonStepRepository(
        channel: buildSimulatedChannel(simulated.answer),
      );
  await nodeBacked.load();
  final List<OpenPersonStep> listed = nodeBacked.listOpenPersonSteps();
  final FakePersonStepRepository fake = FakePersonStepRepository(
    openSteps: listed,
    taskRepository: buildRunsAskingSteps(random, listed),
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

Future<RecordNotFound?> _findRefusal(
  PersonStepRepository repository,
  _AskedAnswer askedAnswer,
) async {
  try {
    await repository.answerPersonStep(
      runId: askedAnswer.asked.runId,
      stepName: askedAnswer.asked.stepName,
      answer: askedAnswer.answer,
    );
  } on RecordNotFound catch (refusal) {
    return refusal;
  }
  return null;
}

_AskedAnswer _pickAsked(Random random, List<OpenPersonStep> listed) {
  if (listed.isEmpty || random.nextInt(4) == 0) {
    final _StepKey missing = (
      runId: RunId('run-missing-${random.nextInt(100)}'),
      stepName: 'missing-${random.nextInt(100)}',
    );
    return (asked: missing, answer: _anyAnswer);
  }
  final OpenPersonStep picked = pickOne(random, listed);
  final _StepKey asked = (runId: picked.runId, stepName: picked.stepName);
  if (picked.choices.isEmpty) {
    return (asked: asked, answer: randomText(random) + _anyAnswer);
  }
  return (asked: asked, answer: pickOne(random, picked.choices));
}

void main() {
  test('${_typePrefix}_constructor_property_keeps_every_step_in_'
      'order', () {
    final Random random = seededRandom(65501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);

      final CountedPersonSteps counted = buildCountedPersonSteps(seeded);

      expect(counted.repository.listOpenPersonSteps(), orderedEquals(seeded));
      expect(counted.notifications.count, 0);
    }
  });

  test('${_typePrefix}_constructor_property_copies_the_given_list', () {
    final Random random = seededRandom(65502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final List<OpenPersonStep> callerList = List<OpenPersonStep>.of(seeded);
      final CountedPersonSteps counted = buildCountedPersonSteps(callerList);

      callerList.add(randomOpenStep(random, seeded.length));
      callerList.shuffle(random);

      expect(counted.repository.listOpenPersonSteps(), orderedEquals(seeded));
    }
  });

  test('${_typePrefix}_constructor_property_agrees_with_the_node_'
      'listing', () async {
    final Random random = seededRandom(65503);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);

      expect(
        _describeSteps(pair.fake.listOpenPersonSteps()),
        orderedEquals(_describeSteps(pair.nodeBacked.listOpenPersonSteps())),
      );
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_callers_cannot_'
      'change_it', () async {
    final Random random = seededRandom(65504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final CountedPersonSteps counted = buildCountedPersonSteps(seeded);
      if (seeded.isNotEmpty && random.nextBool()) {
        final OpenPersonStep asked = pickOne(random, seeded);
        await counted.repository.answerPersonStep(
          runId: asked.runId,
          stepName: asked.stepName,
          answer: asked.choices.isEmpty ? _anyAnswer : asked.choices.first,
        );
      }
      final List<OpenPersonStep> listed = counted.repository
          .listOpenPersonSteps();

      expect(
        () => listed.add(randomOpenStep(random, seeded.length)),
        throwsUnsupportedError,
      );
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_loses_exactly_the_'
      'answered_steps', () async {
    final Random random = seededRandom(65505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final CountedPersonSteps counted = buildCountedPersonSteps(seeded);
      final List<OpenPersonStep> expected = List<OpenPersonStep>.of(seeded);
      final int answerCount = random.nextInt(seeded.length + 1);

      for (int answer = 0; answer < answerCount; answer += 1) {
        final OpenPersonStep asked = pickOne(random, expected);
        await counted.repository.answerPersonStep(
          runId: asked.runId,
          stepName: asked.stepName,
          answer: asked.choices.isEmpty ? _anyAnswer : asked.choices.last,
        );
        expected.remove(asked);
      }

      expect(
        counted.repository.listOpenPersonSteps(),
        orderedEquals(expected),
      );
      expect(counted.notifications.count, answerCount);
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_agrees_with_the_'
      'node_backed_repository', () async {
    final Random random = seededRandom(65506);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final _AskedAnswer asked = _pickAsked(
          random,
          pair.nodeBacked.listOpenPersonSteps(),
        );

        final RecordNotFound? fakeRefusal = await _findRefusal(
          pair.fake,
          asked,
        );
        final RecordNotFound? nodeRefusal = await _findRefusal(
          pair.nodeBacked,
          asked,
        );

        expect(fakeRefusal?.kind, nodeRefusal?.kind);
        expect(fakeRefusal?.identifier, nodeRefusal?.identifier);
        expect(
          _describeSteps(pair.fake.listOpenPersonSteps()),
          orderedEquals(_describeSteps(pair.nodeBacked.listOpenPersonSteps())),
        );
      }
    }
  });
}
