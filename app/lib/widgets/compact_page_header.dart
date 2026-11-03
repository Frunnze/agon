import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

const double compactHeaderSingleRowMinimumWidth = 640;

class CompactPageHeader extends StatelessWidget {
  const CompactPageHeader({
    required this.title,
    required this.summary,
    required this.backLink,
    required this.actions,
    super.key,
  });

  final String title;
  final String summary;
  final BackLink backLink;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildHeader);
  }

  Widget _buildHeader(BuildContext context, BoxConstraints limits) {
    if (limits.maxWidth < compactHeaderSingleRowMinimumWidth) {
      return PageHeader(
        title: title,
        summary: <TextSegment>[TextSegment(summary)],
        backLink: backLink,
        actions: actions,
      );
    }

    final Widget heading = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        BackLinkButton(link: backLink),
        const SizedBox(width: AppSpacing.space4),
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.pageTitle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Flexible(
          child: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMuted,
          ),
        ),
      ],
    );

    return Row(
      children: <Widget>[
        Expanded(child: heading),
        const SizedBox(width: AppSpacing.space4),
        Wrap(spacing: AppSpacing.space2, children: actions),
      ],
    );
  }
}
