import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

const double _sideBySideMinimumWidth = 720;
const String addAgentLabel = 'Add agent';
const String addPersonStepLabel = 'Add a person step';

class BuilderToolbar extends StatelessWidget {
  const BuilderToolbar({
    required this.askController,
    required this.onAgentAdded,
    required this.onPersonStepAdded,
    required this.onAsked,
    super.key,
  });

  final TextEditingController askController;
  final VoidCallback onAgentAdded;
  final VoidCallback onPersonStepAdded;
  final VoidCallback? onAsked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildToolbar);
  }

  Widget _buildToolbar(BuildContext context, BoxConstraints limits) {
    final Widget addButton = AddStepButtons(
      onAgentAdded: onAgentAdded,
      onPersonStepAdded: onPersonStepAdded,
    );
    final Widget askRow = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Semantics(
              label: 'Ask the agent to change the workflow',
              child: TextField(
                controller: askController,
                onSubmitted: (String _) => onAsked?.call(),
                decoration: const InputDecoration(
                  hintText: 'Ask the agent, e.g. add a test step after ios',
                  hintMaxLines: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          AppButton.secondary(
            label: 'Ask',
            icon: AppIconKind.draft,
            onPressed: onAsked,
          ),
        ],
      ),
    );

    if (limits.maxWidth >= _sideBySideMinimumWidth) {
      return Row(
        children: <Widget>[
          addButton,
          const SizedBox(width: AppSpacing.space4),
          Expanded(child: askRow),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        addButton,
        const SizedBox(height: AppSpacing.space2),
        askRow,
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
