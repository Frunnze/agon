import 'dart:math';
import 'dart:ui';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

abstract final class CanvasMetrics {
  static const double nodeWidth = 160;
  static const double nodeHeight = 88;
  static const double portExtent = AppSpacing.space3;
  static const double portRadius = portExtent / 2;
  static const double portHitRadius = AppSpacing.space4;
  static const double arrowGap = AppBorders.thin;
  static const double arrowLength = AppSpacing.space2;
  static const double endMarginHorizontal = AppSpacing.space2;
  static const double endMarginVertical = AppSpacing.space4;
}

enum PortSide { input, output }

sealed class CanvasHit {
  const CanvasHit(this.agentId);

  final WorkflowAgentId agentId;
}

final class PortHit extends CanvasHit {
  const PortHit(super.agentId, this.side);

  final PortSide side;
}

final class NodeHit extends CanvasHit {
  const NodeHit(super.agentId);
}

final class EdgeCurve {
  const EdgeCurve({
    required this.start,
    required this.controlStart,
    required this.controlEnd,
    required this.end,
  });

  final Offset start;
  final Offset controlStart;
  final Offset controlEnd;
  final Offset end;

  bool get pointsDown => end.dy >= controlEnd.dy;
}

Rect findNodeRect(CanvasPosition position) {
  return Rect.fromLTWH(
    position.horizontal,
    position.vertical,
    CanvasMetrics.nodeWidth,
    CanvasMetrics.nodeHeight,
  );
}

Offset findInputPort(CanvasPosition position) {
  return findNodeRect(position).topCenter;
}

Offset findOutputPort(CanvasPosition position) {
  return findNodeRect(position).bottomCenter;
}

Size measureCanvas(List<CanvasPosition> positions) {
  double right = 0;
  double bottom = 0;

  for (final CanvasPosition position in positions) {
    final Rect node = findNodeRect(position);
    right = max(right, node.right);
    bottom = max(bottom, node.bottom);
  }

  return Size(
    right + CanvasMetrics.endMarginHorizontal,
    bottom + CanvasMetrics.endMarginVertical,
  );
}

Size measureDrawingSurface({
  required List<CanvasPosition> positions,
  required Size viewport,
}) {
  final Size nodes = measureCanvas(positions);
  final double roomyWidth = nodes.width + CanvasMetrics.nodeWidth;
  final double roomyHeight = nodes.height + CanvasMetrics.nodeHeight;
  return Size(
    max(viewport.width, roomyWidth),
    max(viewport.height, roomyHeight),
  );
}

EdgeCurve connectPoints({required Offset start, required Offset end}) {
  final double middle = (start.dy + end.dy) / 2;

  return EdgeCurve(
    start: start,
    controlStart: Offset(start.dx, middle),
    controlEnd: Offset(end.dx, middle),
    end: end,
  );
}

EdgeCurve buildEdgeCurve({
  required CanvasPosition from,
  required CanvasPosition to,
}) {
  final Offset start = findOutputPort(from)
      .translate(0, CanvasMetrics.portRadius);
  final Offset end = findInputPort(to)
      .translate(0, -(CanvasMetrics.portRadius + CanvasMetrics.arrowGap));

  return connectPoints(start: start, end: end);
}

bool _isNearPort(Offset port, Offset point) {
  return (port - point).distance <= CanvasMetrics.portHitRadius;
}

CanvasHit? findCanvasHit(List<WorkflowAgent> agents, Offset point) {
  final List<WorkflowAgent> topFirst = agents.reversed.toList();

  for (final WorkflowAgent agent in topFirst) {
    if (_isNearPort(findOutputPort(agent.position), point)) {
      return PortHit(agent.id, PortSide.output);
    }
    if (_isNearPort(findInputPort(agent.position), point)) {
      return PortHit(agent.id, PortSide.input);
    }
  }
  for (final WorkflowAgent agent in topFirst) {
    if (findNodeRect(agent.position).contains(point)) {
      return NodeHit(agent.id);
    }
  }
  return null;
}

AgentConnection? resolveDraggedConnection({
  required PortHit start,
  required CanvasHit? end,
}) {
  if (end == null) {
    return null;
  }

  switch (start.side) {
    case PortSide.output:
      return AgentConnection(
        from: start.agentId,
        to: end.agentId,
        condition: null,
        roundLimit: null,
      );
    case PortSide.input:
      return AgentConnection(
        from: end.agentId,
        to: start.agentId,
        condition: null,
        roundLimit: null,
      );
  }
}

CanvasPosition moveCanvasPosition(CanvasPosition position, Offset delta) {
  return CanvasPosition(
    horizontal: max(0, position.horizontal + delta.dx),
    vertical: max(0, position.vertical + delta.dy),
  );
}
