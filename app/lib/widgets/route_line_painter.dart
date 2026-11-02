import 'package:flutter/rendering.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const double _endDotRadius = 2.8;
const double _endDotInset = AppSpacing.space1;
const double _dashLength = 9;
const double _dashGap = 6;
const double _dotSpacing = AppBorders.route * 2;

enum RoutePath {
  direct(AppColors.ink),
  relay(AppColors.ink),
  broken(AppColors.danger);

  const RoutePath(this.color);

  final Color color;
}

final class RouteLinePainter extends CustomPainter {
  const RouteLinePainter({required this.path});

  final RoutePath path;

  @override
  void paint(Canvas canvas, Size size) {
    final double middle = size.height / 2;
    final Paint linePaint = Paint()
      ..color = path.color
      ..strokeWidth = AppBorders.route;
    final Paint dotPaint = Paint()..color = path.color;

    switch (path) {
      case RoutePath.direct:
        canvas.drawLine(
          Offset(0, middle),
          Offset(size.width, middle),
          linePaint,
        );
      case RoutePath.relay:
        _paintDashes(canvas, size.width, middle, linePaint);
      case RoutePath.broken:
        _paintDots(canvas, size.width, middle, dotPaint);
    }

    canvas.drawCircle(Offset(_endDotInset, middle), _endDotRadius, dotPaint);
    canvas.drawCircle(
      Offset(size.width - _endDotInset, middle),
      _endDotRadius,
      dotPaint,
    );
  }

  void _paintDashes(Canvas canvas, double width, double middle, Paint paint) {
    for (double start = 0; start < width; start += _dashLength + _dashGap) {
      final double end = start + _dashLength < width
          ? start + _dashLength
          : width;
      canvas.drawLine(Offset(start, middle), Offset(end, middle), paint);
    }
  }

  void _paintDots(Canvas canvas, double width, double middle, Paint paint) {
    for (double center = 0; center <= width; center += _dotSpacing) {
      canvas.drawCircle(Offset(center, middle), AppBorders.route / 2, paint);
    }
  }

  @override
  bool shouldRepaint(RouteLinePainter oldDelegate) {
    return oldDelegate.path != path;
  }
}
