import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const int _labelLineCount = 1;
const EdgeInsets _labelPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.space2,
  vertical: AppSpacing.space1,
);

final TextStyle _labelStyle = AppTextStyles.caption
    .merge(AppTextStyles.monospace)
    .copyWith(color: AppColors.inkMuted, inherit: false);

Size measureEdgeLabel(String label) {
  final TextPainter labelText = TextPainter(
    text: TextSpan(text: label, style: _labelStyle),
    textDirection: TextDirection.ltr,
    maxLines: _labelLineCount,
  );
  labelText.layout();
  final Size textSize = labelText.size;
  labelText.dispose();

  return _labelPadding.inflateSize(textSize);
}

class EdgeLabelBox extends StatelessWidget {
  const EdgeLabelBox({required this.label, required this.look, super.key});

  final String label;
  final EdgeLook look;

  @override
  Widget build(BuildContext context) {
    final Color border = look == EdgeLook.selected
        ? AppColors.action
        : AppColors.line;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.sunken,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Padding(
        padding: _labelPadding,
        child: Text(
          label,
          style: _labelStyle,
          maxLines: _labelLineCount,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}
