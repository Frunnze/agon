import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

const String addAgentLabel = 'Add agent';
const String addPersonStepLabel = 'Add a person step';
const String askAnAgentLabel = 'Ask an agent';

class BuilderToolbar extends StatelessWidget {
  const BuilderToolbar({
    required this.onAgentAdded,
    required this.onPersonStepAdded,
    required this.onChatOpened,
    super.key,
  });

  final VoidCallback onAgentAdded;
  final VoidCallback onPersonStepAdded;
  final VoidCallback onChatOpened;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        AddStepButtons(
          onAgentAdded: onAgentAdded,
          onPersonStepAdded: onPersonStepAdded,
        ),
        AppButton.secondary(
          label: askAnAgentLabel,
          icon: AppIconKind.draft,
          onPressed: onChatOpened,
        ),
      ],
    );
  }
}

class AddStepButtons extends StatelessWidget {
  const AddStepButtons({
    required this.onAgentAdded,
    required this.onPersonStepAdded,
    super.key,
  });

  final VoidCallback onAgentAdded;
  final VoidCallback onPersonStepAdded;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        AppButton.secondary(
          label: addAgentLabel,
          icon: AppIconKind.plus,
          onPressed: onAgentAdded,
        ),
        AppButton.secondary(
          label: addPersonStepLabel,
          icon: AppIconKind.person,
          onPressed: onPersonStepAdded,
        ),
      ],
    );
  }
}
