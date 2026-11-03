import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';

import '../support/random_branching_workflows.dart';
import '../support/random_inputs.dart';

EarlierRound _randomEarlierRound(Random random) {
  final DateTime startedAt = randomUtcMoment(random);
  return EarlierRound(
    status: pickOne(random, StepStatus.values),
    startedAt: startedAt,
    finishedAt: startedAt.add(Duration(seconds: random.nextInt(4000))),
    result: randomWordPhrase(random),
    outcome: random.nextBool() ? pickOne(random, sampleOutcomes) : null,
  );
}

RunStep _stepFor({
  required WorkflowAgent agent,
  required String? loopSource,
  required List<EarlierRound> earlierRounds,
  required String? result,
}) {
  return RunStep(
    name: agent.name,
    agentId: agent.id,
    runner: null,
    status: StepStatus.done,
    startedAt: null,
    finishedAt: null,
    result: result,
    outcome: null,
    loopSource: loopSource,
    earlierRounds: earlierRounds,
  );
}

Run _runOf(List<RunStep> steps) {
  return galleryRunningRun.withProgress(
    nextStatus: RunStatus.running,
    nextSteps: steps,
    nextFinishedAt: null,
  );
}

void main() {
  test('test_describe_step_round_property_counts_rounds_against_limit', () {
    final Random random = seededRandom(9911);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<AgentConnection> loops = <AgentConnection>[
        for (final AgentConnection connection in workflow.connections)
          if (connection.isLoop) connection,
      ];
      if (loops.isEmpty) {
        continue;
      }
      final AgentConnection loop = pickOne(random, loops);
      final int earlierCount = random.nextInt(4);
      final RunStep step = _stepFor(
        agent: workflow.findAgent(loop.to),
        loopSource: workflow.findAgent(loop.from).name,
        earlierRounds: <EarlierRound>[
          for (int round = 0; round < earlierCount; round += 1)
            _randomEarlierRound(random),
        ],
        result: null,
      );

      final String? text = describeStepRound(step: step, workflow: workflow);

      if (earlierCount == 0) {
        expect(text, isNull);
      } else {
        expect(text, 'round ${earlierCount + 1} of ${loop.roundLimit! + 1}');
      }
      expect(
        describeStepRound(step: step, workflow: null) == null,
        earlierCount == 0,
      );
    }
  });

  test('test_describe_step_outcome_property_points_at_the_outcome', () {
    final Random random = seededRandom(9912);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String outcome = randomWordPhrase(random);

      expect(describeStepOutcome(outcome), '→\u00A0$outcome');
    }
    expect(describeStepOutcome(null), isNull);
  });

  test('test_describe_earlier_round_property_numbers_and_names_status', () {
    final Random random = seededRandom(9913);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EarlierRound round = _randomEarlierRound(random);
      final int roundNumber = 1 + random.nextInt(9);

      final String text = describeEarlierRound(
        round: round,
        roundNumber: roundNumber,
        statusText: 'Done',
      );

      expect(text, startsWith('Round $roundNumber · Done'));
      expect(text.contains('→\u00A0'), round.outcome != null);
      expect(text, contains('took '));
    }
  });

  test('test_describe_show_earlier_rounds_property_counts_rounds', () {
    for (int count = 1; count < 12; count += 1) {
      expect(describeShowEarlierRounds(count), startsWith('Show $count'));
      expect(describeHideEarlierRounds(count), startsWith('Hide $count'));
    }
    expect(describeShowEarlierRounds(1), 'Show 1 earlier round');
    expect(describeHideEarlierRounds(2), 'Hide 2 earlier rounds');
  });

  test('test_find_incoming_results_property_only_feeding_finished_steps', () {
    final Random random = seededRandom(9914);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final List<RunStep> steps = <RunStep>[
        for (final WorkflowAgent agent in workflow.agents)
          _stepFor(
            agent: agent,
            loopSource: null,
            earlierRounds: const <EarlierRound>[],
            result: random.nextBool() ? randomWordPhrase(random) : null,
          ),
      ];
      final WorkflowAgent target = pickOne(random, workflow.agents);

      final List<RunStep> incoming = findIncomingResults(
        run: _runOf(steps),
        workflow: workflow,
        stepName: target.name,
      );

      for (final RunStep step in incoming) {
        expect(step.result, isNotNull);
        final bool feedsTarget = workflow.connections.any(
          (AgentConnection connection) =>
              connection.from == step.agentId && connection.to == target.id,
        );
        expect(feedsTarget, isTrue);
      }
      for (final RunStep step in steps) {
        final bool feedsTarget = workflow.connections.any(
          (AgentConnection connection) =>
              connection.from == step.agentId && connection.to == target.id,
        );
        if (feedsTarget && step.result != null) {
          expect(incoming, contains(step));
        }
      }
    }
  });
}
