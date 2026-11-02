import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

class StackedListRow extends StatelessWidget {
  const StackedListRow({required this.row, super.key});

  final ListRowData row;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: row.onTap,
      child: Container(
        decoration: buildRowDecoration(row.emphasis),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space3 + AppBorders.selected,
          AppSpacing.space3,
          AppSpacing.space3,
          AppSpacing.space3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LayoutBuilder(builder: _buildMainAndEnd),
            if (row.meta.isNotEmpty) const SizedBox(height: AppSpacing.space1),
            if (row.meta.isNotEmpty)
              DefaultTextStyle.merge(
                style: AppTextStyles.smallMuted,
                child: Wrap(
                  spacing: AppSpacing.space4,
                  runSpacing: AppSpacing.space1,
                  children: row.meta,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainAndEnd(BuildContext context, BoxConstraints constraints) {
    final Widget? end = row.end;
    if (end == null) {
      return row.main;
    }

    final double widestEnd = constraints.maxWidth / 2;
    return Row(
      children: <Widget>[
        Expanded(child: row.main),
        const SizedBox(width: AppSpacing.space4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widestEnd),
          child: end,
        ),
      ],
    );
  }
}
