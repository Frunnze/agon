import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/rules/run_step_progress.dart';

import '../../../bridge/support/random_live_json.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../support/random_inputs.dart';
import '../../models/support/random_run_records.dart';
import '../../rules/support/random_progress_runs.dart';
import 'support/live_run_event_sequences.dart';
import 'support/live_run_views.dart';

const int _largestStatusEventCount = 6;

Run _runWithSteps(Random random) {
  return buildLiveRun(
    random,
    steps: <RunStep>[
      randomRunStep(random),
      ...randomRecordsOf(random, randomRunStep),
    ],
    log: randomRecordsOf(random, randomLogLine),
    chat: randomRecordsOf(random, randomChatMessage),
  );
}

bool _isAccepted(Run run, String stepName) {
  return canChangeRunStep(run, stepName);
}

Run _applyEvents(Random random, Run run, List<node.RunEvent> events) {
  return applyLiveRunView(
    run: run,
    view: buildLiveView(events),
    at: randomPreciseMoment(random),
  );
}

node.StepStatusChanged _statusEvent(String stepName, node.StepStatus status) {
  return node.StepStatusChanged(stepName: stepName, status: status);
}

ShownRecord _describeFailure(RunFailure? failure) {
  if (failure == null) {
    return const <Object?>[];
  }
  return <Object?>[
    failure.stepName,
    failure.runner,
    failure.reason,
    failure.retryRunsOnSameRunner,
  ];
}

void main() {
  test(
    'test_change_step_status_property_other_steps_move_only_on_failure',
    () {
      final Random random = seededRandom(72121);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Run run = _runWithSteps(random);
        final String stepName = pickOne(random, run.steps).name;
        final node.StepStatus status = pickOne(random, node.StepStatus.values);

        final Run applied = _applyEvents(random, run, <node.RunEvent>[
          _statusEvent(stepName, status),
        ]);

        expect(applied.steps.length, run.steps.length);
        for (int index = 0; index < run.steps.length; index += 1) {
          final RunStep before = run.steps[index];
          final RunStep after = applied.steps[index];
          final bool isSkippedByFailure =
              applied.status == RunStatus.failed &&
              !isStepFinished(before.status);
          expect(after.name, before.name);
          if (before.name != stepName && !isSkippedByFailure) {
            expect(after.status, before.status);
          }
        }
      }
    },
  );

  test('test_change_step_status_property_changed_step_keeps_identity', () {
    final Random random = seededRandom(72122);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _runWithSteps(random);
      final String stepName = pickOne(random, run.steps).name;
      final node.StepStatus status = pickOne(random, node.StepStatus.values);

      final Run applied = _applyEvents(random, run, <node.RunEvent>[
        _statusEvent(stepName, status),
      ]);

      for (int index = 0; index < run.steps.length; index += 1) {
        final ShownRecord before = describeStepBesidesStatus(run.steps[index]);
        final ShownRecord after = describeStepBesidesStatus(
          applied.steps[index],
        );
        expect(after.sublist(0, 3), before.sublist(0, 3));
        expect(after.sublist(5), before.sublist(5));
      }
    }
  });

  test('test_change_step_status_property_last_event_wins_while_open', () {
    final Random random = seededRandom(72123);

    for (int i = 0; i < propertyIterations; i += 1) {
      Run run = freshHeldRun(random);
      final String stepName = pickOne(random, run.steps).name;
      final int eventCount = 1 + random.nextInt(_largestStatusEventCount);

      for (int index = 0; index < eventCount; index += 1) {
        final StepStatus status = pickOne(random, <StepStatus>[
          StepStatus.waiting,
          StepStatus.running,
          StepStatus.waitingForApproval,
          StepStatus.waitingForPerson,
        ]);
        run = _applyEvents(random, run, <node.RunEvent>[
          buildStatusEvent(stepName, status),
        ]);

        expect(stepsNamed(run, stepName).single.status, status);
        expect(isRunFinished(run.status), isFalse);
      }
    }
  });

  test('test_change_step_status_property_unknown_step_changes_nothing', () {
    final Random random = seededRandom(72124);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = _runWithSteps(random);
      final String unknownName = '${run.steps.first.name}$newRecordMark';
      final bool isNamedStep = run.steps.any(
        (RunStep step) => step.name == unknownName,
      );
      if (isNamedStep) {
        continue;
      }

      final Run applied = _applyEvents(random, run, <node.RunEvent>[
        _statusEvent(unknownName, pickOne(random, node.StepStatus.values)),
      ]);

      for (int index = 0; index < run.steps.length; index += 1) {
        expect(applied.steps[index].status, run.steps[index].status);
      }
    }
  });

  test('test_change_step_status_property_each_node_status_lands_apart', () {
    final Random random = seededRandom(72125);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = freshHeldRun(random);
      final RunStep step = run.steps.first;
      final Set<StepStatus> landedStatuses = <StepStatus>{};

      for (final node.StepStatus status in node.StepStatus.values) {
        final Run applied = _applyEvents(random, run, <node.RunEvent>[
          _statusEvent(step.name, status),
        ]);
        final StepStatus landed = applied.steps.first.status;
        landedStatuses.add(landed);

        expect(_isAccepted(run, step.name), isTrue);
        expect(landed.name, status.name);
      }
      expect(landedStatuses, StepStatus.values.toSet());
    }
  });

  test('test_apply_live_run_view_property_keeps_identity_and_history', () {
    final Random random = seededRandom(72126);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = randomLiveRun(random);
      final node.WatchView view = node.WatchView.fromJson(
        randomWatchViewJson(random),
      );

      final Run applied = applyLiveRunView(
        run: run,
        view: view,
        at: randomPreciseMoment(random),
      );

      expect(applied.id, run.id);
      expect(applied.taskId, run.taskId);
      expect(applied.number, run.number);
      expect(applied.startedBy, run.startedBy);
      expect(applied.startedAt, run.startedAt);
      expect(applied.loopRounds, orderedEquals(run.loopRounds));
      expect(applied.notes, orderedEquals(run.notes));
    }
  });

  test(
    'test_apply_live_run_view_property_latest_session_branch_and_failure',
    () {
      final Random random = seededRandom(72127);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Run run = randomLiveRun(random);
        final node.WatchView view = node.WatchView.fromJson(
          randomWatchViewJson(random),
        );
        String? expectedSession = run.agentSession;
        String? expectedBranch = run.worktreeBranch;
        final List<ShownRecord> possibleFailures = <ShownRecord>[
          _describeFailure(null),
          _describeFailure(run.failure),
        ];
        for (final node.RunEvent event in view.events) {
          if (event is node.SessionStarted) {
            expectedSession = event.session;
          }
          if (event is node.WorktreeCreated) {
            expectedBranch = event.branch;
          }
          if (event is node.RunFailed) {
            final RunFailure reported = mapRunFailureFromNode(event.failure);
            final List<RunStep> named = stepsNamed(run, reported.stepName);
            possibleFailures.add(
              _describeFailure(
                RunFailure(
                  stepName: reported.stepName,
                  runner: named.isEmpty ? null : named.first.runner,
                  reason: reported.reason,
                  retryRunsOnSameRunner: reported.retryRunsOnSameRunner,
                ),
              ),
            );
          }
        }

        final Run applied = applyLiveRunView(
          run: run,
          view: view,
          at: randomPreciseMoment(random),
        );

        expect(applied.agentSession, expectedSession);
        expect(applied.worktreeBranch, expectedBranch);
        expect(
          possibleFailures,
          anyElement(equals(_describeFailure(applied.failure))),
        );
      }
    },
  );
}
