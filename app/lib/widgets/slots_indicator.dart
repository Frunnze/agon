import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

class SlotsIndicator extends StatelessWidget {
  SlotsIndicator({required this.total, required this.busy, super.key}) {
    if (total < 0 || busy < 0 || busy > total) {
      throw ArgumentError('Busy slots must be between 0 and $total');
    }
  }

  final int total;
  final int busy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space1,
      runSpacing: AppSpacing.space1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (int index = 0; index < total; index += 1)
          Container(
            width: AppSpacing.space3,
            height: AppSpacing.space3,
            decoration: BoxDecoration(
              color: index < busy ? AppColors.ink : null,
              border: Border.all(color: AppColors.ink),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.space1),
          child: Text('$busy of $total busy'),
        ),
      ],
    );
  }
}
