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
import 'support/person_step_rigs.dart';
import 'support/person_step_runs.dart';

const String _typePrefix = 'test_fake_person_step_repository';
const int _sequenceIterations = 40;
const int _largestNodeStepCount = 6;
const int _longestSequence = 10;
const int _largestMissingIndex = 10;
const String _acceptedOutcome = 'accepted';
const String _refusedOutcome = 'refused';
const String _notFoundOutcome = 'not found';
const String _unmatchedAnswerStart = 'none of them';

enum _AnswerKind { matching, unmatched, blank }

typedef _Pair = ({
  SimulatedPersonStepNode simulated,
  NodeBackedPersonStepRepository nodeBacked,
  FakeTaskRepository taskRepository,
  FakePersonStepRepository fake,
  List<OpenPersonStep> everyStep,
});

typedef _StepKey = ({RunId runId, String stepName});

typedef _AskedAnswer = ({
  OpenPersonStep asked,
  _AnswerKind kind,
  String answer,
});

typedef _Outcomes = ({String fake, String node, String expected});

List<_StepKey> _describeSteps(List<OpenPersonStep> openSteps) {
  return <_StepKey>[
    for (final OpenPersonStep openStep in openSteps)
      (runId: openStep.runId, stepName: openStep.stepName),
  ];
}

Set<RunId> _finishedRunIds(_Pair pair) {
  return <RunId>{
    for (final Object? runId in pair.simulated.finishedRunIds)
      RunId(runId! as String),
  };
}

Future<_Pair> _buildPair(Random random) async {
  final SimulatedPersonStepNode simulated = SimulatedPersonStepNode();
  final int count = 1 + random.nextInt(_largestNodeStepCount);
  for (int i = 0; i < count; i += 1) {
    simulated.askFromElsewhere(random);
    simulated.openSteps.last['choices'] = randomStepChoices(random);
  }
  final NodeBackedPersonStepRepository nodeBacked =
      NodeBackedPersonStepRepository(
        channel: buildSimulatedChannel(simulated.answer),
      );
  await nodeBacked.load();
  final List<OpenPersonStep> everyStep = nodeBacked.listOpenPersonSteps();
  final FakeTaskRepository taskRepository = buildRunsAskingSteps(
    random,
    everyStep,
  );
  final Set<RunId> finished = pickRandomRuns(
    random,
    listStepRunIds(everyStep),
  );
  for (final RunId runId in finished) {
    await taskRepository.cancelRun(runId);
    simulated.finishedRunIds.add(runId.value);
  }
  await nodeBacked.load();

  final FakePersonStepRepository fake = FakePersonStepRepository(
    openSteps: everyStep,
    taskRepository: taskRepository,
  );
  return (
    simulated: simulated,
    nodeBacked: nodeBacked,
    taskRepository: taskRepository,
    fake: fake,
    everyStep: everyStep,
  );
}

Future<void> _toggleRandomRun(Random random, _Pair pair) async {
  final Set<RunId> finished = await toggleRandomRun(
    random: random,
    taskRepository: pair.taskRepository,
    runIds: listStepRunIds(pair.everyStep),
    cancelledRunIds: _finishedRunIds(pair),
  );
  pair.simulated.finishedRunIds.clear();
  for (final RunId runId in finished) {
    pair.simulated.finishedRunIds.add(runId.value);
  }
  await pair.nodeBacked.load();
}

String _pickAnswer(Random random, OpenPersonStep asked, _AnswerKind kind) {
  return switch (kind) {
    _AnswerKind.matching => pickMatchingAnswer(random, asked),
    _AnswerKind.unmatched => '$_unmatchedAnswerStart ${random.nextInt(99)}',
    _AnswerKind.blank => pickOne(random, blankPersonAnswers),
  };
}

_AskedAnswer _pickAskedAnswer(Random random, _Pair pair) {
  final bool asksMissingStep = random.nextInt(4) == 0;
  final OpenPersonStep asked = asksMissingStep
      ? randomOpenStep(random, random.nextInt(_largestMissingIndex))
      : pickOne(random, pair.everyStep);
  final _AnswerKind kind = pickOne(random, _AnswerKind.values);
  return (asked: asked, kind: kind, answer: _pickAnswer(random, asked, kind));
}

