import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

bool _hasPath(
  Workflow workflow, {
  required WorkflowAgentId from,
  required WorkflowAgentId to,
}) {
  final List<WorkflowAgentId> waiting = <WorkflowAgentId>[from];
  final Set<WorkflowAgentId> seen = <WorkflowAgentId>{};

  while (waiting.isNotEmpty) {
    final WorkflowAgentId current = waiting.removeLast();
    if (current == to) {
      return true;
    }
    if (seen.add(current)) {
      for (final AgentConnection connection in workflow.connections) {
        if (connection.from == current) {
          waiting.add(connection.to);
        }
      }
    }
  }
  return false;
}

void main() {
  test('test_order_agents_property_upstream_comes_first', () {
    final Random random = seededRandom(8101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      final List<WorkflowAgent> ordered = orderAgents(workflow);
      final List<WorkflowAgentId> orderedIds = <WorkflowAgentId>[
        for (final WorkflowAgent agent in ordered) agent.id,
      ];

      expect(orderedIds.toSet().length, workflow.agents.length);
      for (final AgentConnection connection in workflow.connections) {
        expect(
          orderedIds.indexOf(connection.from),
          lessThan(orderedIds.indexOf(connection.to)),
        );
      }
    }
  });

  test('test_order_agents_property_unconnected_agents_follow_canvas', () {
    final Random random = seededRandom(8102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random)
          .withGraph(agents: randomAgents(random), connections: const []);
      final List<WorkflowAgent> ordered = orderAgents(workflow);

      for (int index = 1; index < ordered.length; index += 1) {
        final double previous = ordered[index - 1].position.vertical;
        expect(previous, lessThanOrEqualTo(ordered[index].position.vertical));
      }
    }
  });

  test('order agents matches the gallery feature pipeline', () {
    final Workflow pipeline = galleryWorkflows[2];
    final List<String> names = <String>[
      for (final WorkflowAgent agent in orderAgents(pipeline)) agent.name,
    ];

    expect(names, <String>['plan', 'backend', 'ios', 'review', 'ship']);
  });

  test('test_find_connection_problem_property_never_allows_a_loop', () {
    final Random random = seededRandom(8103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent from = pickOne(random, workflow.agents);
      final WorkflowAgent to = pickOne(random, workflow.agents);
      final AgentConnection connection = AgentConnection(
        from: from.id,
        to: to.id,
      );
      final ConnectionProblem? problem = findConnectionProblem(
        workflow,
        connection,
      );

      if (from.id == to.id) {
        expect(problem, ConnectionProblem.sameAgent);
      } else if (workflow.connections.contains(connection)) {
        expect(problem, ConnectionProblem.alreadyConnected);
      } else if (_hasPath(workflow, from: to.id, to: from.id)) {
        expect(problem, ConnectionProblem.wouldMakeLoop);
      } else {
        expect(problem, isNull);
      }
    }
  });

  test('test_connect_agents_property_result_stays_acyclic', () {
    final Random random = seededRandom(8104);

    for (int i = 0; i < propertyIterations; i += 1) {
      Workflow workflow = randomAcyclicWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      for (int attempt = 0; attempt < 10; attempt += 1) {
        final AgentConnection connection = AgentConnection(
          from: pickOne(random, workflow.agents).id,
          to: pickOne(random, workflow.agents).id,
        );
        if (findConnectionProblem(workflow, connection) == null) {
          workflow = connectAgents(workflow, connection);
          expect(workflow.connections, contains(connection));
        } else {
          expect(
            () => connectAgents(workflow, connection),
            throwsArgumentError,
          );
        }
      }

      for (final AgentConnection connection in workflow.connections) {
        expect(
          _hasPath(workflow, from: connection.to, to: connection.from),
          isFalse,
        );
      }
    }
  });

  test('connect agents rejects agents the workflow does not have', () {
    final Workflow release = galleryWorkflows.first;

    expect(
      () => connectAgents(
        release,
        AgentConnection(
          from: release.agents.first.id,
          to: const WorkflowAgentId('missing'),
        ),
      ),
      throwsStateError,
    );
  });

  test('test_connection_problem_property_every_problem_explained', () {
    final Set<String> messages = <String>{
      for (final ConnectionProblem problem in ConnectionProblem.values)
        problem.message,
    };

    expect(messages.length, ConnectionProblem.values.length);
    expect(ConnectionProblem.wouldMakeLoop.message, 'That would make a loop');
  });
}
