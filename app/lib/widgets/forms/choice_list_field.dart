import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/widgets/forms/choice_tile_frame.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const double _radioDotShareOfMark = 0.5;

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
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      child: ChoiceTileFrame(
        title: title,
        detail: detail,
        mark: _RadioMark(isSelected: isSelected),
        isSelected: isSelected,
        onPressed: onPressed,
        below: const <Widget>[],
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final double markExtent = AppSizes.iconFor(LayoutDensity.of(context));
    final double dotExtent = markExtent * _radioDotShareOfMark;

    return Container(
      width: markExtent,
      height: markExtent,
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
              width: dotExtent,
              height: dotExtent,
              decoration: const BoxDecoration(
                color: AppColors.action,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
