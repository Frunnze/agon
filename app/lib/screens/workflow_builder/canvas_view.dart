import 'dart:math';
import 'dart:ui';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

abstract final class CanvasZoom {
  static const double smallestScale = 0.25;
  static const double largestScale = 2;
  static const double largestFitScale = 1;
  static const double buttonStep = 0.25;
  static const double fitMargin = AppSpacing.space5;
}

final class CanvasView {
  const CanvasView({required this.scale, required this.offset});

  final double scale;
  final Offset offset;

  Offset findCanvasPoint(Offset viewportPoint) {
    return (viewportPoint - offset) / scale;
  }

  Offset findViewportPoint(Offset canvasPoint) {
    return canvasPoint * scale + offset;
  }
}

const CanvasView startingCanvasView = CanvasView(
  scale: 1,
  offset: Offset(AppSpacing.space5, AppSpacing.space5),
);

CanvasView zoomCanvasView({
  required CanvasView view,
  required Offset focus,
  required double scale,
}) {
  final double allowedScale = clampDouble(
    scale,
    CanvasZoom.smallestScale,
    CanvasZoom.largestScale,
  );
  final Offset canvasFocus = view.findCanvasPoint(focus);

  return CanvasView(
    scale: allowedScale,
    offset: focus - canvasFocus * allowedScale,
  );
}

CanvasView panCanvasView({required CanvasView view, required Offset delta}) {
  return CanvasView(scale: view.scale, offset: view.offset + delta);
}

CanvasView fitCanvasView({
  required List<CanvasPosition> positions,
  required Size viewport,
}) {
  final Rect nodesBounds = findNodesBounds(positions);
  final Rect withMargin = nodesBounds.inflate(CanvasZoom.fitMargin);
  final double fittingScale = min(
    viewport.width / withMargin.width,
    viewport.height / withMargin.height,
  );
  final double scale = clampDouble(
    fittingScale,
    CanvasZoom.smallestScale,
    CanvasZoom.largestFitScale,
  );

  final Offset viewportCentre = viewport.center(Offset.zero);
  return CanvasView(
    scale: scale,
    offset: viewportCentre - nodesBounds.center * scale,
  );
}
