import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/icons/app_icon_painter.dart';
import 'package:agent_orchestration/icons/spinning_box.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

enum AppIconSize {
  regular(AppSizes.icon),
  small(AppSizes.iconSmall);

  const AppIconSize(this.extent);

  final double extent;
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
    final Widget paintedIcon = CustomPaint(
      size: Size.square(size.extent),
      painter: AppIconPainter(kind: kind, color: color ?? inheritedColor),
    );

    if (kind == AppIconKind.spinner) {
      return ExcludeSemantics(child: SpinningBox(child: paintedIcon));
    }

    return ExcludeSemantics(child: paintedIcon);
  }
}
