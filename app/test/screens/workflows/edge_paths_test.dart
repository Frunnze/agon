import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const double _pixelTolerance = 1e-6;

List<EdgeRoute> _randomRoutes(Random random) {
  final Workflow workflow = randomBranchingWorkflow(random);
  final List<DiagramEdge> edges = describeDiagramEdges(
    agents: workflow.agents,
    connections: workflow.connections,
    selected: null,
    drawnLoop: null,
  );

  return <EdgeRoute>[for (final DiagramEdge edge in edges) edge.route];
}

Offset _findRouteStart(EdgeRoute route) {
  switch (route) {
    case EdgeCurve():
      return route.start;
    case LoopRoute():
      return route.corners.first;
  }
}

Offset _findRouteEnd(EdgeRoute route) {
  switch (route) {
    case EdgeCurve():
      return route.end;
    case LoopRoute():
      return route.corners.last;
  }
}

void _expectSamePoint(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, _pixelTolerance));
  expect(actual.dy, closeTo(expected.dy, _pixelTolerance));
}

void main() {
  test('test_build_edge_path_property_runs_from_start_to_end', () {
    final Random random = seededRandom(9911);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        final PathMetric line = buildEdgePath(route).computeMetrics().single;

        final Tangent first = line.getTangentForOffset(0)!;
        final Tangent last = line.getTangentForOffset(line.length)!;
        _expectSamePoint(first.position, _findRouteStart(route));
        _expectSamePoint(last.position, _findRouteEnd(route));
      }
    }
  });

  test('test_build_edge_path_property_loops_stay_inside_their_corners', () {
    final Random random = seededRandom(9912);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        if (route is! LoopRoute) {
          continue;
        }
        Rect cornersBounds = Rect.fromPoints(
          route.corners.first,
          route.corners.last,
        );
        for (final Offset corner in route.corners) {
          cornersBounds = cornersBounds.expandToInclude(
            Rect.fromPoints(corner, corner),
          );
        }

        final Rect pathBounds = buildEdgePath(route).getBounds();
        final Rect allowed = cornersBounds.inflate(_pixelTolerance);
        expect(allowed.expandToInclude(pathBounds), allowed);
      }
    }
  });

  test('test_build_arrowhead_property_points_at_the_route_end', () {
    final Random random = seededRandom(9913);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        final Rect arrowhead = buildArrowhead(route).getBounds();
        final Offset end = _findRouteEnd(route);

        expect(arrowhead.inflate(_pixelTolerance).contains(end), isTrue);
        expect(
          max(arrowhead.width, arrowhead.height),
          closeTo(CanvasMetrics.arrowLength, _pixelTolerance),
        );
        if (route is LoopRoute) {
          expect(arrowhead.left, closeTo(end.dx, _pixelTolerance));
        }
      }
    }
  });

  test('test_measure_edge_label_property_longer_text_is_never_narrower', () {
    final Random random = seededRandom(9914);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String label = randomWordPhrase(random);
      final String longer = '$label${randomWordPhrase(random)}x';

      final Size labelSize = measureEdgeLabel(label);
      final Size longerSize = measureEdgeLabel(longer);

      expect(longerSize.width, greaterThan(labelSize.width));
      expect(labelSize.width, greaterThanOrEqualTo(2 * AppSpacing.space2));
      expect(labelSize.height, greaterThan(2 * AppSpacing.space1));
    }
  });
}
