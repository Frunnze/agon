import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/count_badge.dart';
import 'package:agent_orchestration/widgets/selection.dart';

class BottomTabs extends StatelessWidget {
  const BottomTabs({
    required this.currentSection,
    required this.pendingApprovalCount,
    required this.onSectionSelected,
    super.key,
  });

  final AppSection currentSection;
  final int pendingApprovalCount;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final AppSection currentTab = findBottomTabFor(currentSection);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.raised,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            for (final AppSection section in bottomTabSections)
              Expanded(
                child: _BottomTab(
                  section: section,
                  selection: section == currentTab
                      ? Selection.selected
                      : Selection.unselected,
                  pendingCount: section == AppSection.approvals
                      ? pendingApprovalCount
                      : 0,
                  onSelected: onSectionSelected,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.section,
    required this.selection,
    required this.pendingCount,
    required this.onSelected,
  });

  final AppSection section;
  final Selection selection;
  final int pendingCount;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = selection.isSelected;
    final Color color = isCurrent ? AppColors.action : AppColors.inkMuted;

    return Semantics(
      selected: isCurrent,
      button: true,
      child: InkWell(
        onTap: () => onSelected(section),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (isCurrent)
              Positioned(
                top: 0,
                left: AppSpacing.space3,
                right: AppSpacing.space3,
                child: Container(
                  height: AppBorders.selected,
                  color: AppColors.action,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Center(child: AppIcon(section.icon, color: color)),
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (pendingCount > 0)
              Positioned(
                top: AppSpacing.space1,
                left: 0,
                right: 0,
                child: Row(
                  children: <Widget>[
                    const Spacer(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.space2,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CountBadge(pendingCount),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