bool _isStillAskedByModel(_Pair pair, OpenPersonStep asked) {
  if (pair.simulated.finishedRunIds.contains(asked.runId.value)) {
    return false;
  }
  return pair.simulated.openSteps.any(
    (Map<String, Object?> openStep) =>
        openStep['run_id'] == asked.runId.value &&
        openStep['step_name'] == asked.stepName,
  );
}

String _expectOutcome(_Pair pair, _AskedAnswer askedAnswer) {
  if (askedAnswer.kind == _AnswerKind.blank) {
    return _refusedOutcome;
  }
  if (!_isStillAskedByModel(pair, askedAnswer.asked)) {
    return '$_notFoundOutcome ${askedAnswer.asked.stepName}';
  }
  final bool hasChoices = askedAnswer.asked.choices.isNotEmpty;
  if (askedAnswer.kind == _AnswerKind.unmatched && hasChoices) {
    return _refusedOutcome;
  }
  return _acceptedOutcome;
}

String _reportAccepted(Object? answered) => _acceptedOutcome;

bool _isAnswerRefusal(Object error) {
  return error is ArgumentError ||
      error is StateError ||
      error is RecordNotFound;
}

String _describeRefusal(Object error) {
  if (error is RecordNotFound) {
    return '$_notFoundOutcome ${error.identifier}';
  }
  return _refusedOutcome;
}

Future<String> _describeOutcome(
  PersonStepRepository repository,
  _AskedAnswer askedAnswer,
) {
  final Future<void> answering = repository.answerPersonStep(
    runId: askedAnswer.asked.runId,
    stepName: askedAnswer.asked.stepName,
    answer: askedAnswer.answer,
  );
  final Future<String> accepted = answering.then(_reportAccepted);
  return accepted.catchError(_describeRefusal, test: _isAnswerRefusal);
}

Future<_Outcomes> _answerOnBoth(Random random, _Pair pair) async {
  final _AskedAnswer askedAnswer = _pickAskedAnswer(random, pair);
  final String expected = _expectOutcome(pair, askedAnswer);
  final String fakeOutcome = await _describeOutcome(pair.fake, askedAnswer);
  final String nodeOutcome = await _describeOutcome(
    pair.nodeBacked,
    askedAnswer,
  );
  return (fake: fakeOutcome, node: nodeOutcome, expected: expected);
}

void _expectSameListing(_Pair pair) {
  expect(
    _describeSteps(pair.fake.listOpenPersonSteps()),
    orderedEquals(_describeSteps(pair.nodeBacked.listOpenPersonSteps())),
  );
}

void main() {
  test('${_typePrefix}_constructor_property_hides_runs_the_node_finished_'
      'first', () async {
    final Random random = seededRandom(67301);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);

      _expectSameListing(pair);
      expect(
        pair.fake.listOpenPersonSteps(),
        orderedEquals(
          keepStepsOutsideRuns(pair.everyStep, _finishedRunIds(pair)),
        ),
      );
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_agrees_with_the_'
      'node_as_runs_finish', () async {
    final Random random = seededRandom(67302);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        if (random.nextBool()) {
          await _toggleRandomRun(random, pair);
        } else {
          await _answerOnBoth(random, pair);
        }

        _expectSameListing(pair);
      }
    }
  });

  test('${_typePrefix}_answer_person_step_property_refuses_like_the_node_'
      'as_runs_finish', () async {
    final Random random = seededRandom(67303);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        if (random.nextInt(3) == 0) {
          await _toggleRandomRun(random, pair);
        }
        final _Outcomes outcomes = await _answerOnBoth(random, pair);

        expect(outcomes.fake, outcomes.expected);
        expect(outcomes.node, outcomes.expected);
      }
    }
  });

  test('test_is_run_still_active_property_follows_the_node_finished_'
      'runs', () async {
    final Random random = seededRandom(67304);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      final int toggleCount = 1 + random.nextInt(_longestSequence);

      for (int toggle = 0; toggle < toggleCount; toggle += 1) {
        await _toggleRandomRun(random, pair);

        final List<OpenPersonStep> expected = keepStepsOutsideRuns(
          pair.everyStep,
          _finishedRunIds(pair),
        );
        expect(pair.fake.listOpenPersonSteps(), orderedEquals(expected));
        _expectSameListing(pair);
      }
    }
  });
}
