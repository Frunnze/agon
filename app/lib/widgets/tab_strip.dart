import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/selection.dart';

class TabStrip extends StatelessWidget {
  const TabStrip({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final Widget tabs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: spaceHorizontally(<Widget>[
          for (int index = 0; index < labels.length; index += 1)
            _TabButton(
              label: labels[index],
              selection: index == selectedIndex
                  ? Selection.selected
                  : Selection.unselected,
              onPressed: () => onSelected(index),
            ),
        ], AppSpacing.space5),
      ),
    );

    return Stack(
      children: <Widget>[
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ColoredBox(
            color: AppColors.line,
            child: SizedBox(height: AppBorders.thin),
          ),
        ),
        tabs,
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selection,
    required this.onPressed,
  });

  final String label;
  final Selection selection;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final LayoutDensity layoutDensity = LayoutDensity.of(context);
    final double controlHeight = AppSizes.controlHeightFor(layoutDensity);

    final bool isSelected = selection.isSelected;

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onPressed,
        hoverColor: AppColors.transparent,
        child: Container(
          constraints: BoxConstraints(minHeight: controlHeight),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.action : AppColors.transparent,
                width: AppBorders.selected,
              ),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyBold.copyWith(
              color: isSelected ? AppColors.ink : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
