import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

void main() {
  test('test_order_agents_property_upstream_comes_first', () {
    final Random random = seededRandom(8101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<WorkflowAgent> ordered = orderAgents(workflow);
      final List<WorkflowAgentId> orderedIds = <WorkflowAgentId>[
        for (final WorkflowAgent agent in ordered) agent.id,
      ];

      expect(orderedIds.toSet().length, workflow.agents.length);
      for (final AgentConnection connection in workflow.connections) {
        if (connection.isLoop) {
          continue;
        }
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

  test('test_find_connection_problem_property_refuses_self_and_repeats', () {
    final Random random = seededRandom(8103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final WorkflowAgent from = pickOne(random, workflow.agents);
      final WorkflowAgent to = pickOne(random, workflow.agents);
      final AgentConnection connection = AgentConnection(
        from: from.id,
        to: to.id,
        condition: null,
        roundLimit: null,
      );
      final bool isJoined = workflow.connections.any(
        (AgentConnection existing) =>
            existing.from == from.id && existing.to == to.id,
      );

      final ConnectionProblem? problem = findConnectionProblem(
        workflow,
        connection,
      );

      if (from.id == to.id) {
        expect(problem, ConnectionProblem.sameAgent);
      } else if (isJoined) {
        expect(problem, ConnectionProblem.alreadyConnected);
      } else {
        expect(problem, isNull);
      }
    }
  });

  test('test_points_back_property_matches_a_forward_path', () {
    final Random random = seededRandom(8105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      final AgentConnection connection = AgentConnection(
        from: pickOne(random, workflow.agents).id,
        to: pickOne(random, workflow.agents).id,
        condition: null,
        roundLimit: null,
      );

      expect(
        pointsBack(workflow, connection),
        hasForwardPath(workflow, from: connection.to, to: connection.from),
      );
    }
  });

  test('test_connect_agents_property_only_loops_close_a_cycle', () {
    final Random random = seededRandom(8104);

    for (int i = 0; i < propertyIterations; i += 1) {
      Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.isEmpty) {
        continue;
      }
      for (int attempt = 0; attempt < 10; attempt += 1) {
        final AgentConnection plain = AgentConnection(
          from: pickOne(random, workflow.agents).id,
          to: pickOne(random, workflow.agents).id,
          condition: null,
          roundLimit: null,
        );
        final AgentConnection loop = plain
            .withCondition(pickOne(random, sampleOutcomes))
            .withRoundLimit(1 + random.nextInt(mostRoundsInATest));
        if (findConnectionProblem(workflow, plain) != null) {
          expect(() => connectAgents(workflow, plain), throwsArgumentError);
          continue;
        }

        final bool isBackward = pointsBack(workflow, plain);
        final AgentConnection accepted = isBackward ? loop : plain;
        final AgentConnection refused = isBackward ? plain : loop;
        expect(() => connectAgents(workflow, refused), throwsArgumentError);
        workflow = connectAgents(workflow, accepted);
        expect(workflow.connections, contains(accepted));
      }

      for (final AgentConnection connection in workflow.connections) {
        final bool closesCycle = hasForwardPath(
          workflow,
          from: connection.to,
          to: connection.from,
        );
        expect(closesCycle, connection.isLoop);
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
          condition: null,
          roundLimit: null,
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
    expect(
      ConnectionProblem.alreadyConnected.message,
      'These steps are already connected',
    );
  });
}
