import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

const String _noAgentsProblem = 'Add at least one agent';
const WorkflowAgentId _unknownAgentId = WorkflowAgentId('unknown-agent');
const int _firstFreshAgentIndex = 100;
const String _twinName = 'twin';
const String _brokenName = 'Broken Name';
const String _brokenOutcome = 'Not An Outcome';

Workflow _randomWorkflowWithAgents(Random random) {
  Workflow workflow = randomBranchingWorkflow(random);
  while (workflow.agents.isEmpty) {
    workflow = randomBranchingWorkflow(random);
  }
  return workflow;
}

List<WorkflowAgent> _insertAgent(
  Random random,
  List<WorkflowAgent> agents,
  WorkflowAgent inserted,
) {
  final List<WorkflowAgent> changed = List<WorkflowAgent>.of(agents);
  changed.insert(random.nextInt(agents.length + 1), inserted);
  return changed;
}

Workflow _addConnection(
  Random random,
  Workflow workflow,
  AgentConnection added,
) {
  final List<AgentConnection> connections = List<AgentConnection>.of(
    workflow.connections,
  );
  connections.insert(random.nextInt(connections.length + 1), added);
  return workflow.withGraph(agents: workflow.agents, connections: connections);
}

AgentConnection _randomSelfConnection(Random random, WorkflowAgentId agentId) {
  final bool isLoop = random.nextBool();
  return AgentConnection(
    from: agentId,
    to: agentId,
    condition: isLoop ? pickOne(random, sampleOutcomes) : null,
    roundLimit: isLoop ? 1 + random.nextInt(mostRoundsInATest) : null,
  );
}

AgentConnection _randomUnknownEndConnection(
  Random random,
  WorkflowAgentId knownId,
) {
  final bool isUnknownSource = random.nextBool();
  return AgentConnection(
    from: isUnknownSource ? _unknownAgentId : knownId,
    to: isUnknownSource ? knownId : _unknownAgentId,
    condition: null,
    roundLimit: null,
  );
}

Workflow _randomUnconnectedWorkflow(Random random) {
  final List<AgentConnection> connections = <AgentConnection>[
    for (int i = 0; i < random.nextInt(4); i += 1)
      AgentConnection(
        from: WorkflowAgentId(randomText(random)),
        to: WorkflowAgentId(randomText(random)),
        condition: random.nextBool() ? randomText(random) : null,
        roundLimit: random.nextBool() ? random.nextInt(20) - 5 : null,
      ),
  ];
  return Workflow(
    id: const WorkflowId('workflow-without-agents'),
    name: 'empty',
    availability: const AllWorkspaces(),
    agents: const <WorkflowAgent>[],
    connections: connections,
    signature: null,
  );
}

