import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const String _outcomeAlphabet = 'abcxyz0189 -_A.é';

bool _followsBackendOutcomeRule(String outcome) {
  final bool hasAllowedLength = outcome.isNotEmpty && outcome.length <= 40;
  final bool hasAllowedCharacters = RegExp(r'^[a-z0-9 \-]*$')
      .hasMatch(outcome);
  final bool isTrimmed = outcome.trim() == outcome;
  return hasAllowedLength && hasAllowedCharacters && isTrimmed;
}

String _randomOutcomeText(Random random) {
  final int length = random.nextInt(44);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    buffer.write(_outcomeAlphabet[random.nextInt(_outcomeAlphabet.length)]);
  }
  return buffer.toString();
}

Workflow _replaceConnectionAt(
  Workflow workflow,
  int index,
  AgentConnection replacement,
) {
  final List<AgentConnection> connections = List<AgentConnection>.of(
    workflow.connections,
  );
  connections[index] = replacement;
  return workflow.withGraph(agents: workflow.agents, connections: connections);
}

int? _findLoopIndex(Workflow workflow) {
  for (int index = 0; index < workflow.connections.length; index += 1) {
    if (workflow.connections[index].isLoop) {
      return index;
    }
  }
  return null;
}

void main() {
  test('test_is_well_formed_outcome_property_matches_the_backend_rule', () {
    final Random random = seededRandom(9701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String outcome = random.nextBool()
          ? _randomOutcomeText(random)
          : randomText(random);

      expect(
        isWellFormedOutcome(outcome),
        _followsBackendOutcomeRule(outcome),
      );
    }
  });

  test('test_describe_outcome_problem_property_one_step_never_repeats', () {
    final Random random = seededRandom(9702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final AgentConnection connection = pickOne(random, workflow.connections);
      final String outcome = pickOne(random, sampleOutcomes);
      final bool isTakenElsewhere = workflow.connections.any(
        (AgentConnection other) =>
            other.from == connection.from &&
            !other.joinsSameSteps(connection) &&
            other.condition == outcome,
      );

      final String? problem = describeOutcomeProblem(
        workflow: workflow,
        connection: connection,
        outcome: outcome,
      );

      expect(problem == null, !isTakenElsewhere);
    }
  });

  test('test_describe_connections_problem_property_accepts_valid_graphs', () {
    final Random random = seededRandom(9703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      expect(describeConnectionsProblem(workflow), isNull);
    }
  });

  test('test_describe_connections_problem_property_names_a_broken_loop', () {
    final Random random = seededRandom(9704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final int? loopIndex = _findLoopIndex(workflow);
      if (loopIndex == null) {
        continue;
      }
      final AgentConnection loop = workflow.connections[loopIndex];
      final List<AgentConnection> brokenLoops = <AgentConnection>[
        loop.withCondition(null),
        loop.withRoundLimit(0),
        loop.withRoundLimit(11 + random.nextInt(5)),
        loop.withRoundLimit(null),
        loop.withCondition('Not Valid '),
      ];
      final AgentConnection broken = pickOne(random, brokenLoops);

      final String? problem = describeConnectionsProblem(
        _replaceConnectionAt(workflow, loopIndex, broken),
      );

      expect(problem, isNotNull);
    }
  });

  test('test_describe_connections_problem_property_a_forward_loop_fails', () {
    final Random random = seededRandom(9705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final int? loopIndex = _findLoopIndex(workflow);
      if (loopIndex == null) {
        continue;
      }
      final AgentConnection loop = workflow.connections[loopIndex];
      final List<AgentConnection> withoutLoop = <AgentConnection>[
        for (final AgentConnection connection in workflow.connections)
          if (connection != loop && !connection.isLoop) connection,
      ];
      final AgentConnection forwardLoop = AgentConnection(
        from: loop.to,
        to: loop.from,
        condition: 'onward',
        roundLimit: 2,
      );
      final Workflow broken = workflow.withGraph(
        agents: workflow.agents,
        connections: <AgentConnection>[
          for (final AgentConnection connection in withoutLoop)
            if (!connection.joinsSameSteps(forwardLoop)) connection,
          forwardLoop,
        ],
      );

      expect(describeConnectionsProblem(broken), contains('earlier step'));
    }
  });

  test('two connections from one step cannot share an outcome', () {
    final Random random = seededRandom(9706);
    Workflow? found;
    while (found == null) {
      final Workflow candidate = randomBranchingWorkflow(random);
      final Map<WorkflowAgentId, int> outgoing = <WorkflowAgentId, int>{};
      for (final AgentConnection connection in candidate.connections) {
        outgoing[connection.from] = (outgoing[connection.from] ?? 0) + 1;
      }
      if (outgoing.values.any((int count) => count > 1)) {
        found = candidate;
      }
    }
    final Workflow workflow = found;
    final List<AgentConnection> sharing = <AgentConnection>[
      for (final AgentConnection connection in workflow.connections)
        connection.withCondition('same'),
    ];

    final String? problem = describeConnectionsProblem(
      workflow.withGraph(agents: workflow.agents, connections: sharing),
    );

    expect(problem, contains('share the outcome same'));
  });
}
