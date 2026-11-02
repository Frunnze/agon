import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/count_badge.dart';
import 'package:agent_orchestration/widgets/selection.dart';

class RailLink extends StatelessWidget {
  const RailLink({
    required this.section,
    required this.selection,
    required this.pendingCount,
    required this.onSelected,
    super.key,
  });

  final AppSection section;
  final Selection selection;
  final int pendingCount;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = selection.isSelected;
    final Color color = isCurrent ? AppColors.action : AppColors.inkMuted;
    final TextStyle style = AppTextStyles.body.copyWith(
      color: color,
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
    );

    return Semantics(
      selected: isCurrent,
      button: true,
      child: Material(
        color: isCurrent ? AppColors.actionTint : AppColors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          onTap: () => onSelected(section),
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.controlHeightCompact,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space3,
              vertical: AppSpacing.space2,
            ),
            child: Row(
              children: <Widget>[
                AppIcon(section.icon, color: color),
                const SizedBox(width: AppSpacing.space3),
                Expanded(child: Text(section.label, style: style)),
                if (pendingCount > 0) CountBadge(pendingCount),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
