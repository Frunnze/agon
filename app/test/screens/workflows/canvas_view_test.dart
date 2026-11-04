import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

const double _tolerance = 1e-6;
const double _largestOffset = 2000;
const double _middleShare = 0.5;
const double _largestViewportSide = 2400;
const double _scaleSpan = CanvasZoom.largestScale - CanvasZoom.smallestScale;
const double _outOfRangeScaleSpan = 4;

double _randomScale(Random random) {
  return CanvasZoom.smallestScale + random.nextDouble() * _scaleSpan;
}

Offset _randomOffset(Random random) {
  return Offset(
    (random.nextDouble() - _middleShare) * _largestOffset,
    (random.nextDouble() - _middleShare) * _largestOffset,
  );
}

CanvasView _randomView(Random random) {
  return CanvasView(
    scale: _randomScale(random),
    offset: _randomOffset(random),
  );
}

List<CanvasPosition> _randomPositions(Random random) {
  return <CanvasPosition>[
    for (final WorkflowAgent agent in randomAgents(random)) agent.position,
  ];
}

Size _randomRoomyViewport(Random random, Rect nodesBounds) {
  final Rect withMargin = nodesBounds.inflate(CanvasZoom.fitMargin);
  final double widthShare = random.nextDouble() * _scaleSpan;
  final double heightShare = random.nextDouble() * _scaleSpan;
  return Size(
    withMargin.width * (CanvasZoom.smallestScale + widthShare),
    withMargin.height * (CanvasZoom.smallestScale + heightShare),
  );
}

void _expectSamePoint(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, _tolerance));
  expect(actual.dy, closeTo(expected.dy, _tolerance));
}

