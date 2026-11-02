import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

class PageSection extends StatelessWidget {
  const PageSection({
    required this.title,
    required this.children,
    super.key,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final Widget header = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.space4,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: AppTextStyles.bodyBold),
        ),
        ...actions,
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        header,
        ...children,
      ], AppSpacing.space3),
    );
  }
}
