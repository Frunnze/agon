import 'dart:ui';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

Rect findDiagramBounds({
  required List<CanvasPosition> positions,
  required List<DiagramEdge> edges,
}) {
  Rect bounds = findNodesBounds(positions);

  for (final DiagramEdge edge in edges) {
    final EdgeRoute route = edge.route;
    if (route is! LoopRoute) {
      continue;
    }
    bounds = bounds.expandToInclude(route.labelArea);
    for (final Offset corner in route.corners) {
      bounds = bounds.expandToInclude(Rect.fromPoints(corner, corner));
    }
  }

  return bounds;
}
