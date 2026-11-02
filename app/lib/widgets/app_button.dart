import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

const double _pressedFillDarkening = 0.1;
const Color _darkeningColor = Color(0xFF000000);

enum ButtonTone {
  secondary(AppColors.raised, AppColors.lineStrong, AppColors.ink),
  primary(AppColors.actionFill, AppColors.actionFill, AppColors.onFill),
  danger(AppColors.dangerFill, AppColors.dangerFill, AppColors.onFill);

  const ButtonTone(this.fill, this.border, this.text);

  final Color fill;
  final Color border;
  final Color text;

  Color get hoverFill {
    if (this == ButtonTone.secondary) {
      return AppColors.sunken;
    }
    return Color.lerp(fill, _darkeningColor, _pressedFillDarkening)!;
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    required this.tone,
    super.key,
    this.icon,
  });

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  }) : tone = ButtonTone.secondary;

  const AppButton.primary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  }) : tone = ButtonTone.primary;

  const AppButton.danger({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  }) : tone = ButtonTone.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppIconKind? icon;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final double minimumHeight = LayoutSize.of(context).isLarge
        ? AppSizes.controlHeightCompact
        : AppSizes.controlHeight;
    final AppIconKind? iconKind = icon;
    final TextStyle labelStyle = DefaultTextStyle.of(context).style
        .merge(AppTextStyles.bodyBold);
    final ButtonStyle style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(0, minimumHeight)),
      padding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.space4 + AppBorders.thin,
          vertical: AppSpacing.space2 + AppBorders.thin,
        ),
      ),
      backgroundColor: WidgetStateProperty<Color>.fromMap(
        <WidgetStatesConstraint, Color>{
          WidgetState.hovered: tone.hoverFill,
          WidgetState.any: tone.fill,
        },
      ),
      foregroundColor: WidgetStateProperty<Color>.fromMap(
        <WidgetStatesConstraint, Color>{
          WidgetState.disabled: AppColors.inkMuted,
          WidgetState.any: tone.text,
        },
      ),
      overlayColor: const WidgetStatePropertyAll<Color>(AppColors.transparent),
      side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: tone.border)),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        ),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(labelStyle),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return TextButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (iconKind != null) AppIcon(iconKind),
          if (iconKind != null) const SizedBox(width: AppSpacing.space2),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
