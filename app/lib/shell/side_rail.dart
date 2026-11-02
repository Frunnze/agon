import 'package:flutter/material.dart';

import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/rail_link.dart';
import 'package:agent_orchestration/shell/rail_workspace_header.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/selection.dart';

class SideRail extends StatelessWidget {
  const SideRail({
    required this.workspaceName,
    required this.deviceSummary,
    required this.currentSection,
    required this.pendingApprovalCount,
    required this.onSectionSelected,
    required this.onWorkspacePressed,
    super.key,
  });

  final String workspaceName;
  final String deviceSummary;
  final AppSection currentSection;
  final int pendingApprovalCount;
  final ValueChanged<AppSection> onSectionSelected;
  final VoidCallback onWorkspacePressed;

  @override
  Widget build(BuildContext context) {
    final double width = LayoutSize.of(context).isLarge
        ? AppSizes.railWidthLarge
        : AppSizes.railWidth;

    return Semantics(
      label: 'Main',
      container: true,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space4,
        ),
        decoration: const BoxDecoration(
          color: AppColors.raised,
          border: Border(right: BorderSide(color: AppColors.line)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              RailWorkspaceHeader(
                workspaceName: workspaceName,
                deviceSummary: deviceSummary,
                onPressed: onWorkspacePressed,
              ),
              const SizedBox(height: AppSpacing.space3),
              ...spaceVertically(<Widget>[
                for (final AppSection section in railSections)
                  RailLink(
                    section: section,
                    selection: section == currentSection
                        ? Selection.selected
                        : Selection.unselected,
                    pendingCount: section == AppSection.approvals
                        ? pendingApprovalCount
                        : 0,
                    onSelected: onSectionSelected,
                  ),
              ], AppSpacing.space1),
            ],
          ),
        ),
      ),
    );
  }
}
