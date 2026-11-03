import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

class PanelHeading extends StatelessWidget {
  const PanelHeading({required this.title, required this.onDone, super.key});

  final String title;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? done = onDone;

    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.bodyBold),
          ),
        ),
        if (done != null) AppButton.secondary(label: 'Done', onPressed: done),
      ],
    );
  }
}
