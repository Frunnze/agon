import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

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
      _paintEdge(canvas, edge.route, color, edge.line);
    }

    final EdgeCurve? drawn = drawnEdge;
    if (drawn != null) {
      _paintEdge(canvas, drawn, AppColors.action, EdgeLine.solid);
    }
  }

  void _paintEdge(Canvas canvas, EdgeRoute route, Color color, EdgeLine line) {
    final Paint stroke = Paint();
    stroke.color = color;
    stroke.style = PaintingStyle.stroke;
    stroke.strokeWidth = AppBorders.selected;

    final Path path = buildEdgePath(route);
    switch (line) {
      case EdgeLine.solid:
        canvas.drawPath(path, stroke);
      case EdgeLine.dashed:
        _paintDashes(canvas, path, stroke);
    }

    final Paint fill = Paint();
    fill.color = color;
    canvas.drawPath(buildArrowhead(route), fill);
  }

  void _paintDashes(Canvas canvas, Path path, Paint stroke) {
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final Path dash = metric.extractPath(distance, distance + _dashLength);
        canvas.drawPath(dash, stroke);
        distance += _dashLength + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(DiagramEdgesPainter oldDelegate) {
    return oldDelegate.edges != edges || oldDelegate.drawnEdge != drawnEdge;
  }
}
