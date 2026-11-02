import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

class NumberedList extends StatelessWidget {
  const NumberedList({required this.entries, super.key});

  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        for (int index = 0; index < entries.length; index += 1)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('${index + 1}.', style: AppTextStyles.bodyBold),
              const SizedBox(width: AppSpacing.space2),
              Expanded(child: Text(entries[index])),
            ],
          ),
      ], AppSpacing.space2),
    );
  }
}
