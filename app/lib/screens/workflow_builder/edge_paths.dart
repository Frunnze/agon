import 'dart:math';
import 'dart:ui';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const double _arrowHalfWidth = CanvasMetrics.arrowLength / 2;
const double _loopCornerRadius = AppSpacing.space2;

Path _buildCurvePath(EdgeCurve curve) {
  final Path path = Path();
  path.moveTo(curve.start.dx, curve.start.dy);
  path.cubicTo(
    curve.controlStart.dx,
    curve.controlStart.dy,
    curve.controlEnd.dx,
    curve.controlEnd.dy,
    curve.end.dx,
    curve.end.dy,
  );
  return path;
}

Offset _moveToward(Offset from, Offset toward, double distance) {
  if (distance == 0) {
    return from;
  }

  final Offset step = toward - from;
  return from + step / step.distance * distance;
}

Path _buildRoundedPath(List<Offset> corners) {
  final Path path = Path();
  path.moveTo(corners.first.dx, corners.first.dy);

  for (int i = 1; i < corners.length - 1; i += 1) {
    final Offset previous = corners[i - 1];
    final Offset corner = corners[i];
    final Offset next = corners[i + 1];
    final double shortestHalf =
        min((corner - previous).distance, (next - corner).distance) / 2;
    final double radius = min(_loopCornerRadius, shortestHalf);

    final Offset turnStart = _moveToward(corner, previous, radius);
    final Offset turnEnd = _moveToward(corner, next, radius);
    path.lineTo(turnStart.dx, turnStart.dy);
    path.quadraticBezierTo(corner.dx, corner.dy, turnEnd.dx, turnEnd.dy);
  }

  path.lineTo(corners.last.dx, corners.last.dy);
  return path;
}

Path buildEdgePath(EdgeRoute route) {
  switch (route) {
    case EdgeCurve():
      return _buildCurvePath(route);
    case LoopRoute():
      return _buildRoundedPath(route.corners);
  }
}

Path _buildArrowheadAt({required Offset tip, required Offset heading}) {
  final Offset base = tip - heading * CanvasMetrics.arrowLength;
  final Offset across = Offset(-heading.dy, heading.dx) * _arrowHalfWidth;
  final Offset baseOneSide = base + across;
  final Offset baseOtherSide = base - across;

  final Path arrowhead = Path();
  arrowhead.moveTo(tip.dx, tip.dy);
  arrowhead.lineTo(baseOneSide.dx, baseOneSide.dy);
  arrowhead.lineTo(baseOtherSide.dx, baseOtherSide.dy);
  arrowhead.close();
  return arrowhead;
}

Path buildArrowhead(EdgeRoute route) {
  switch (route) {
    case EdgeCurve():
      final double direction = route.pointsDown ? 1 : -1;
      return _buildArrowheadAt(tip: route.end, heading: Offset(0, direction));
    case LoopRoute():
      final List<Offset> corners = route.corners;
      final Offset lastStep = corners.last - corners[corners.length - 2];
      return _buildArrowheadAt(
        tip: corners.last,
        heading: lastStep / lastStep.distance,
      );
  }
}
