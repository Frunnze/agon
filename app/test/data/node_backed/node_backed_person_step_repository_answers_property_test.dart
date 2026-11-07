import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import '../fakes/support/person_step_inputs.dart';
import '../fakes/support/person_step_rigs.dart';
import '../fakes/support/person_step_runs.dart';
import 'support/node_backed_person_step_rig.dart';

const String _typePrefix = 'test_node_backed_person_step_repository';
const int _iterations = 60;
const int _largestMissingIndex = 20;
const String _acceptedOutcome = 'accepted';
const List<node.ChangeArea> _reloadingAreas = <node.ChangeArea>[
  node.ChangeArea.tasks,
];

enum _AnswerKind { matching, unmatched, blank, missingStep }

typedef _AskedAnswer = ({RunId runId, String stepName, String answer});

String _reportAccepted(Object? answered) => _acceptedOutcome;

bool _isRefusal(Object error) {
  return error is ArgumentError ||
      error is StateError ||
      error is RecordNotFound;
}

String _describeRefusal(Object error) {
  if (error is ArgumentError) {
    return 'ArgumentError: ${error.message}';
  }
  if (error is StateError) {
    return 'StateError: ${error.message}';
  }
  return 'RecordNotFound: $error';
}

Future<String> _describeOutcome(
  PersonStepRepository repository,
  _AskedAnswer asked,
) {
  final Future<void> answering = repository.answerPersonStep(
    runId: asked.runId,
    stepName: asked.stepName,
    answer: asked.answer,
  );
  final Future<String> accepted = answering.then(_reportAccepted);
  return accepted.catchError(_describeRefusal, test: _isRefusal);
}

_AskedAnswer _pickAskedAnswer(Random random, List<OpenPersonStep> listed) {
  final _AnswerKind kind = pickOne(random, _AnswerKind.values);
  final OpenPersonStep openStep = kind == _AnswerKind.missingStep
      ? randomOpenStep(random, random.nextInt(_largestMissingIndex))
      : pickOne(random, listed);
  final String answer = switch (kind) {
    _AnswerKind.matching ||
    _AnswerKind.missingStep => pickMatchingAnswer(random, openStep),
    _AnswerKind.unmatched => 'none of them ${random.nextInt(99)}',
    _AnswerKind.blank => pickOne(random, blankPersonAnswers),
  };
  return (runId: openStep.runId, stepName: openStep.stepName, answer: answer);
}

List<node.ChangeArea> _listQuietAreas() {
  return <node.ChangeArea>[
    for (final node.ChangeArea area in node.ChangeArea.values)
      if (!_reloadingAreas.contains(area)) area,
  ];
}

Future<NodeBackedPersonStepRig> _buildLoadedRig(Random random) async {
  final NodeBackedPersonStepRig rig = NodeBackedPersonStepRig();
  rig.askRandomSteps(random);
  await rig.repository.load();
  return rig;
}

