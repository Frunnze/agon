import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

const double _trackWidth = AppSpacing.space6 + AppSpacing.space3;
const double _trackHeight = AppSpacing.space5;
const double _knobExtent = AppSpacing.space4;
const double _knobOffInset = AppSpacing.space1 - AppBorders.thin;
const double _knobTravel = AppSpacing.space5 - AppSpacing.space1;
const double _disabledOpacity = 0.5;
const double _enabledOpacity = 1;

class SwitchField extends StatelessWidget {
  const SwitchField({
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
    return _SwitchTapArea(
      semanticLabel: label,
      value: value,
      onChanged: onChanged,
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppTextStyles.bodyBold)),
          const SizedBox(width: AppSpacing.space3),
          _SwitchTrack(isOn: value),
        ],
      ),
    );
  }
}

class SwitchToggle extends StatelessWidget {
  const SwitchToggle({
    required this.semanticLabel,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String semanticLabel;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _SwitchTapArea(
      semanticLabel: semanticLabel,
      value: value,
      onChanged: onChanged,
      child: _SwitchTrack(isOn: value),
    );
  }
}

class _SwitchTapArea extends StatelessWidget {
  const _SwitchTapArea({
    required this.semanticLabel,
    required this.value,
    required this.onChanged,
    required this.child,
  });

  final String semanticLabel;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final LayoutDensity layoutDensity = LayoutDensity.of(context);
    final double controlHeight = AppSizes.controlHeightFor(layoutDensity);

    final ValueChanged<bool>? reportChange = onChanged;
    final VoidCallback? toggle = reportChange == null
        ? null
        : () => reportChange(!value);

    return Semantics(
      label: semanticLabel,
      toggled: value,
      button: true,
      enabled: toggle != null,
      excludeSemantics: true,
      onTap: toggle,
      child: InkWell(
        onTap: toggle,
        mouseCursor: WidgetStateMouseCursor.clickable,
        hoverColor: AppColors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: controlHeight),
          child: Opacity(
            opacity: toggle == null ? _disabledOpacity : _enabledOpacity,
            child: Align(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

class _SwitchTrack extends StatelessWidget {
  const _SwitchTrack({required this.isOn});

  final bool isOn;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.micro,
      width: _trackWidth,
      height: _trackHeight,
      decoration: BoxDecoration(
        color: isOn ? AppColors.actionFill : AppColors.sunken,
        border: Border.all(
          color: isOn ? AppColors.actionFill : AppColors.lineStrong,
        ),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedPositioned(
            duration: AppDurations.micro,
            left: isOn ? _knobOffInset + _knobTravel : _knobOffInset,
            top: (_trackHeight - _knobExtent) / 2 - AppBorders.thin,
            child: Container(
              width: _knobExtent,
              height: _knobExtent,
              decoration: BoxDecoration(
                color: isOn ? AppColors.onFill : AppColors.inkMuted,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
