import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_density.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/word_safe_box.dart';

const double _rowStartInset = AppSpacing.space3 + AppBorders.selected;
const double _rowEndInset = AppSpacing.space3;
const double _columnGap = AppSpacing.space4;
const EdgeInsets _headingPadding = EdgeInsets.symmetric(
  vertical: AppSpacing.space2,
);
const EdgeInsets _denseRowPadding = EdgeInsets.symmetric(
  vertical: AppSpacing.space2,
);
const EdgeInsets _touchRowPadding = EdgeInsets.symmetric(
  vertical: AppSpacing.space3,
);

EdgeInsets _rowPaddingFor(LayoutDensity layoutDensity) {
  if (layoutDensity.isTouch) {
    return _touchRowPadding;
  }
  return _denseRowPadding;
}

enum ListHeading { shown, hidden }

class ListTable extends StatelessWidget {
  const ListTable({
    required this.columns,
    required this.rows,
    required this.heading,
    super.key,
  });

  final List<ListColumn> columns;
  final List<ListRowData> rows;
  final ListHeading heading;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets rowPadding = _rowPaddingFor(LayoutDensity.of(context));

    return Table(
      columnWidths: _buildColumnWidths(),
      defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
      children: <TableRow>[
        if (heading == ListHeading.shown) _buildHeadingRow(),
        for (final ListRowData row in rows) _buildRow(row, rowPadding),
      ],
    );
  }

  Map<int, TableColumnWidth> _buildColumnWidths() {
    final List<TableColumnWidth> widths = <TableColumnWidth>[
      const FixedColumnWidth(_rowStartInset),
    ];

    for (int index = 0; index < columns.length; index += 1) {
      if (index > 0) {
        widths.add(const FixedColumnWidth(_columnGap));
      }
      widths.add(columns[index].tableWidth);
    }

    widths.add(const FixedColumnWidth(_rowEndInset));
    return widths.asMap();
  }

  TableRow _buildHeadingRow() {
    final List<Widget> cells = <Widget>[
      for (final ListColumn column in columns)
        Padding(
          padding: _headingPadding,
          child: ExcludeSemantics(
            child: Text(column.label, style: AppTextStyles.smallMuted),
          ),
        ),
    ];

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      children: _surroundWithSpacers(cells, const SizedBox.shrink()),
    );
  }

  TableRow _buildRow(ListRowData row, EdgeInsets rowPadding) {
    final List<Widget> cells = <Widget>[
      row.main,
      for (final Widget meta in row.meta)
        DefaultTextStyle.merge(style: AppTextStyles.smallMuted, child: meta),
      row.end ?? const SizedBox.shrink(),
    ];
    if (cells.length != columns.length) {
      throw ArgumentError('A row needs ${columns.length} cells');
    }

    final List<Widget> placedCells = <Widget>[
      for (int index = 0; index < cells.length; index += 1)
        TableRowInkWell(
          onTap: row.onTap,
          mouseCursor: WidgetStateMouseCursor.clickable,
          child: Align(
            alignment: columns[index].cellAlignment,
            child: Padding(
              padding: rowPadding,
              child: WordSafeBox(child: cells[index]),
            ),
          ),
        ),
    ];
    final Widget spacer = TableRowInkWell(
      onTap: row.onTap,
      mouseCursor: WidgetStateMouseCursor.clickable,
      child: const SizedBox.shrink(),
    );

    return TableRow(
      key: row.key,
      decoration: buildRowDecoration(row.emphasis),
      children: _surroundWithSpacers(placedCells, spacer),
    );
  }

  List<Widget> _surroundWithSpacers(List<Widget> cells, Widget spacer) {
    final List<Widget> spaced = <Widget>[spacer];

    for (final Widget cell in cells) {
      spaced.add(cell);
      spaced.add(spacer);
    }

    return spaced;
  }
}