void main() {
  test('test_describe_workflow_problem_property_refuses_no_agents', () {
    final Random random = seededRandom(52101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomUnconnectedWorkflow(random);

      expect(describeWorkflowProblem(workflow), _noAgentsProblem);
    }
  });

  test('test_describe_workflow_problem_property_refuses_a_repeated_id', () {
    final Random random = seededRandom(52102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflowWithAgents(random);
      final WorkflowAgent copied = pickOne(random, workflow.agents);
      final WorkflowAgent twin = copied.copyWith(name: _twinName);
      final Workflow repeated = workflow.withGraph(
        agents: _insertAgent(random, workflow.agents, twin),
        connections: workflow.connections,
      );

      final String? problem = describeWorkflowProblem(repeated);

      expect(problem, 'Two agents share the id ${copied.id.value}');
    }
  });

  test('test_describe_workflow_problem_property_refuses_a_repeated_name', () {
    final Random random = seededRandom(52103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflowWithAgents(random);
      final WorkflowAgent copied = pickOne(random, workflow.agents);
      final WorkflowAgent twin = randomAgent(
        random,
        _firstFreshAgentIndex,
      ).copyWith(name: copied.name);
      final Workflow repeated = workflow.withGraph(
        agents: _insertAgent(random, workflow.agents, twin),
        connections: workflow.connections,
      );

      final String? problem = describeWorkflowProblem(repeated);

      expect(problem, 'Two agents are named ${copied.name}');
    }
  });

  test('test_describe_workflow_problem_property_refuses_unknown_ends', () {
    final Random random = seededRandom(52104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflowWithAgents(random);
      final WorkflowAgent known = pickOne(random, workflow.agents);
      final Workflow broken = _addConnection(
        random,
        workflow,
        _randomUnknownEndConnection(random, known.id),
      );

      final String? problem = describeWorkflowProblem(broken);

      expect(
        problem,
        'A connection points to the unknown agent ${_unknownAgentId.value}',
      );
    }
  });

  test('test_describe_workflow_problem_property_refuses_self_connections', () {
    final Random random = seededRandom(52105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflowWithAgents(random);
      final WorkflowAgent looped = pickOne(random, workflow.agents);
      final Workflow broken = _addConnection(
        random,
        workflow,
        _randomSelfConnection(random, looped.id),
      );

      final String? problem = describeWorkflowProblem(broken);

      expect(problem, 'The agent ${looped.name} is connected to itself');
    }
  });

  test('test_describe_workflow_problem_property_repeats_before_names', () {
    final Random random = seededRandom(52106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflowWithAgents(random);
      final WorkflowAgent renamed = pickOne(random, workflow.agents);
      final List<WorkflowAgent> agents = <WorkflowAgent>[
        for (final WorkflowAgent agent in workflow.agents)
          if (agent.id == renamed.id)
            agent.copyWith(name: _brokenName)
          else
            agent,
      ];
      final WorkflowAgent twin = pickOne(
        random,
        workflow.agents,
      ).copyWith(name: _twinName);
      final Workflow broken = workflow.withGraph(
        agents: <WorkflowAgent>[...agents, twin],
        connections: workflow.connections,
      );

      final String? problem = describeWorkflowProblem(broken);

      expect(problem, startsWith('Two agents share the id '));
    }
  });

  test('test_describe_workflow_problem_property_ends_before_outcomes', () {
    final Random random = seededRandom(52107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflowWithAgents(random);
      final WorkflowAgent known = pickOne(random, workflow.agents);
      final List<AgentConnection> connections = <AgentConnection>[
        for (final AgentConnection connection in workflow.connections)
          connection.withCondition(_brokenOutcome),
        _randomUnknownEndConnection(random, known.id),
      ];
      final Workflow broken = workflow.withGraph(
        agents: workflow.agents,
        connections: connections,
      );

      final String? problem = describeWorkflowProblem(broken);

      expect(problem, startsWith('A connection points to the unknown agent'));
    }
  });

  test(
    'test_describe_workflow_problem_property_hostile_graphs_never_throw',
    () {
      final Random random = seededRandom(52108);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = _randomWorkflowWithAgents(random);
        final List<WorkflowAgentId> ends = <WorkflowAgentId>[
          for (final WorkflowAgent agent in workflow.agents) agent.id,
          _unknownAgentId,
        ];
        Workflow hostile = workflow;
        for (int added = 0; added < 1 + random.nextInt(4); added += 1) {
          final AgentConnection connection = AgentConnection(
            from: pickOne(random, ends),
            to: pickOne(random, ends),
            condition: random.nextBool() ? randomText(random) : null,
            roundLimit: random.nextBool() ? random.nextInt(20) - 5 : null,
          );
          hostile = _addConnection(random, hostile, connection);
        }
        final bool touchesUnknownAgent = hostile.connections.any(
          (AgentConnection connection) =>
              connection.from == _unknownAgentId ||
              connection.to == _unknownAgentId,
        );

        final String? problem = describeWorkflowProblem(hostile);

        if (touchesUnknownAgent) {
          expect(problem, isNotNull);
        }
      }
    },
  );
}
