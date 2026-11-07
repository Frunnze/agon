import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';

import '../../support/random_inputs.dart';
import 'support/person_step_inputs.dart';
import 'support/person_step_rigs.dart';
import 'support/person_step_run_statuses.dart';

const String _typePrefix = 'test_fake_person_step_repository';

void main() {
  test('${_typePrefix}_answer_person_step_property_steps_of_cancelled_'
      'runs_are_not_found_and_kept', () async {
    final Random random = seededRandom(67107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      if (seeded.isEmpty) {
        continue;
      }
      final PersonStepRig rig = buildPersonStepRig(random, seeded);
      final OpenPersonStep asked = pickOne(random, seeded);
      final String answer = pickMatchingAnswer(random, asked);
      await rig.taskRepository.cancelRun(asked.runId);
      final int notificationsBefore = rig.notifications.count;

      await expectLater(
        rig.repository.answerPersonStep(
          runId: asked.runId,
          stepName: asked.stepName,
          answer: answer,
        ),
        throwsOpenStepNotFound(asked),
      );
      expect(rig.notifications.count, notificationsBefore);
      expect(
        rig.repository.listOpenPersonSteps(),
        orderedEquals(keepStepsOutsideRuns(seeded, <RunId>{asked.runId})),
      );

      await rig.taskRepository.retryRun(asked.runId);
      expect(rig.repository.listOpenPersonSteps(), orderedEquals(seeded));
    }
  });

  test('${_typePrefix}_answer_person_step_property_steps_of_finished_'
      'runs_are_not_found', () async {
    final Random random = seededRandom(67108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakePersonStepRepository repository = buildPersonStepsOverRuns(
        seeded,
        buildRunsWithStatuses(
          random,
          seeded,
          pickRunStatuses(random, seeded, finishedRunStatusCodes),
        ),
      );
      final OpenPersonStep asked = pickOne(random, seeded);

      await expectLater(
        repository.answerPersonStep(
          runId: asked.runId,
          stepName: asked.stepName,
          answer: pickMatchingAnswer(random, asked),
        ),
        throwsOpenStepNotFound(asked),
      );
      expect(repository.listOpenPersonSteps(), isEmpty);
    }
  });

  test('${_typePrefix}_answer_person_step_property_blank_answers_are_'
      'refused_before_the_lookup', () async {
    final Random random = seededRandom(67109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final PersonStepRig rig = buildPersonStepRig(random, seeded);
      final Set<RunId> cancelled = pickRandomRuns(
        random,
        listStepRunIds(seeded),
      );
      for (final RunId runId in cancelled) {
        await rig.taskRepository.cancelRun(runId);
      }
      final OpenPersonStep asked = seeded.isNotEmpty && random.nextBool()
          ? pickOne(random, seeded)
          : randomOpenStep(random, seeded.length);
      final int notificationsBefore = rig.notifications.count;

      await expectLater(
        rig.repository.answerPersonStep(
          runId: asked.runId,
          stepName: asked.stepName,
          answer: pickOne(random, blankPersonAnswers),
        ),
        throwsArgumentError,
      );
      expect(rig.notifications.count, notificationsBefore);
      expect(
        rig.repository.listOpenPersonSteps(),
        orderedEquals(keepStepsOutsideRuns(seeded, cancelled)),
      );
    }
  });
}
