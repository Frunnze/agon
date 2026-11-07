import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const String _completeTask = 'Do the work';
const List<String> _ruleBreakingNames = <String>[
  '',
  'Plan',
  'write code',
  'run_tests',
  'café',
  'build, at most 3 rounds',
];

Workflow _randomCompleteWorkflow(Random random) {
  final Workflow workflow = randomBranchingWorkflow(random);
  return workflow.withGraph(
    agents: <WorkflowAgent>[
      for (final WorkflowAgent agent in workflow.agents)
        agent.copyWith(
          kind: agent.kind ?? pickOne(random, AgentKind.values),
          task: _completeTask,
        ),
    ],
    connections: workflow.connections,
  );
}

Workflow _withConnection(Workflow workflow, AgentConnection connection) {
  return workflow.withGraph(
    agents: workflow.agents,
    connections: <AgentConnection>[...workflow.connections, connection],
  );
}

void main() {
  test('test_describe_signing_problem_property_signs_complete_workflows', () {
    final Random random = seededRandom(77321);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomCompleteWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }

      final String? problem = describeSigningProblem(workflow);

      expect(problem, isNull);
    }
  });

  test('test_describe_signing_problem_property_refuses_repeated_pairs', () {
    final Random random = seededRandom(77322);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomCompleteWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final AgentConnection copied = pickOne(random, workflow.connections);
      final AgentConnection plainCopy = AgentConnection(
        from: copied.from,
        to: copied.to,
        condition: null,
        roundLimit: null,
      );

      final String? problem = describeSigningProblem(
        _withConnection(workflow, plainCopy),
      );

      expect(problem, isNotNull);
    }
  });

  test('test_describe_signing_problem_property_refuses_bad_step_names', () {
    final Random random = seededRandom(77323);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomCompleteWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent renamed = pickOne(random, workflow.agents);
      final String name = pickOne(random, _ruleBreakingNames);
      final Workflow badlyNamed = workflow.withGraph(
        agents: <WorkflowAgent>[
          for (final WorkflowAgent agent in workflow.agents)
            if (agent.id == renamed.id) agent.copyWith(name: name) else agent,
        ],
        connections: workflow.connections,
      );

      final String? problem = describeSigningProblem(badlyNamed);

      final String nameProblem = describeNameProblem(name) ?? '';
      expect(nameProblem, isNotEmpty);
      expect(problem, contains(nameProblem));
    }
  });
}
