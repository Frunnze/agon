import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

class ListRowMain extends StatelessWidget {
  const ListRowMain({
    required this.title,
    super.key,
    this.subtitle = const <TextSegment>[],
  }) : titleFace = TextFace.body;

  const ListRowMain.monospace({
    required this.title,
    super.key,
    this.subtitle = const <TextSegment>[],
  }) : titleFace = TextFace.monospace;

  final String title;
  final TextFace titleFace;
  final List<TextSegment> subtitle;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = titleFace == TextFace.monospace
        ? AppTextStyles.bodyBold.merge(AppTextStyles.monospace)
        : AppTextStyles.bodyBold;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: titleStyle),
        if (subtitle.isNotEmpty) const SizedBox(height: AppSpacing.space1),
        if (subtitle.isNotEmpty)
          MixedText(subtitle, style: AppTextStyles.smallMuted),
      ],
    );
  }
}

class RowAction extends StatelessWidget {
  const RowAction({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final String? actionLabel = label;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (actionLabel != null)
          Text(
            actionLabel,
            style: AppTextStyles.bodyBold.copyWith(color: AppColors.action),
          ),
        if (actionLabel != null) const SizedBox(width: AppSpacing.space1),
        const AppIcon(
          AppIconKind.chevronRight,
          size: AppIconSize.small,
          color: AppColors.action,
        ),
      ],
    );
  }
}
