import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

class CheckField extends StatelessWidget {
  const CheckField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      checked: value,
      excludeSemantics: true,
      onTap: _toggle,
      child: InkWell(
        onTap: _toggle,
        hoverColor: AppColors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.controlHeightCompact,
          ),
          child: Row(
            children: <Widget>[
              SizedBox.square(
                dimension: AppSizes.iconSmall,
                child: Checkbox(
                  value: value,
                  onChanged: _handleChanged,
                  activeColor: AppColors.action,
                  checkColor: AppColors.paper,
                  side: const BorderSide(color: AppColors.lineStrong),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle() => onChanged(!value);

  void _handleChanged(bool? nextValue) {
    if (nextValue != null) {
      onChanged(nextValue);
    }
  }
}
