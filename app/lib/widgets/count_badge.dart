import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const double _badgeExtent = AppSpacing.space4 + AppSpacing.space1;

class CountBadge extends StatelessWidget {
  CountBadge(this.count, {super.key}) {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'Badges count from one');
    }
  }

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: _badgeExtent,
        minHeight: _badgeExtent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.attention,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.paper,
          fontSize: AppFontSizes.caption,
          fontWeight: FontWeight.w700,
          height: 1,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
