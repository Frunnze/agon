import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

ButtonStyle buildQuietLinkStyle(BuildContext context) {
  final TextStyle labelStyle = DefaultTextStyle.of(context).style
      .merge(AppTextStyles.small);
  final TextStyle hoveredLabelStyle = labelStyle.copyWith(
    decoration: TextDecoration.underline,
  );

  return ButtonStyle(
    padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size(0, AppSpacing.space5),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    mouseCursor: WidgetStateMouseCursor.clickable,
    overlayColor: const WidgetStatePropertyAll<Color>(AppColors.transparent),
    foregroundColor: const WidgetStateProperty<Color>.fromMap(
      <WidgetStatesConstraint, Color>{
        WidgetState.hovered: AppColors.ink,
        WidgetState.any: AppColors.inkMuted,
      },
    ),
    textStyle: WidgetStateProperty<TextStyle>.fromMap(
      <WidgetStatesConstraint, TextStyle>{
        WidgetState.hovered: hoveredLabelStyle,
        WidgetState.any: labelStyle,
      },
    ),
  );
}
