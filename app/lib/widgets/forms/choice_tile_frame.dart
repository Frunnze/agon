import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const double _tilePadding = AppSpacing.space4 + AppBorders.thin;

class ChoiceTileFrame extends StatelessWidget {
  const ChoiceTileFrame({
    required this.title,
    required this.detail,
    required this.mark,
    required this.isSelected,
    required this.onPressed,
    required this.below,
    super.key,
  });

  final String title;
  final String detail;
  final Widget mark;
  final bool isSelected;
  final VoidCallback onPressed;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final BorderRadius corners = BorderRadius.circular(AppRadii.panel);

    return Material(
      color: isSelected ? AppColors.actionTint : AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: corners,
        side: BorderSide(
          color: isSelected ? AppColors.action : AppColors.lineStrong,
          width: isSelected ? AppBorders.selected : AppBorders.thin,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: corners,
        hoverColor: AppColors.sunken,
        child: Padding(
          padding: const EdgeInsets.all(_tilePadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              mark,
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppTextStyles.bodyBold),
                    const SizedBox(height: AppSpacing.space1),
                    Text(detail, style: AppTextStyles.smallMuted),
                    ...below,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
