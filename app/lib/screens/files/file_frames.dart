import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const double _checkerSquare = AppSpacing.space4 / 2;

class FileFrame extends StatelessWidget {
  const FileFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: child,
    );
  }
}

class ImageFrame extends StatelessWidget {
  const ImageFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: CustomPaint(
        painter: const _CheckerboardPainter(),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.space5),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadii.panel),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class EmptySection extends StatelessWidget {
  const EmptySection({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.measure),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: spaceVertically(<Widget>[
              Semantics(
                header: true,
                child: Text(title, style: AppTextStyles.heading),
              ),
              ...children,
            ], AppSpacing.space3),
          ),
        ),
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paperPaint = Paint()..color = AppColors.paper;
    final Paint raisedPaint = Paint()..color = AppColors.raised;
    canvas.drawRect(Offset.zero & size, paperPaint);

    final int columns = (size.width / _checkerSquare).ceil();
    final int rows = (size.height / _checkerSquare).ceil();
    for (int row = 0; row < rows; row += 1) {
      for (int column = (row + 1) % 2; column < columns; column += 2) {
        final Rect square = Rect.fromLTWH(
          column * _checkerSquare,
          row * _checkerSquare,
          _checkerSquare,
          _checkerSquare,
        );
        canvas.drawRect(square, raisedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) => false;
}
