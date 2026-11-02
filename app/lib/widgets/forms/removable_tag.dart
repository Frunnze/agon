import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

class RemovableTag extends StatelessWidget {
  const RemovableTag({
    required this.label,
    required this.onRemoved,
    super.key,
  });

  final String label;
  final ValueChanged<String> onRemoved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.space2),
      decoration: BoxDecoration(
        color: AppColors.actionTint,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.small.merge(AppTextStyles.monospace),
            ),
          ),
          const SizedBox(width: AppSpacing.space1),
          Semantics(
            container: true,
            button: true,
            label: 'Remove $label',
            onTap: _remove,
            excludeSemantics: true,
            child: InkWell(
              onTap: _remove,
              hoverColor: AppColors.line,
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: const SizedBox.square(
                dimension: AppSpacing.space5,
                child: Center(
                  child: AppIcon(
                    AppIconKind.close,
                    size: AppIconSize.small,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _remove() => onRemoved(label);
}
