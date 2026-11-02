import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/quiet_link_style.dart';

final class BackLink {
  const BackLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    super.key,
    this.summary = const <TextSegment>[],
    this.backLink,
    this.breadcrumb,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<TextSegment> summary;
  final BackLink? backLink;
  final Widget? breadcrumb;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final BackLink? link = backLink;
    final Widget? path = breadcrumb;
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (link != null) BackLinkButton(link: link),
        if (link != null) const SizedBox(height: AppSpacing.space1),
        ?path,
        if (path != null) const SizedBox(height: AppSpacing.space1),
        Semantics(
          header: true,
          child: Text(title, style: AppTextStyles.pageTitle),
        ),
        if (summary.isNotEmpty) const SizedBox(height: AppSpacing.space1),
        if (summary.isNotEmpty)
          MixedText(
            summary,
            style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
          ),
      ],
    );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: AppSpacing.space4,
      runSpacing: AppSpacing.space3,
      children: <Widget>[
        heading,
        if (actions.isNotEmpty)
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: actions,
          ),
      ],
    );
  }
}

class BackLinkButton extends StatelessWidget {
  const BackLinkButton({required this.link, super.key});

  final BackLink link;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: link.onPressed,
      style: buildQuietLinkStyle(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const AppIcon(AppIconKind.chevronLeft, size: AppIconSize.small),
          const SizedBox(width: AppSpacing.space1),
          Flexible(child: Text(link.label)),
        ],
      ),
    );
  }
}