void main() {
  test('${_typePrefix}_apply_change_property_run_and_task_topics_'
      'reload', () async {
    final Random random = seededRandom(78901);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = await _buildLoadedRig(random);
      rig.askRandomSteps(random);
      final int commandsBefore = rig.commandNames.length;
      final node.ChangeTopic topic = pickOne(random, <node.ChangeTopic>[
        node.RunChanged(runId: RunId(randomText(random))),
        const node.AreaChanged(area: node.ChangeArea.tasks),
      ]);

      await rig.repository.applyChange(topic);

      expect(rig.commandNames.sublist(commandsBefore), <String>[
        listPersonStepsCommand,
      ]);
      expect(rig.describeListedSteps(), rig.describeNodeSteps());
    }
  });

  test('${_typePrefix}_apply_change_property_other_areas_send_'
      'nothing', () async {
    final Random random = seededRandom(78902);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = await _buildLoadedRig(random);
      final List<OpenPersonStep> before = rig.repository.listOpenPersonSteps();
      final int commandsBefore = rig.commandNames.length;
      final int notificationsBefore = rig.notifications.count;
      rig.askRandomSteps(random);
      final node.ChangeArea area = pickOne(random, _listQuietAreas());

      await rig.repository.applyChange(node.AreaChanged(area: area));

      expect(rig.commandNames.length, commandsBefore);
      expect(rig.notifications.count, notificationsBefore);
      expect(identical(rig.repository.listOpenPersonSteps(), before), isTrue);
    }
  });

  test('${_typePrefix}_apply_change_property_finished_runs_drop_their_'
      'steps', () async {
    final Random random = seededRandom(78903);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = await _buildLoadedRig(random);
      final List<OpenPersonStep> everyStep = rig.repository
          .listOpenPersonSteps();
      final Set<RunId> finished = pickRandomRuns(
        random,
        listStepRunIds(everyStep),
      );
      for (final RunId runId in finished) {
        rig.simulated.finishedRunIds.add(runId.value);
      }

      await rig.repository.applyChange(
        node.RunChanged(runId: pickOne(random, everyStep).runId),
      );

      expect(
        rig.repository.listOpenPersonSteps(),
        hasLength(keepStepsOutsideRuns(everyStep, finished).length),
      );
      expect(rig.describeListedSteps(), rig.describeNodeSteps());
    }
  });

  test('${_typePrefix}_answer_person_step_property_refuses_exactly_like_'
      'the_fake', () async {
    final Random random = seededRandom(78904);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = await _buildLoadedRig(random);
      final List<OpenPersonStep> listed = rig.repository.listOpenPersonSteps();
      final FakePersonStepRepository fake = FakePersonStepRepository(
        openSteps: listed,
        taskRepository: buildRunsAskingSteps(random, listed),
      );
      final _AskedAnswer asked = _pickAskedAnswer(random, listed);

      final String nodeOutcome = await _describeOutcome(rig.repository, asked);
      final String fakeOutcome = await _describeOutcome(fake, asked);

      expect(nodeOutcome, fakeOutcome, reason: '$asked');
      expect(rig.describeListedSteps(), <StepKey>[
        for (final OpenPersonStep openStep in fake.listOpenPersonSteps())
          (runId: openStep.runId.value, stepName: openStep.stepName),
      ]);
      fake.dispose();
    }
  });

  test('${_typePrefix}_answer_person_step_property_finished_runs_refuse_'
      'answers', () async {
    final Random random = seededRandom(78905);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = await _buildLoadedRig(random);
      final OpenPersonStep asked = pickOne(
        random,
        rig.repository.listOpenPersonSteps(),
      );
      rig.simulated.finishedRunIds.add(asked.runId.value);
      final int answersBefore = rig.simulated.receivedAnswers.length;

      await expectLater(
        rig.repository.answerPersonStep(
          runId: asked.runId,
          stepName: asked.stepName,
          answer: pickMatchingAnswer(random, asked),
        ),
        throwsA(
          isA<RecordNotFound>().having(
            (RecordNotFound missing) => missing.identifier,
            'identifier',
            asked.stepName,
          ),
        ),
      );

      expect(rig.simulated.receivedAnswers, hasLength(answersBefore));
    }
  });

  test('${_typePrefix}_answer_person_step_property_white_space_padded_'
      'answers_match_like_rust', () async {
    final Random random = seededRandom(78906);
    final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

    for (int i = 0; i < _iterations; i += 1) {
      final NodeBackedPersonStepRig rig = await _buildLoadedRig(random);
      final OpenPersonStep asked = pickOne(
        random,
        rig.repository.listOpenPersonSteps(),
      );
      final String answer = padWithRustWhiteSpace(
        random,
        table,
        pickOne(random, <String>[
          pickMatchingAnswer(random, asked),
          randomText(random),
          '',
        ]),
      );
      final bool isAccepted = isAcceptedLikeRust(
        table: table,
        answer: answer,
        choices: asked.choices,
      );

      final String outcome = await _describeOutcome(rig.repository, (
        runId: asked.runId,
        stepName: asked.stepName,
        answer: answer,
      ));

      expect(outcome == _acceptedOutcome, isAccepted, reason: answer);
      if (isAccepted) {
        expect(rig.simulated.receivedAnswers.last, answer);
      }
      final bool isStillListed = rig.describeListedSteps().contains((
        runId: asked.runId.value,
        stepName: asked.stepName,
      ));
      expect(isStillListed, !isAccepted);
    }
  });
}
