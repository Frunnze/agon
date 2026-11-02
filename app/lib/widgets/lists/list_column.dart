import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';

final class ListColumn {
  ListColumn.flexible({required this.label, required double flex})
    : tableWidth = FlexColumnWidth(flex),
      cellAlignment = Alignment.centerLeft;

  ListColumn.content({required this.label, required double minimumWidth})
    : tableWidth = MaxColumnWidth(
        FixedColumnWidth(minimumWidth),
        const IntrinsicColumnWidth(),
      ),
      cellAlignment = Alignment.centerLeft;

  const ListColumn.trailing({required this.label})
    : tableWidth = const IntrinsicColumnWidth(),
      cellAlignment = Alignment.centerRight;

  final String label;
  final TableColumnWidth tableWidth;
  final Alignment cellAlignment;
}

List<ListColumn> buildStandardColumns(List<String> labels) {
  if (labels.length != 4) {
    throw ArgumentError.value(labels, 'labels', 'Lists have four columns');
  }

  return <ListColumn>[
    ListColumn.flexible(label: labels[0], flex: 2),
    ListColumn.flexible(label: labels[1], flex: 1),
    ListColumn.flexible(label: labels[2], flex: 1),
    ListColumn.content(
      label: labels[3],
      minimumWidth: AppSizes.listEndColumnMinimumWidth,
    ),
  ];
}

List<ListColumn> buildColumnsWithAction(List<String> labels) {
  if (labels.length != 5) {
    throw ArgumentError.value(labels, 'labels', 'Action lists have five');
  }

  return <ListColumn>[
    ListColumn.flexible(label: labels[0], flex: 2),
    ListColumn.flexible(label: labels[1], flex: 1),
    ListColumn.flexible(label: labels[2], flex: 1),
    ListColumn.flexible(label: labels[3], flex: 1),
    ListColumn.content(
      label: labels[4],
      minimumWidth: AppSizes.listActionColumnMinimumWidth,
    ),
  ];
}

final List<ListColumn> plainColumns = List<ListColumn>.unmodifiable(
  <ListColumn>[
    ListColumn.flexible(label: '', flex: 1),
    const ListColumn.trailing(label: ''),
  ],
);
