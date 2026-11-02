import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

const double _fieldVerticalPadding =
    (AppSizes.controlHeight -
        AppFontSizes.body * AppLineHeights.body -
        AppBorders.thin * 2) /
    2;

class SelectField<T> extends StatelessWidget {
  const SelectField({
    required this.value,
    required this.entries,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<SelectEntry<T>> entries;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = DefaultTextStyle.of(context).style
        .merge(AppTextStyles.body);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: _fieldVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.raised,
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Padding(
            padding: EdgeInsets.only(left: AppSpacing.space4),
            child: AppIcon(AppIconKind.chevronDown, color: AppColors.inkMuted),
          ),
          dropdownColor: AppColors.raised,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          style: valueStyle,
          items: <DropdownMenuItem<T>>[
            for (final SelectEntry<T> entry in entries) _buildItem(entry),
          ],
          selectedItemBuilder: _buildSelectedItems,
          onChanged: _handleChanged,
        ),
      ),
    );
  }

  DropdownMenuItem<T> _buildItem(SelectEntry<T> entry) {
    switch (entry) {
      case SelectGroupHeading<T>(:final String label):
        return DropdownMenuItem<T>(
          enabled: false,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case SelectOption<T>():
        final bool isSelected = entry.value == value;
        return DropdownMenuItem<T>(
          value: entry.value,
          enabled: entry.isEnabled,
          child: Text(
            entry.label,
            style: AppTextStyles.body.copyWith(
              color: entry.isEnabled ? AppColors.ink : AppColors.inkMuted,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        );
    }
  }

  List<Widget> _buildSelectedItems(BuildContext context) {
    return <Widget>[
      for (final SelectEntry<T> entry in entries)
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            entry is SelectOption<T> ? entry.label : '',
            style: AppTextStyles.body,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
  }

  void _handleChanged(T? nextValue) {
    if (nextValue != null) {
      onChanged(nextValue);
    }
  }
}
