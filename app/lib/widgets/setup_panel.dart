import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/dot_grid_background.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const double _panelMaximumWidth = 544;

class SetupPanel extends StatelessWidget {
  const SetupPanel({
    required this.step,
    required this.title,
    required this.children,
    super.key,
  });

  final String step;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final double panelPadding = LayoutSize.of(context).isCompact
        ? AppSpacing.space5
        : AppSpacing.space7;

    return DotGridBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space6,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _panelMaximumWidth),
            child: Container(
              padding: EdgeInsets.all(panelPadding),
              decoration: BoxDecoration(
                color: AppColors.raised,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppRadii.panel),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaceVertically(<Widget>[
                  Text(
                    step,
                    style: AppTextStyles.smallMuted.merge(
                      AppTextStyles.monospace,
                    ),
                  ),
                  Semantics(
                    header: true,
                    child: Text(title, style: AppTextStyles.hero),
                  ),
                  ...children,
                ], AppSpacing.space5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SetupActions extends StatelessWidget {
  const SetupActions({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (LayoutSize.of(context).isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaceVertically(children, AppSpacing.space2),
      );
    }

    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: children,
    );
  }
}
