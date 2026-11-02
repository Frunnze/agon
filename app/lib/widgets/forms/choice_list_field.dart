import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const double _radioDotExtent = AppSizes.icon / 2;
const double _tilePadding = AppSpacing.space4 + AppBorders.thin;

final class ChoiceOption<T> {
  const ChoiceOption({
    required this.value,
    required this.title,
    required this.detail,
  });

  final T value;
  final String title;
  final String detail;
}

class ChoiceListField<T> extends StatelessWidget {
  const ChoiceListField({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<ChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        for (final ChoiceOption<T> option in options)
          _ChoiceTile(
            title: option.title,
            detail: option.detail,
            isSelected: option.value == selected,
            onPressed: () => onChanged(option.value),
          ),
      ], AppSpacing.space2),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.detail,
    required this.isSelected,
    required this.onPressed,
  });

  final String title;
  final String detail;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final BorderRadius corners = BorderRadius.circular(AppRadii.panel);

    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      child: Material(
        color: isSelected ? AppColors.actionTint : AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: corners,
          side: BorderSide(
            color: isSelected ? AppColors.action : AppColors.lineStrong,
            width: isSelected ? AppBorders.selected : AppBorders.thin,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: corners,
          hoverColor: AppColors.sunken,
          child: Padding(
            padding: const EdgeInsets.all(_tilePadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _RadioMark(isSelected: isSelected),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppTextStyles.bodyBold),
                      const SizedBox(height: AppSpacing.space1),
                      Text(detail, style: AppTextStyles.smallMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.icon,
      height: AppSizes.icon,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.action : AppColors.lineStrong,
          width: AppBorders.selected,
        ),
      ),
      child: isSelected
          ? Container(
              width: _radioDotExtent,
              height: _radioDotExtent,
              decoration: const BoxDecoration(
                color: AppColors.action,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
