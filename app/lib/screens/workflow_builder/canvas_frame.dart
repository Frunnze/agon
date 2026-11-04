import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

const double _dotSpacing = AppSpacing.space4;
const double _dotRadius = AppBorders.thin;

class CanvasFrame extends StatelessWidget {
  const CanvasFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.sunken,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        child: CustomPaint(painter: const DotGridPainter(), child: child),
      ),
    );
  }
}

class DotGridPainter extends CustomPainter {
  const DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dotPaint = Paint();
    dotPaint.color = AppColors.lineStrong;

    for (double top = _dotSpacing / 2; top < size.height; top += _dotSpacing) {
      for (
        double left = _dotSpacing / 2;
        left < size.width;
        left += _dotSpacing
      ) {
        canvas.drawCircle(Offset(left, top), _dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter oldDelegate) => false;
}
