import 'dart:math';
import 'dart:ui';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const double _labelClearance = AppSpacing.space4;
const double _sideStub = AppSpacing.space4;
const double _rowEscape = AppSpacing.space5;

bool _isLegClear({
  required Offset sidePoint,
  required double outerHorizontal,
  required Rect end,
  required List<Rect> nodes,
}) {
  for (final Rect node in nodes) {
    final bool isOwnStep = node == end;
    final bool sharesLegRow =
        node.top < sidePoint.dy && sidePoint.dy < node.bottom;
    final bool reachesLeg =
        node.left < outerHorizontal && sidePoint.dx < node.right;
    if (!isOwnStep && sharesLegRow && reachesLeg) {
      return false;
    }
  }
  return true;
}

List<Offset> _routeLeg({
  required Offset sidePoint,
  required Rect end,
  required double outerHorizontal,
  required double escapeVertical,
  required List<Rect> nodes,
}) {
  final bool isClear = _isLegClear(
    sidePoint: sidePoint,
    outerHorizontal: outerHorizontal,
    end: end,
    nodes: nodes,
  );
  if (isClear) {
    return <Offset>[sidePoint, Offset(outerHorizontal, sidePoint.dy)];
  }

  final double stubHorizontal = sidePoint.dx + _sideStub;
  return <Offset>[
    sidePoint,
    Offset(stubHorizontal, sidePoint.dy),
    Offset(stubHorizontal, escapeVertical),
    Offset(outerHorizontal, escapeVertical),
  ];
}

double _findWidestRight({
  required List<Rect> nodes,
  required double bandTop,
  required double bandBottom,
  required double least,
}) {
  double widestRight = least;

  for (final Rect node in nodes) {
    final bool isInBand = node.top < bandBottom && bandTop < node.bottom;
    if (isInBand) {
      widestRight = max(widestRight, node.right);
    }
  }
  return widestRight;
}

LoopRoute routeLoopEdge({
  required Rect source,
  required Rect target,
  required List<Rect> nodes,
  required Size labelSize,
}) {
  final bool isSourceBelow = source.center.dy >= target.center.dy;
  final double sourceEscape = isSourceBelow
      ? source.bottom + _rowEscape
      : source.top - _rowEscape;
  final double targetEscape = isSourceBelow
      ? target.top - _rowEscape
      : target.bottom + _rowEscape;

  final double bandReach = _rowEscape + labelSize.height / 2;
  final double widestRight = _findWidestRight(
    nodes: nodes,
    bandTop: min(source.top, target.top) - bandReach,
    bandBottom: max(source.bottom, target.bottom) + bandReach,
    least: max(source.right, target.right),
  );
  final double outerHorizontal =
      widestRight + _labelClearance + labelSize.width / 2;

  final List<Offset> sourceLeg = _routeLeg(
    sidePoint: source.centerRight,
    end: source,
    outerHorizontal: outerHorizontal,
    escapeVertical: sourceEscape,
    nodes: nodes,
  );
  final List<Offset> targetLeg = _routeLeg(
    sidePoint: target.centerRight.translate(CanvasMetrics.arrowGap, 0),
    end: target,
    outerHorizontal: outerHorizontal,
    escapeVertical: targetEscape,
    nodes: nodes,
  );

  final double outerMiddle = (sourceLeg.last.dy + targetLeg.last.dy) / 2;
  return LoopRoute(
    corners: <Offset>[...sourceLeg, ...targetLeg.reversed],
    labelArea: Rect.fromCenter(
      center: Offset(outerHorizontal, outerMiddle),
      width: labelSize.width,
      height: labelSize.height,
    ),
  );
}
