import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const String emptyCanvasText =
    'No agents yet. Add an agent, then drag between dots to connect agents.';

class EmptyWorkflowCanvas extends StatelessWidget {
  const EmptyWorkflowCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return const CanvasFrame(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.space4),
          child: Text(
            emptyCanvasText,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
          ),
        ),
      ),
    );
  }
}
