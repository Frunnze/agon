import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';

import '../../support/random_inputs.dart';
import 'support/person_step_inputs.dart';
import 'support/person_step_rigs.dart';
import 'support/person_step_run_statuses.dart';
import 'support/task_inputs.dart';

const String _typePrefix = 'test_fake_person_step_repository';
const String _otherTaskPrefix = 'other-';
const String _unrelatedRunPrefix = 'unrelated-';
const String _runningStatus = 'running';

void main() {
  test('test_is_run_still_active_property_lists_exactly_the_active_'
      'statuses', () {
    final Random random = seededRandom(67101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final Map<RunId, String> statuses = pickRunStatuses(
        random,
        seeded,
        <String>[...activeRunStatusCodes, ...finishedRunStatusCodes],
      );
      final FakePersonStepRepository repository = buildPersonStepsOverRuns(
        seeded,
        buildRunsWithStatuses(random, seeded, statuses),
      );
      final List<OpenPersonStep> expected = <OpenPersonStep>[
        for (final OpenPersonStep openStep in seeded)
          if (activeRunStatusCodes.contains(statuses[openStep.runId]))
            openStep,
      ];

      expect(repository.listOpenPersonSteps(), orderedEquals(expected));
    }
  });

  test('test_is_run_still_active_property_runs_filed_under_another_task_'
      'list_nothing', () {
    final Random random = seededRandom(67102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final List<Run> runs = <Run>[
        for (final RunId runId in listStepRunIds(seeded))
          buildSeededRun(
            random,
            runId: runId.value,
            taskId: TaskId('$_otherTaskPrefix${runId.value}'),
            number: 1,
            status: pickOne(random, activeRunStatusCodes),
          ),
      ];

      final FakePersonStepRepository repository = buildPersonStepsOverRuns(
        seeded,
        runs,
      );

      expect(repository.listOpenPersonSteps(), isEmpty);
    }
  });

  test('test_is_run_still_active_property_other_active_runs_of_the_task_'
      'do_not_count', () {
    final Random random = seededRandom(67103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final List<Run> runs = <Run>[
        for (final OpenPersonStep openStep in seeded)
          buildSeededRun(
            random,
            runId: '$_unrelatedRunPrefix${openStep.runId.value}',
            taskId: openStep.taskId,
            number: 1,
            status: _runningStatus,
          ),
      ];

      final FakePersonStepRepository repository = buildPersonStepsOverRuns(
        seeded,
        runs,
      );

      expect(repository.listOpenPersonSteps(), isEmpty);
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_cancelling_hides_'
      'exactly_those_runs', () async {
    final Random random = seededRandom(67104);

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

      expect(
        rig.repository.listOpenPersonSteps(),
        orderedEquals(keepStepsOutsideRuns(seeded, cancelled)),
      );
      expect(rig.notifications.count, cancelled.length);
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_lists_steps_only_'
      'while_their_run_is_active', () async {
    final Random random = seededRandom(67105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      if (seeded.isEmpty) {
        continue;
      }
      final PersonStepRig rig = buildPersonStepRig(random, seeded);
      final int toggleCount = 1 + random.nextInt(seeded.length * 2);
      Set<RunId> cancelled = <RunId>{};

      for (int toggle = 0; toggle < toggleCount; toggle += 1) {
        cancelled = await toggleRandomRun(
          random: random,
          taskRepository: rig.taskRepository,
          runIds: listStepRunIds(seeded),
          cancelledRunIds: cancelled,
        );

        expect(
          rig.repository.listOpenPersonSteps(),
          orderedEquals(keepStepsOutsideRuns(seeded, cancelled)),
        );
      }
      expect(rig.notifications.count, toggleCount);
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_answered_steps_'
      'stay_gone_after_a_retry', () async {
    final Random random = seededRandom(67106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<OpenPersonStep> seeded = randomOpenSteps(random);
      final PersonStepRig rig = buildPersonStepRig(random, seeded);
      final List<OpenPersonStep> expected = <OpenPersonStep>[];
      for (final OpenPersonStep openStep in seeded) {
        if (random.nextBool()) {
          await rig.repository.answerPersonStep(
            runId: openStep.runId,
            stepName: openStep.stepName,
            answer: pickMatchingAnswer(random, openStep),
          );
        } else {
          expected.add(openStep);
        }
      }

      for (final RunId runId in listStepRunIds(seeded)) {
        await rig.taskRepository.cancelRun(runId);
        await rig.taskRepository.retryRun(runId);
      }

      expect(rig.repository.listOpenPersonSteps(), orderedEquals(expected));
    }
  });
}
