import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

enum RowEmphasis { normal, current }

final class ListRowData {
  const ListRowData({
    required this.main,
    this.key,
    this.meta = const <Widget>[],
    this.end,
    this.onTap,
    this.emphasis = RowEmphasis.normal,
  });

  final LocalKey? key;
  final Widget main;
  final List<Widget> meta;
  final Widget? end;
  final VoidCallback? onTap;
  final RowEmphasis emphasis;
}

BoxDecoration buildRowDecoration(RowEmphasis emphasis) {
  final bool isCurrent = emphasis == RowEmphasis.current;

  return BoxDecoration(
    color: isCurrent ? AppColors.actionTint : null,
    border: Border(
      left: BorderSide(
        color: isCurrent ? AppColors.action : AppColors.transparent,
        width: AppBorders.selected,
      ),
      bottom: const BorderSide(color: AppColors.line),
    ),
  );
}
