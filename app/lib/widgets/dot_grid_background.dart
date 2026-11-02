import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const double _tileSize = AppSpacing.space5;
const double _dotRadius = (AppBorders.thin + AppBorders.selected) / 2;

List<Offset> listDotGridCenters(Size area) {
  final int columns = (area.width / _tileSize).ceil();
  final int rows = (area.height / _tileSize).ceil();
  final List<Offset> centers = <Offset>[];

  for (int row = 0; row < rows; row += 1) {
    for (int column = 0; column < columns; column += 1) {
      final double x = column * _tileSize + _tileSize / 2;
      final double y = row * _tileSize + _tileSize / 2;
      centers.add(Offset(x, y));
    }
  }

  return centers;
}

class DotGridBackground extends StatelessWidget {
  const DotGridBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.paper,
      child: CustomPaint(painter: const _DotGridPainter(), child: child),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dotPaint = Paint()..color = AppColors.line;
    for (final Offset center in listDotGridCenters(size)) {
      canvas.drawCircle(center, _dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => false;
}
