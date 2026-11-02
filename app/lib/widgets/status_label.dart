import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

enum StatusTone {
  normal(AppColors.ink, FontWeight.w400),
  muted(AppColors.inkMuted, FontWeight.w400),
  attention(AppColors.attention, FontWeight.w700),
  danger(AppColors.danger, FontWeight.w700);

  const StatusTone(this.color, this.weight);

  final Color color;
  final FontWeight weight;
}

class StatusLabel extends StatelessWidget {
  const StatusLabel({
    required this.text,
    required this.tone,
    super.key,
    this.icon,
  });

  final String text;
  final StatusTone tone;
  final AppIconKind? icon;

  @override
  Widget build(BuildContext context) {
    final AppIconKind? iconKind = icon;
    final TextStyle style = AppTextStyles.small.copyWith(
      color: tone.color,
      fontWeight: tone.weight,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (iconKind != null)
          AppIcon(iconKind, size: AppIconSize.small, color: tone.color),
        if (iconKind != null) const SizedBox(width: AppSpacing.space1),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
