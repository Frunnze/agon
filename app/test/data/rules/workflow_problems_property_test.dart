import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const List<String> _hostileStepNames = <String>[
  '',
  'Plan',
  'write code',
  'run_tests',
  'café',
  'ship\n',
  ' build',
  'a,b',
  '"quoted"',
  'build, at most 3 rounds',
  '😀',
  '\u{FF61}',
];
const String _longNameLetter = 'a';

String _randomStepName(Random random) {
  final int choice = random.nextInt(4);
  if (choice == 0) {
    return pickOne(random, _hostileStepNames);
  }
  if (choice == 1) {
    return randomText(random);
  }
  if (choice == 2) {
    final int length = nameMaximumLength - 1 + random.nextInt(3);
    return _longNameLetter * length;
  }
  return randomWordPhrase(random).replaceAll(' ', '-');
}

Workflow _renameRandomStep(Random random, Workflow workflow, String name) {
  final WorkflowAgent renamed = pickOne(random, workflow.agents);
  return workflow.withGraph(
    agents: <WorkflowAgent>[
      for (final WorkflowAgent agent in workflow.agents)
        if (agent.id == renamed.id) agent.copyWith(name: name) else agent,
    ],
    connections: workflow.connections,
  );
}

bool _hasRuleBreakingName(Workflow workflow) {
  return workflow.agents.any(
    (WorkflowAgent agent) => describeNameProblem(agent.name) != null,
  );
}

void main() {
  test('test_describe_workflow_problem_property_follows_the_name_rule', () {
    final Random random = seededRandom(77311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final String name = _randomStepName(random);
      final Workflow renamed = _renameRandomStep(random, workflow, name);

      final String? problem = describeWorkflowProblem(renamed);

      expect(describeWorkflowProblem(workflow), isNull);
      expect(problem == null, describeNameProblem(name) == null);
    }
  });

  test('test_describe_workflow_problem_property_names_the_renamed_step', () {
    final Random random = seededRandom(77312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final String name = _randomStepName(random);
      final String? nameProblem = describeNameProblem(name);
      if (workflow.agents.isEmpty || nameProblem == null) {
        continue;
      }
      final Workflow renamed = _renameRandomStep(random, workflow, name);

      final String? problem = describeWorkflowProblem(renamed);

      expect(problem, contains('"$name"'));
      expect(problem, contains(nameProblem));
    }
  });

  test(
    'test_describe_workflow_problem_property_keeps_connection_problems',
    () {
      final Random random = seededRandom(77313);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = randomBranchingWorkflow(random);
        if (workflow.connections.isEmpty) {
          continue;
        }
        final AgentConnection copied = pickOne(random, workflow.connections);
        final Workflow repeated = workflow.withGraph(
          agents: workflow.agents,
          connections: <AgentConnection>[...workflow.connections, copied],
        );

        final String? problem = describeWorkflowProblem(repeated);

        expect(_hasRuleBreakingName(repeated), isFalse);
        expect(problem, describeConnectionsProblem(repeated));
        expect(problem, isNotNull);
      }
    },
  );
}
