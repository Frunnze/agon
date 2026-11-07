import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

const String _loopOutcome = 'again';
const int _loopRounds = 2;

Workflow _withConnection(Workflow workflow, AgentConnection connection) {
  return workflow.withGraph(
    agents: workflow.agents,
    connections: <AgentConnection>[...workflow.connections, connection],
  );
}

AgentConnection _randomCopy(Random random, AgentConnection original) {
  final String? condition = random.nextBool()
      ? null
      : pickOne(random, sampleOutcomes);
  return AgentConnection(
    from: original.from,
    to: original.to,
    condition: condition,
    roundLimit: random.nextBool() ? null : original.roundLimit,
  );
}

AgentConnection _randomPlainConnection(Random random, Workflow workflow) {
  return AgentConnection(
    from: pickOne(random, workflow.agents).id,
    to: pickOne(random, workflow.agents).id,
    condition: null,
    roundLimit: null,
  );
}

void main() {
  test(
    'test_describe_connections_problem_property_refuses_repeated_pairs',
    () {
      final Random random = seededRandom(77301);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = randomBranchingWorkflow(random);
        if (workflow.connections.isEmpty) {
          continue;
        }
        final AgentConnection original = pickOne(random, workflow.connections);
        final AgentConnection copy = _randomCopy(random, original);
        final Workflow repeated = _withConnection(workflow, copy);

        final String? problem = describeConnectionsProblem(repeated);

        expect(describeConnectionsProblem(workflow), isNull);
        expect(problem, isNotNull);
        final bool isPlainForwardCopy =
            copy.condition == null &&
            copy.roundLimit == null &&
            !original.isLoop;
        if (isPlainForwardCopy) {
          final String fromName = workflow.findAgent(original.from).name;
          final String toName = workflow.findAgent(original.to).name;
          expect(problem, contains('from $fromName to $toName'));
        }
      }
    },
  );

  test(
    'test_describe_connections_problem_property_agrees_with_the_editor',
    () {
      final Random random = seededRandom(77302);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = randomAcyclicWorkflow(random);
        if (workflow.agents.isEmpty) {
          continue;
        }
        final AgentConnection connection = _randomPlainConnection(
          random,
          workflow,
        );
        final ConnectionProblem? editorProblem = findConnectionProblem(
          workflow,
          connection,
        );

        final String? problem = describeConnectionsProblem(
          _withConnection(workflow, connection),
        );

        if (editorProblem == ConnectionProblem.alreadyConnected) {
          expect(problem, isNotNull);
        }
      }
    },
  );

  test('test_describe_connections_problem_property_keeps_the_way_back', () {
    final Random random = seededRandom(77303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final AgentConnection forward = pickOne(random, workflow.connections);
      final AgentConnection wayBack = AgentConnection(
        from: forward.to,
        to: forward.from,
        condition: _loopOutcome,
        roundLimit: 1 + random.nextInt(_loopRounds),
      );

      final String? problem = describeConnectionsProblem(
        _withConnection(workflow, wayBack),
      );

      expect(problem, isNull);
    }
  });
}
