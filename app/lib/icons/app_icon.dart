import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/icons/app_icon_painter.dart';
import 'package:agent_orchestration/icons/spinning_box.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_density.dart';

enum AppIconSize {
  regular,
  small;

  double extentFor(LayoutDensity layoutDensity) {
    if (this == AppIconSize.small) {
      return AppSizes.iconSmall;
    }
    return AppSizes.iconFor(layoutDensity);
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.kind, {
    super.key,
    this.size = AppIconSize.regular,
    this.color,
  });

  final AppIconKind kind;
  final AppIconSize size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color inheritedColor =
        DefaultTextStyle.of(context).style.color ?? AppColors.ink;
    final double extent = size.extentFor(LayoutDensity.of(context));
    final Widget paintedIcon = CustomPaint(
      size: Size.square(extent),
      painter: AppIconPainter(kind: kind, color: color ?? inheritedColor),
    );

    if (kind == AppIconKind.spinner) {
      return ExcludeSemantics(child: SpinningBox(child: paintedIcon));
    }

    return ExcludeSemantics(child: paintedIcon);
  }
}
