import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const double _dashLength = AppSpacing.space1;
const double _portInset =
    (CanvasMetrics.nodeWidth - CanvasMetrics.portExtent) / 2;

enum NodeLook { normal, selected, pending }

final TextStyle _detailStyle = AppTextStyles.caption
    .merge(AppTextStyles.monospace)
    .copyWith(color: AppColors.inkMuted);

class AgentNodeBox extends StatelessWidget {
  const AgentNodeBox({
    required this.kindText,
    required this.name,
    required this.targetText,
    required this.look,
    super.key,
  });

  final String kindText;
  final String name;
  final String? targetText;
  final NodeLook look;

  @override
  Widget build(BuildContext context) {
    final String? target = targetText;
    final bool isSelected = look == NodeLook.selected;
    final Color nameColor = look == NodeLook.pending
        ? AppColors.inkMuted
        : AppColors.ink;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(kindText, style: _detailStyle, maxLines: 1),
          Text(
            name,
            style: AppTextStyles.bodyBold.copyWith(color: nameColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (target != null)
            Text(
              target,
              style: _detailStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );

    return Semantics(
      button: look != NodeLook.pending,
      selected: isSelected,
      label: '$name, $kindText',
      excludeSemantics: true,
      child: SizedBox(
        width: CanvasMetrics.nodeWidth,
        height: CanvasMetrics.nodeHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(child: _buildOutline(content)),
            if (look != NodeLook.pending)
              _buildPort(top: -CanvasMetrics.portRadius),
            if (look != NodeLook.pending)
              _buildPort(
                top: CanvasMetrics.nodeHeight - CanvasMetrics.portRadius,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutline(Widget content) {
    switch (look) {
      case NodeLook.normal:
        return _buildFilledOutline(
          content,
          fill: AppColors.raised,
          edge: AppColors.lineStrong,
        );
      case NodeLook.selected:
        return _buildFilledOutline(
          content,
          fill: AppColors.actionTint,
          edge: AppColors.action,
        );
      case NodeLook.pending:
        return CustomPaint(
          painter: const DashedOutlinePainter(color: AppColors.lineStrong),
          child: content,
        );
    }
  }

  Widget _buildFilledOutline(
    Widget content, {
    required Color fill,
    required Color edge,
  }) {
    final double width = look == NodeLook.selected
        ? AppBorders.selected
        : AppBorders.thin;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: edge, width: width),
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: content,
    );
  }

  Widget _buildPort({required double top}) {
    final Color edge = look == NodeLook.selected
        ? AppColors.action
        : AppColors.lineStrong;

    return Positioned(
      top: top,
      left: _portInset,
      child: Container(
        width: CanvasMetrics.portExtent,
        height: CanvasMetrics.portExtent,
        decoration: BoxDecoration(
          color: AppColors.raised,
          shape: BoxShape.circle,
          border: Border.all(color: edge, width: AppBorders.selected),
        ),
      ),
    );
  }
}

class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint();
    stroke.color = color;
    stroke.style = PaintingStyle.stroke;
    stroke.strokeWidth = AppBorders.thin;
    final Path outline = Path();
    outline.addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(AppRadii.panel),
      ),
    );

    for (final PathMetric metric in outline.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final Path dash = metric.extractPath(distance, distance + _dashLength);
        canvas.drawPath(dash, stroke);
        distance += _dashLength * 2;
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
