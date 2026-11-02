import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/route_line_painter.dart';

class RouteLine extends StatelessWidget {
  const RouteLine({
    required this.startName,
    required this.endName,
    required this.path,
    required this.badgeLabel,
    required this.badgeIcon,
    super.key,
  });

  final String startName;
  final String endName;
  final RoutePath path;
  final String badgeLabel;
  final AppIconKind badgeIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$startName to $endName, $badgeLabel',
      child: ExcludeSemantics(child: LayoutBuilder(builder: _buildRoute)),
    );
  }

  Widget _buildRoute(BuildContext context, BoxConstraints constraints) {
    final Color routeColor = path.color;
    final TextStyle nodeStyle = AppTextStyles.small
        .merge(AppTextStyles.monospace)
        .copyWith(fontWeight: FontWeight.w700);
    final double spaceForNames =
        constraints.maxWidth - AppSpacing.space8 - AppSpacing.space2 * 2;
    final BoxConstraints nameConstraints = BoxConstraints(
      maxWidth: max(0, spaceForNames / 2),
    );

    return Row(
      children: <Widget>[
        ConstrainedBox(
          constraints: nameConstraints,
          child: Text(startName, style: nodeStyle),
        ),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          child: CustomPaint(
            painter: RouteLinePainter(path: path),
            child: Center(child: _buildBadge(routeColor)),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        ConstrainedBox(
          constraints: nameConstraints,
          child: Text(endName, style: nodeStyle),
        ),
      ],
    );
  }

  Widget _buildBadge(Color routeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: routeColor),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppIcon(badgeIcon, size: AppIconSize.small, color: routeColor),
          const SizedBox(width: AppSpacing.space1),
          Flexible(
            child: Text(
              badgeLabel,
              style: AppTextStyles.monospace.copyWith(
                color: routeColor,
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
