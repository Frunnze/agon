import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

List<CanvasPosition> _positionsOf(List<WorkflowAgent> agents) {
  return <CanvasPosition>[
    for (final WorkflowAgent agent in agents) agent.position,
  ];
}

void main() {
  test('test_measure_canvas_property_every_node_fits_inside', () {
    final Random random = seededRandom(8801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomAgents(random);
      final Size size = measureCanvas(findNodesBounds(_positionsOf(agents)));

      for (final WorkflowAgent agent in agents) {
        final Rect node = findNodeRect(agent.position);
        expect(node.right, lessThan(size.width));
        expect(node.bottom, lessThan(size.height));
      }
    }
  });

  test('measure canvas matches the gallery feature pipeline', () {
    final List<CanvasPosition> positions = _positionsOf(
      galleryWorkflows[2].agents,
    );
    final Size size = measureCanvas(findNodesBounds(positions));

    expect(size, const Size(344, 528));
  });

  test('test_build_edge_curve_property_runs_between_the_ports', () {
    final Random random = seededRandom(8802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition from = randomCanvasPosition(random);
      final CanvasPosition to = randomCanvasPosition(random);
      final EdgeCurve curve = buildEdgeCurve(from: from, to: to);

      expect(curve.start.dx, findOutputPort(from).dx);
      expect(curve.start.dy, greaterThan(findOutputPort(from).dy));
      expect(curve.end.dx, findInputPort(to).dx);
      expect(curve.end.dy, lessThan(findInputPort(to).dy));
      expect(curve.controlStart.dx, curve.start.dx);
      expect(curve.controlEnd.dx, curve.end.dx);
      expect(curve.pointsDown, curve.end.dy >= curve.controlEnd.dy);
    }
  });

  test('build edge curve pins the gallery plan to backend arrow', () {
    final List<WorkflowAgent> agents = galleryWorkflows[2].agents;
    final EdgeCurve curve = buildEdgeCurve(
      from: agents[0].position,
      to: agents[1].position,
    );

    expect(curve.start, const Offset(172, 110));
    expect(curve.end, const Offset(88, 145));
    expect(curve.pointsDown, isTrue);
  });

  test('test_find_canvas_hit_property_node_centres_hit_their_node', () {
    final Random random = seededRandom(8803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomAgents(random);
      if (agents.isEmpty) {
        expect(findCanvasHit(agents, Offset.zero), isNull);
        continue;
      }
      final WorkflowAgent top = agents.last;
      final Offset middle = findNodeRect(top.position).center;
      final bool isNearAnyPort = agents.any(
        (WorkflowAgent agent) =>
            (findInputPort(agent.position) - middle).distance <=
                CanvasMetrics.portHitRadius ||
            (findOutputPort(agent.position) - middle).distance <=
                CanvasMetrics.portHitRadius,
      );
      final CanvasHit? centre = findCanvasHit(agents, middle);
      final CanvasHit? output = findCanvasHit(
        agents,
        findOutputPort(top.position),
      );

      if (isNearAnyPort) {
        expect(centre, isA<PortHit>());
      } else {
        expect(centre, isA<NodeHit>());
        expect(centre?.agentId, top.id);
      }
      expect(output, isA<PortHit>());
      expect((output! as PortHit).side, PortSide.output);
      expect(output.agentId, top.id);
    }
  });

  test('test_find_canvas_hit_property_far_points_miss', () {
    final Random random = seededRandom(8804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<WorkflowAgent> agents = randomAgents(random);
      final Size size = measureCanvas(findNodesBounds(_positionsOf(agents)));
      final Offset farAway = Offset(size.width + 100, size.height + 100);

      expect(findCanvasHit(agents, farAway), isNull);
    }
  });

  test('test_resolve_dragged_connection_property_output_feeds_input', () {
    final Random random = seededRandom(8805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgentId first = WorkflowAgentId('a${random.nextInt(9)}');
      final WorkflowAgentId second = WorkflowAgentId('b${random.nextInt(9)}');
      final PortSide side = pickOne(random, PortSide.values);
      final AgentConnection? connection = resolveDraggedConnection(
        start: PortHit(first, side),
        end: NodeHit(second),
      );

      if (side == PortSide.output) {
        expect(
          connection,
          AgentConnection(
            from: first,
            to: second,
            condition: null,
            roundLimit: null,
          ),
        );
      } else {
        expect(
          connection,
          AgentConnection(
            from: second,
            to: first,
            condition: null,
            roundLimit: null,
          ),
        );
      }
      expect(
        resolveDraggedConnection(start: PortHit(first, side), end: null),
        isNull,
      );
    }
  });

  test('test_move_canvas_position_property_never_negative', () {
    final Random random = seededRandom(8806);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition start = randomCanvasPosition(random);
      final Offset delta = Offset(
        random.nextDouble() * 1400 - 700,
        random.nextDouble() * 1400 - 700,
      );
      final CanvasPosition moved = moveCanvasPosition(start, delta);

      expect(moved.horizontal, greaterThanOrEqualTo(0));
      expect(moved.vertical, greaterThanOrEqualTo(0));
      if (start.horizontal + delta.dx >= 0) {
        expect(moved.horizontal, closeTo(start.horizontal + delta.dx, 1e-9));
      }
    }
  });
}
