import 'dart:ui';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

const double edgeHitDistance = CanvasMetrics.portHitRadius;
const double _loopBulge = CanvasMetrics.nodeWidth;
const double _loopDrop = CanvasMetrics.nodeHeight;
const int _hitSampleCount = 48;
const String _roundLimitSymbol = '≤';
const String _labelSeparator = ' · ';

enum EdgeLine { solid, dashed }

enum EdgeLook { normal, selected }

final class DiagramEdge {
  const DiagramEdge({
    required this.connection,
    required this.curve,
    required this.label,
    required this.line,
    required this.look,
  });

  final AgentConnection connection;
  final EdgeCurve curve;
  final String? label;
  final EdgeLine line;
  final EdgeLook look;
}

EdgeCurve buildLoopCurve({
  required CanvasPosition from,
  required CanvasPosition to,
}) {
  final Offset start = findOutputPort(from)
      .translate(0, CanvasMetrics.portRadius);
  final Offset end = findInputPort(to)
      .translate(0, -(CanvasMetrics.portRadius + CanvasMetrics.arrowGap));

  return EdgeCurve(
    start: start,
    controlStart: start.translate(_loopBulge, _loopDrop),
    controlEnd: end.translate(_loopBulge, -_loopDrop),
    end: end,
  );
}

Offset findCurvePoint(EdgeCurve curve, double progress) {
  final double rest = 1 - progress;
  final double startWeight = rest * rest * rest;
  final double controlStartWeight = 3 * rest * rest * progress;
  final double controlEndWeight = 3 * rest * progress * progress;
  final double endWeight = progress * progress * progress;

  return curve.start * startWeight +
      curve.controlStart * controlStartWeight +
      curve.controlEnd * controlEndWeight +
      curve.end * endWeight;
}

String? describeConnectionLabel(AgentConnection connection) {
  final String? condition = connection.condition;
  final int? roundLimit = connection.roundLimit;
  if (roundLimit == null) {
    return condition;
  }

  final String limit = '$_roundLimitSymbol $roundLimit';
  if (condition == null) {
    return limit;
  }
  return '$condition$_labelSeparator$limit';
}

DiagramEdge _describeEdge({
  required AgentConnection connection,
  required Map<WorkflowAgentId, CanvasPosition> positions,
  required EdgeLine line,
  required EdgeLook look,
}) {
  final CanvasPosition? from = positions[connection.from];
  final CanvasPosition? to = positions[connection.to];
  if (from == null || to == null) {
    throw StateError('A connection points to an agent that is not drawn');
  }

  final EdgeCurve curve = line == EdgeLine.dashed
      ? buildLoopCurve(from: from, to: to)
      : buildEdgeCurve(from: from, to: to);
  return DiagramEdge(
    connection: connection,
    curve: curve,
    label: describeConnectionLabel(connection),
    line: line,
    look: look,
  );
}

List<DiagramEdge> describeDiagramEdges({
  required List<WorkflowAgent> agents,
  required List<AgentConnection> connections,
  required AgentConnection? selected,
  required AgentConnection? drawnLoop,
}) {
  final Map<WorkflowAgentId, CanvasPosition> positions =
      <WorkflowAgentId, CanvasPosition>{
        for (final WorkflowAgent agent in agents) agent.id: agent.position,
      };
  final List<DiagramEdge> edges = <DiagramEdge>[];

  for (final AgentConnection connection in connections) {
    final bool isSelected =
        selected != null && selected.joinsSameSteps(connection);
    edges.add(
      _describeEdge(
        connection: connection,
        positions: positions,
        line: connection.isLoop ? EdgeLine.dashed : EdgeLine.solid,
        look: isSelected ? EdgeLook.selected : EdgeLook.normal,
      ),
    );
  }

  if (drawnLoop != null) {
    edges.add(
      _describeEdge(
        connection: drawnLoop,
        positions: positions,
        line: EdgeLine.dashed,
        look: EdgeLook.selected,
      ),
    );
  }
  return edges;
}

double _measureDistanceToCurve(EdgeCurve curve, Offset point) {
  double nearest = double.infinity;
  for (int sample = 0; sample <= _hitSampleCount; sample += 1) {
    final Offset onCurve = findCurvePoint(curve, sample / _hitSampleCount);
    final double distance = (onCurve - point).distance;
    if (distance < nearest) {
      nearest = distance;
    }
  }
  return nearest;
}

DiagramEdge? findEdgeHit(List<DiagramEdge> edges, Offset point) {
  DiagramEdge? nearestEdge;
  double nearestDistance = edgeHitDistance;

  for (final DiagramEdge edge in edges) {
    final double distance = _measureDistanceToCurve(edge.curve, point);
    if (distance <= nearestDistance) {
      nearestEdge = edge;
      nearestDistance = distance;
    }
  }
  return nearestEdge;
}
