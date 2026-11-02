import 'package:flutter/rendering.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/icons/icon_path_parser.dart';
import 'package:agent_orchestration/icons/icon_shape.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

final class AppIconPainter extends CustomPainter {
  const AppIconPainter({required this.kind, required this.color});

  final AppIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / AppSizes.iconViewBox;
    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.iconStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..save()
      ..scale(scale);
    for (final IconShape shape in kind.shapes) {
      canvas.drawPath(buildIconShapePath(shape), strokePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppIconPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

Path buildIconShapePath(IconShape shape) {
  switch (shape) {
    case IconPathShape(:final String pathData):
      return parseIconPath(pathData);
    case IconCircleShape():
      final Rect bounds = Rect.fromCircle(
        center: Offset(shape.centerHorizontal, shape.centerVertical),
        radius: shape.radius,
      );
      return Path()..addOval(bounds);
    case IconRectangleShape():
      final Rect bounds = Rect.fromLTWH(
        shape.left,
        shape.top,
        shape.width,
        shape.height,
      );
      final RRect rounded = RRect.fromRectAndRadius(
        bounds,
        Radius.circular(shape.cornerRadius),
      );
      return Path()..addRRect(rounded);
  }
}
