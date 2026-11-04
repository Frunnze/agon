import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/widgets/forms/choice_tile_frame.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

final class CheckChoiceOption<T> {
  const CheckChoiceOption({
    required this.value,
    required this.title,
    required this.detail,
    required this.problem,
  });

  final T value;
  final String title;
  final String detail;
  final String? problem;
}

class CheckChoiceListField<T> extends StatelessWidget {
  const CheckChoiceListField({
    required this.options,
    required this.selected,
    required this.onToggled,
    super.key,
  });

  final List<CheckChoiceOption<T>> options;
  final Set<T> selected;
  final ValueChanged<T> onToggled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        for (final CheckChoiceOption<T> option in options) _buildTile(option),
      ], AppSpacing.space2),
    );
  }

  Widget _buildTile(CheckChoiceOption<T> option) {
    final bool isSelected = selected.contains(option.value);
    final String? problem = option.problem;

    return Semantics(
      container: true,
      checked: isSelected,
      child: ChoiceTileFrame(
        title: option.title,
        detail: option.detail,
        mark: _CheckMark(isSelected: isSelected),
        isSelected: isSelected,
        onPressed: () => onToggled(option.value),
        below: <Widget>[
          if (problem != null) const SizedBox(height: AppSpacing.space2),
          if (problem != null)
            StatusLabel(
              text: problem,
              tone: StatusTone.attention,
              icon: AppIconKind.alert,
            ),
        ],
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSizes.iconFor(LayoutDensity.of(context)),
      child: Checkbox(
        value: isSelected,
        onChanged: null,
        fillColor: WidgetStateProperty.resolveWith(_chooseFill),
        checkColor: AppColors.paper,
        side: const BorderSide(
          color: AppColors.lineStrong,
          width: AppBorders.selected,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Color _chooseFill(Set<WidgetState> states) {
    if (isSelected) {
      return AppColors.action;
    }
    return AppColors.transparent;
  }
}
