import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

enum SplitProportion {
  narrowStart(2, 3),
  wideStart(3, 2);

  const SplitProportion(this.startFlex, this.endFlex);

  final int startFlex;
  final int endFlex;
}

class SplitLayout extends StatelessWidget {
  const SplitLayout({
    required this.start,
    required this.end,
    super.key,
    this.proportion = SplitProportion.narrowStart,
  });

  final Widget start;
  final Widget end;
  final SplitProportion proportion;

  @override
  Widget build(BuildContext context) {
    if (!LayoutSize.of(context).isLarge) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          start,
          const SizedBox(height: AppSpacing.space6),
          end,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: proportion.startFlex, child: start),
        const SizedBox(width: AppSpacing.space6),
        Expanded(flex: proportion.endFlex, child: end),
      ],
    );
  }
}
