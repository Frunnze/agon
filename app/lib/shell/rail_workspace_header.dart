import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

class RailWorkspaceHeader extends StatelessWidget {
  const RailWorkspaceHeader({
    required this.workspaceName,
    required this.deviceSummary,
    required this.onPressed,
    super.key,
  });

  final String workspaceName;
  final String deviceSummary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(workspaceName, style: AppTextStyles.displayHeading),
                  Text(
                    deviceSummary,
                    style: AppTextStyles.caption
                        .merge(AppTextStyles.monospace)
                        .copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            const AppIcon(AppIconKind.chevronDown),
          ],
        ),
      ),
    );
  }
}
