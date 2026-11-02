import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/lists/list_column.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/lists/list_table.dart';
import 'package:agent_orchestration/widgets/lists/stacked_list_row.dart';

class ResponsiveList extends StatelessWidget {
  const ResponsiveList({required this.columns, required this.rows, super.key})
    : heading = ListHeading.shown;

  ResponsiveList.plain({required this.rows, super.key})
    : columns = plainColumns,
      heading = ListHeading.hidden;

  final List<ListColumn> columns;
  final List<ListRowData> rows;
  final ListHeading heading;

  @override
  Widget build(BuildContext context) {
    final Widget body = LayoutSize.of(context).isCompact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final ListRowData row in rows)
                StackedListRow(key: row.key, row: row),
            ],
          )
        : ListTable(columns: columns, rows: rows, heading: heading);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: body,
    );
  }
}
