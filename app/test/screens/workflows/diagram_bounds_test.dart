import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const double _tolerance = 1e-6;

final class _DrawnDiagram {
  const _DrawnDiagram({required this.positions, required this.edges});

  final List<CanvasPosition> positions;
  final List<DiagramEdge> edges;

  List<Offset> findLoopPoints() {
    final List<Offset> loopPoints = <Offset>[];
    for (final DiagramEdge edge in edges) {
      final EdgeRoute route = edge.route;
      if (route is LoopRoute) {
        loopPoints.addAll(route.corners);
        loopPoints.add(route.labelArea.topLeft);
        loopPoints.add(route.labelArea.bottomRight);
      }
    }
    return loopPoints;
  }
}

_DrawnDiagram _randomDrawnDiagram(Random random) {
  final Workflow workflow = randomBranchingWorkflow(random);

  return _DrawnDiagram(
    positions: <CanvasPosition>[
      for (final WorkflowAgent agent in workflow.agents) agent.position,
    ],
    edges: describeDiagramEdges(
      agents: workflow.agents,
      connections: workflow.connections,
      selected: null,
      drawnLoop: null,
    ),
  );
}

void main() {
  test('test_find_diagram_bounds_property_holds_steps_loops_and_labels', () {
    final Random random = seededRandom(9921);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _DrawnDiagram diagram = _randomDrawnDiagram(random);

      final Rect bounds = findDiagramBounds(
        positions: diagram.positions,
        edges: diagram.edges,
      );

      final Rect nodesBounds = findNodesBounds(diagram.positions);
      final Rect allowed = bounds.inflate(_tolerance);
      expect(allowed.expandToInclude(nodesBounds), allowed);
      for (final Offset point in diagram.findLoopPoints()) {
        expect(allowed.contains(point), isTrue, reason: '$point');
      }
    }
  });

  test('test_measure_canvas_property_reaches_past_every_loop', () {
    final Random random = seededRandom(9922);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _DrawnDiagram diagram = _randomDrawnDiagram(random);
      final Rect bounds = findDiagramBounds(
        positions: diagram.positions,
        edges: diagram.edges,
      );

      final Size size = measureCanvas(bounds);

      for (final Offset point in diagram.findLoopPoints()) {
        expect(point.dx, lessThan(size.width));
        expect(point.dy, lessThan(size.height));
      }
    }
  });
}
