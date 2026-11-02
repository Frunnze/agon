import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

const double _sideBySideMinimumWidth = 480;

class BuilderToolbar extends StatelessWidget {
  const BuilderToolbar({
    required this.askController,
    required this.onAgentAdded,
    required this.onAsked,
    super.key,
  });

  final TextEditingController askController;
  final VoidCallback onAgentAdded;
  final VoidCallback? onAsked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildToolbar);
  }

  Widget _buildToolbar(BuildContext context, BoxConstraints limits) {
    final Widget addButton = AppButton.secondary(
      label: 'Add agent',
      icon: AppIconKind.plus,
      onPressed: onAgentAdded,
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
