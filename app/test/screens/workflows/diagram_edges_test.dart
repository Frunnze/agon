import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

void main() {
  test('test_describe_diagram_edges_property_one_edge_per_connection', () {
    final Random random = seededRandom(9801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final AgentConnection? selected = workflow.connections.isEmpty
          ? null
          : pickOne(random, workflow.connections);

      final List<DiagramEdge> edges = describeDiagramEdges(
        agents: workflow.agents,
        connections: workflow.connections,
        selected: selected,
        drawnLoop: null,
      );

      expect(edges.length, workflow.connections.length);
      for (final DiagramEdge edge in edges) {
        final bool isSelected =
            selected != null && edge.connection.joinsSameSteps(selected);
        expect(edge.look == EdgeLook.selected, isSelected);
        expect(edge.line == EdgeLine.dashed, edge.connection.isLoop);
      }
    }
  });

  test('test_describe_connection_label_property_names_outcome_and_rounds', () {
    final Random random = seededRandom(9802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);

      for (final AgentConnection connection in workflow.connections) {
        final String? label = describeConnectionLabel(connection);
        final String? condition = connection.condition;
        final int? roundLimit = connection.roundLimit;

        if (roundLimit != null) {
          expect(label, '$condition · ≤ $roundLimit');
        } else {
          expect(label, condition);
        }
      }
    }
  });

  test('test_describe_diagram_edges_property_a_drawn_loop_is_dashed', () {
    final Random random = seededRandom(9803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.agents.length < 2) {
        continue;
      }
      final AgentConnection drawnLoop = AgentConnection(
        from: workflow.agents.last.id,
        to: workflow.agents.first.id,
        condition: null,
        roundLimit: null,
      );

      final List<DiagramEdge> edges = describeDiagramEdges(
        agents: workflow.agents,
        connections: workflow.connections,
        selected: null,
        drawnLoop: drawnLoop,
      );

      expect(edges.length, workflow.connections.length + 1);
      expect(edges.last.connection, drawnLoop);
      expect(edges.last.line, EdgeLine.dashed);
      expect(edges.last.look, EdgeLook.selected);
    }
  });

  test('test_build_loop_curve_property_leaves_bottom_and_enters_top', () {
    final Random random = seededRandom(9804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition from = randomCanvasPosition(random);
      final CanvasPosition to = randomCanvasPosition(random);

      final EdgeCurve curve = buildLoopCurve(from: from, to: to);

      expect(curve.start.dx, findOutputPort(from).dx);
      expect(curve.start.dy, greaterThan(findOutputPort(from).dy));
      expect(curve.end.dx, findInputPort(to).dx);
      expect(curve.end.dy, lessThan(findInputPort(to).dy));
      expect(curve.pointsDown, isTrue);
      final double portsMiddle = (curve.start.dx + curve.end.dx) / 2;
      expect(findCurvePoint(curve, 0.5).dx, greaterThan(portsMiddle));
    }
  });

  test('test_find_curve_point_property_ends_are_the_curve_ends', () {
    final Random random = seededRandom(9805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = buildEdgeCurve(
        from: randomCanvasPosition(random),
        to: randomCanvasPosition(random),
      );

      expect(findCurvePoint(curve, 0), curve.start);
      expect(findCurvePoint(curve, 1), curve.end);
    }
  });

  test('test_find_edge_hit_property_points_on_an_edge_hit_an_edge', () {
    final Random random = seededRandom(9806);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final List<DiagramEdge> edges = describeDiagramEdges(
        agents: workflow.agents,
        connections: workflow.connections,
        selected: null,
        drawnLoop: null,
      );
      final DiagramEdge edge = pickOne(random, edges);
      final Offset point = findCurvePoint(edge.curve, random.nextDouble());

      expect(findEdgeHit(edges, point), isNotNull);
    }
  });

  test('test_find_edge_hit_property_far_points_miss_every_edge', () {
    final Random random = seededRandom(9807);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<DiagramEdge> edges = describeDiagramEdges(
        agents: workflow.agents,
        connections: workflow.connections,
        selected: null,
        drawnLoop: null,
      );
      final Offset farAway = Offset(-1000 - random.nextDouble() * 500, -1000);

      expect(findEdgeHit(edges, farAway), isNull);
    }
  });
}
