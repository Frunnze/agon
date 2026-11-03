import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const double _arrowHalfWidth = CanvasMetrics.arrowLength / 2;
const double _dashLength = AppSpacing.space2;
const double _dashGap = AppSpacing.space1;

class DiagramEdgesPainter extends CustomPainter {
  const DiagramEdgesPainter({required this.edges, required this.drawnEdge});

  final List<DiagramEdge> edges;
  final EdgeCurve? drawnEdge;

  @override
  void paint(Canvas canvas, Size size) {
    for (final DiagramEdge edge in edges) {
      final Color color = edge.look == EdgeLook.selected
          ? AppColors.action
          : AppColors.lineStrong;
      _paintEdge(canvas, edge.curve, color, edge.line);
    }

    final EdgeCurve? drawn = drawnEdge;
    if (drawn != null) {
      _paintEdge(canvas, drawn, AppColors.action, EdgeLine.solid);
    }
  }

  void _paintEdge(Canvas canvas, EdgeCurve edge, Color color, EdgeLine line) {
    final Paint stroke = Paint();
    stroke.color = color;
    stroke.style = PaintingStyle.stroke;
    stroke.strokeWidth = AppBorders.selected;

    final Path curve = Path();
    curve.moveTo(edge.start.dx, edge.start.dy);
    curve.cubicTo(
      edge.controlStart.dx,
      edge.controlStart.dy,
      edge.controlEnd.dx,
      edge.controlEnd.dy,
      edge.end.dx,
      edge.end.dy,
    );
    switch (line) {
      case EdgeLine.solid:
        canvas.drawPath(curve, stroke);
      case EdgeLine.dashed:
        _paintDashes(canvas, curve, stroke);
    }

    final Paint fill = Paint();
    fill.color = color;
    canvas.drawPath(_buildArrowhead(edge), fill);
  }

  void _paintDashes(Canvas canvas, Path curve, Paint stroke) {
    for (final PathMetric metric in curve.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final Path dash = metric.extractPath(distance, distance + _dashLength);
        canvas.drawPath(dash, stroke);
        distance += _dashLength + _dashGap;
      }
    }
  }

  Path _buildArrowhead(EdgeCurve edge) {
    final double direction = edge.pointsDown ? 1 : -1;
    final double baseY = edge.end.dy - direction * CanvasMetrics.arrowLength;

    final Path arrowhead = Path();
    arrowhead.moveTo(edge.end.dx, edge.end.dy);
    arrowhead.lineTo(edge.end.dx - _arrowHalfWidth, baseY);
    arrowhead.lineTo(edge.end.dx + _arrowHalfWidth, baseY);
    arrowhead.close();
    return arrowhead;
  }

  @override
  bool shouldRepaint(DiagramEdgesPainter oldDelegate) {
    return oldDelegate.edges != edges || oldDelegate.drawnEdge != drawnEdge;
  }
}
