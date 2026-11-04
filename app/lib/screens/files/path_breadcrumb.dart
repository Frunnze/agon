import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const String _crumbSeparator = '/';
const String _breadcrumbLabel = 'Path';

class PathBreadcrumb extends StatelessWidget {
  const PathBreadcrumb({
    required this.labels,
    required this.onPressed,
    super.key,
  });

  final List<String> labels;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final TextStyle crumbStyle = AppTextStyles.small
        .merge(AppTextStyles.monospace)
        .copyWith(color: AppColors.inkMuted);
    final List<Widget> crumbs = <Widget>[];

    for (final String label in labels) {
      if (crumbs.isNotEmpty) {
        crumbs.add(
          ExcludeSemantics(child: Text(_crumbSeparator, style: crumbStyle)),
        );
      }
      crumbs.add(
        InkWell(
          onTap: onPressed,
          mouseCursor: WidgetStateMouseCursor.clickable,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.space5),
            child: Align(
              widthFactor: 1,
              child: Text(label, style: crumbStyle),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: _breadcrumbLabel,
      container: true,
      child: Wrap(
        spacing: AppSpacing.space1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: crumbs,
      ),
    );
  }
}