void main() {
  test('test_find_canvas_point_property_round_trips_viewport_points', () {
    final Random random = seededRandom(9101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = _randomView(random);
      final Offset viewportPoint = _randomOffset(random);
      final Offset canvasPoint = _randomOffset(random);

      final Offset backOnViewport = view.findViewportPoint(
        view.findCanvasPoint(viewportPoint),
      );
      final Offset backOnCanvas = view.findCanvasPoint(
        view.findViewportPoint(canvasPoint),
      );

      _expectSamePoint(backOnViewport, viewportPoint);
      _expectSamePoint(backOnCanvas, canvasPoint);
    }
  });

  test('test_find_viewport_point_property_scales_canvas_distances', () {
    final Random random = seededRandom(9102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = _randomView(random);
      final Offset first = _randomOffset(random);
      final Offset second = _randomOffset(random);

      final double viewportDistance =
          (view.findViewportPoint(first) - view.findViewportPoint(second))
              .distance;
      final double canvasDistance = (first - second).distance;

      expect(
        viewportDistance,
        closeTo(canvasDistance * view.scale, _tolerance),
      );
    }
  });

  test('test_zoom_canvas_view_property_keeps_focus_fixed', () {
    final Random random = seededRandom(9103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = _randomView(random);
      final Offset focus = _randomOffset(random);
      final Offset canvasFocus = view.findCanvasPoint(focus);

      final CanvasView zoomed = zoomCanvasView(
        view: view,
        focus: focus,
        scale: _randomScale(random),
      );

      _expectSamePoint(zoomed.findViewportPoint(canvasFocus), focus);
    }
  });

  test('test_zoom_canvas_view_property_keeps_scale_within_limits', () {
    final Random random = seededRandom(9104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double wantedScale = random.nextDouble() * _outOfRangeScaleSpan;

      final CanvasView zoomed = zoomCanvasView(
        view: _randomView(random),
        focus: _randomOffset(random),
        scale: wantedScale,
      );

      expect(zoomed.scale, greaterThanOrEqualTo(CanvasZoom.smallestScale));
      expect(zoomed.scale, lessThanOrEqualTo(CanvasZoom.largestScale));
      final bool isWithinLimits =
          wantedScale >= CanvasZoom.smallestScale &&
          wantedScale <= CanvasZoom.largestScale;
      if (isWithinLimits) {
        expect(zoomed.scale, wantedScale);
      }
    }
  });

  test('test_pan_canvas_view_property_moves_every_point_by_delta', () {
    final Random random = seededRandom(9105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = _randomView(random);
      final Offset canvasPoint = _randomOffset(random);
      final Offset delta = _randomOffset(random);

      final CanvasView panned = panCanvasView(view: view, delta: delta);

      expect(panned.scale, view.scale);
      _expectSamePoint(
        panned.findViewportPoint(canvasPoint),
        view.findViewportPoint(canvasPoint) + delta,
      );
    }
  });

  test('test_fit_canvas_view_property_every_node_inside_viewport', () {
    final Random random = seededRandom(9106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<CanvasPosition> positions = _randomPositions(random);
      final Rect nodesBounds = findNodesBounds(positions);
      final Size viewport = _randomRoomyViewport(random, nodesBounds);

      final CanvasView fitted = fitCanvasView(
        diagramBounds: findNodesBounds(positions),
        viewport: viewport,
      );

      final Rect visible = (Offset.zero & viewport).inflate(_tolerance);
      for (final CanvasPosition position in positions) {
        final Rect node = findNodeRect(position);
        expect(visible.contains(fitted.findViewportPoint(node.topLeft)), true);
        expect(
          visible.contains(fitted.findViewportPoint(node.bottomRight)),
          true,
        );
      }
    }
  });

  test('test_fit_canvas_view_property_scale_stays_between_limits', () {
    final Random random = seededRandom(9107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Size viewport = Size(
        random.nextDouble() * _largestViewportSide,
        random.nextDouble() * _largestViewportSide,
      );

      final CanvasView fitted = fitCanvasView(
        diagramBounds: findNodesBounds(_randomPositions(random)),
        viewport: viewport,
      );

      expect(fitted.scale, greaterThanOrEqualTo(CanvasZoom.smallestScale));
      expect(fitted.scale, lessThanOrEqualTo(CanvasZoom.largestFitScale));
    }
  });

  test('test_fit_canvas_view_property_centres_the_nodes', () {
    final Random random = seededRandom(9108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<CanvasPosition> positions = _randomPositions(random);
      final Rect nodesBounds = findNodesBounds(positions);
      final Size viewport = _randomRoomyViewport(random, nodesBounds);

      final CanvasView fitted = fitCanvasView(
        diagramBounds: findNodesBounds(positions),
        viewport: viewport,
      );

      _expectSamePoint(
        fitted.findViewportPoint(nodesBounds.center),
        viewport.center(Offset.zero),
      );
    }
  });

  test('test_fit_canvas_view_property_every_loop_part_inside_viewport', () {
    final Random random = seededRandom(9110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final List<DiagramEdge> edges = describeDiagramEdges(
        agents: workflow.agents,
        connections: workflow.connections,
        selected: null,
        drawnLoop: null,
      );
      final Rect diagramBounds = findDiagramBounds(
        positions: <CanvasPosition>[
          for (final WorkflowAgent agent in workflow.agents) agent.position,
        ],
        edges: edges,
      );
      final Size viewport = _randomRoomyViewport(random, diagramBounds);

      final CanvasView fitted = fitCanvasView(
        diagramBounds: diagramBounds,
        viewport: viewport,
      );

      final Rect visible = (Offset.zero & viewport).inflate(_tolerance);
      for (final DiagramEdge edge in edges) {
        final EdgeRoute route = edge.route;
        if (route is! LoopRoute) {
          continue;
        }
        final List<Offset> loopPoints = <Offset>[
          ...route.corners,
          route.labelArea.topLeft,
          route.labelArea.bottomRight,
        ];
        for (final Offset point in loopPoints) {
          final Offset shown = fitted.findViewportPoint(point);
          expect(visible.contains(shown), isTrue, reason: '$shown');
        }
      }
    }
  });

  test('test_find_nodes_bounds_property_holds_every_node_tightly', () {
    final Random random = seededRandom(9109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<CanvasPosition> positions = _randomPositions(random);

      final Rect bounds = findNodesBounds(positions);

      Rect? union;
      for (final CanvasPosition position in positions) {
        final Rect node = findNodeRect(position);
        union = union == null ? node : union.expandToInclude(node);
      }
      expect(bounds, union ?? Rect.zero);
    }
  });
}
