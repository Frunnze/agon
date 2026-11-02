import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const double _chipLineHeight = AppSpacing.space5 / AppFontSizes.caption;

class LabelChip extends StatelessWidget {
  const LabelChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        label,
        style: AppTextStyles.monospace.copyWith(
          color: AppColors.ink,
          fontSize: AppFontSizes.caption,
          height: _chipLineHeight,
        ),
      ),
    );
  }
}

class ChipList extends StatelessWidget {
  const ChipList(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space1,
      runSpacing: AppSpacing.space1,
      children: <Widget>[for (final String label in labels) LabelChip(label)],
    );
  }
}
